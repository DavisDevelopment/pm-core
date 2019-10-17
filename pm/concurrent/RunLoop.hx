package pm.concurrent;

import pm.async.impl.NPromise;
import pm.async.impl.PromiseObject.PromiseTriggerObject;
#if (js && !macro)
import js.node.Process.ProcessEvent;
#end
import pm.async.*;
import pm.async.Callback;
import pm.async.Signal;

import pm.concurrent.rl.Task;
import pm.concurrent.rl.Worker;
import pm.concurrent.rl.*;

import pm.Functions.fn;

using pm.Arrays;
using pm.Numbers;
using pm.Functions;
using pm.Outcome;

class RunLoop extends QueueWorker {
    static public var current(default, null):RunLoop = new RunLoop();
    /**
    * The retain count of the loop. When this drops to 0 and no more tasks are scheduled, the loop is done.
    */
    public var retainCount(default, null):Int = 0;
    public var running(default, null):Bool;
    var slaves: Array<Worker>;
    // var _done: PromiseTrigger<Dynamic, pm.Error> = new PromiseTrigger();
    var _done: PromiseTriggerObject<Dynamic> = NPromise.trigger();

    function new(id = 'ROOT_LOOP') {
        slaves = new Array();
        
        super(this, id);
        // });
    }

/* === Methods === */

    public function addSlave(worker:Worker):RunLoop {
        slaves.push(worker);
        return this;
    }

    /**
    * Delegates a task to a worker.
    * The resulting future is dispatched onto the runloop's thread.
    */
    public function delegate<A>(task:pm.Lazy<A>, slave:Worker):Promise<A> {
        // var t = new pm.async.PromiseTrigger();//.FutureTrigger();//Future.trigger();
        return Promise.async(function(done: Callback<Outcome<A, Dynamic>>) {
            this.asap(function () retainCount++);
            
            slave.work(
            function () {
                var res = task.get();
                this.work(function () {
                    done(Success(res));
                    retainCount--;
                });
            }
            );
        });    
        // return t.asPromise();
    }

    public dynamic function onError(error:pm.Error):Void {
        throw error;
    }
    
    /**
    * Delegates an unsafe task to a worker.
    * The resulting surprise is dispatched onto the runloop's thread.
    */
    public function tryDelegate<A>(unsafe:pm.Lazy<A>, slave:Worker, report:Dynamic->Error):Promise<A> {
        return (delegate(
            catchExceptions(unsafe, report),
            slave
        ).flatMap(function(o):Promise<A> {
            switch o {
                case Success(result):
                    return Promise.resolve(result);

                case Failure(error):
                    return delegate(Lazy.ofFn(function() {
                        onError(report(error));
                        return null;
                    }), slave);
            }
        }));
    }
    static function catchExceptions<T, E>(l:pm.Lazy<T>, handle:Dynamic->E):pm.Lazy<Outcome<T, E>> {
        return Lazy.ofFn(function() {
            return
            try Success(l.get())
            catch (e: Dynamic) Failure(handle(e));
        });
    }

    /**
    * Lets the run loop burst for a given time,
    * performing as many tasks as possible until the time elapses.
    * Note that if tasks block the loop, the burst can take significantly longer.
    */
    public function burst(time:Float):WorkResult {
        var burstCap = 0.25;
        var limit = getStamp() + Math.min(time, burstCap);
        var ret = null;
        do {
            if (!running) 
                break;
            switch step() {
                case Progressed:
                case v: 
                    ret = v;
                    break;
            }
        } 
        while (getStamp() < limit);    
        return ret;
    }

    static function create(init:Void->Void) {
        current.enter(init);
    }
    
    public function enter(init:Void->Void) {
        if (!running) {
            trace('runloop(spin)');
            spin(init);
        }
        else {
            work(init);
        }
    }
    
    function spin(init: Void->Void) {
        this.running = true;
        this.execute(init);
        
        var stamp = getStamp();
        function burst(stop) {
            return function() {
                switch this.step() {
                    case Done | Aborted:
                        // #if !js
                        this.running = false;
                        stop();
                        // #end
                    default:
                }
            };

            // unreachable
            return function () {

                var delta = getStamp() - stamp;
                stamp += delta;
                
                switch this.burst(delta) {
                    //TODO handle null value
                    case Done | Aborted: 
                        this.running = false;
                        stop();
                    
                    default:
                }
            }
        }
        
        #if flash

        var beacon = flash.Lib.current.stage;
        var progress = null;
        function stop()
            beacon.removeEventListener(flash.events.Event.ENTER_FRAME, progress);
            
        beacon.addEventListener(flash.events.Event.ENTER_FRAME, progress = function (_) { 
            burst(stop);
        });
        
        #elseif js
        
            #if hxnodejs
            js.Node.process.on(ProcessEvent.BeforeExit, function(exitCode:Int) {
                // this.running = false;
            });
            #end
        /** 
         [TODO] use application-loop built on `process.nextTick || setImmediate` when either are available  
        **/

        var t = new haxe.Timer(0);
        t.run = burst(t.stop);
        // var link:CallbackLink = (function() throw 'Invalid call'),
        //     stop:Void->Void;
        // stop = function() {
        //     link.cancel();
        // };
        // link = JsLoop.defer((function() {
        //     trace('poop');
        // }).join(burst(stop)));
        
        #else
        
        while (this.running) 
            switch this.step() {
                case Done | Aborted: 
                    this.running = false;

                default:
                    //
            }
        #end
    }

    var slaveCounter = 0;
    function _runSlaves():WorkResult {
        slaveCounter %= slaves.length;
        if (slaves.length > 0) {
            for (_ in 0...slaves.length) {
                switch (slaves[slaveCounter++ % slaves.length].step()) {
                    case Progressed:
                        return Progressed;
                    
                    default:
                }
            }
        }
        return Idle;
    }

    function runSlaves() {
        // (?)
        for(i in 0...slaves.length) {
            switch slaves[i].step() {
                case Progressed:
                    return Progressed;
                default:
            }
        }
        return Idle;
    }

    override function doStep():WorkResult {
        // return
        // trace(tasks);
        switch tasks.shift() {
            case null:
                if (this.retainCount == 0) {
                    _done.resolve(Noise);
                    return Done;
                }
                else {
                    return runSlaves();
                }

            case v:
                return execute(v);
        }
    }

    public function bind<A>(cb: Callback<A>):Callback<A> {
        if (cb == null)
            return null;
        this.asap(function() retainCount++);
        return function(result: A) {
            this.work(function() {
                if (cb != null) {
                    cb.invoke(result);
                    cb = null;
                    retainCount--;
                }
            });
        }
    }

    /**
      get most accurate possible timestamp
     **/
    #if js
    static var _now:Null<Void -> Float> = null;
    #end
    static function getStamp():Float {
        #if js
            #if (hxnodejs || nodejs || node)
                var tmp = js.Node.process.hrtime();
                return tmp[0] * 1e3 + tmp[1] / 1e6;
            #else
                js.Syntax.code('
                    {0}._now ? {0}._now() : (function(){
                        {0}._now = (() => {
                            var f = null;
                            if (typeof process !== "undefined" && ("hrtime" in process)){
                                f = process.hrtime.bind(process);
                            }
                            if (!f && typeof performance !== "undefined" && ("now" in performance)) {
                                f = (()=>performance.now());
                            }

                            return (f || (()=>Date.now()));
                        })();
                    })();
                ', RunLoop);
            #end
        #elseif python
        return python.Syntax.code('{0}.perf_counter() * 1e3', python.lib.Time);
        #else
        return (1000.0 * Sys.time());
        #end
    }
}

#if js
class JsLoop {
    static var _clear_(default, null):(deferredFnLink:Any)->Void = null;

    @:isVar
    static var _defer_(get, null):(f:Void->Void)->Any = null;
    static function get__defer_() {
        if (_defer_ == null) {
            var g = js.Lib.global;
            _defer_ = js.Syntax.code('({0}.setImmediate && typeof {0}.setImmediate === "function") ? {0}.setImmediate : null', g);
            if (_defer_ != null) {
                _clear_ = js.Syntax.code('{0}.clearImmediate', g);
                return _defer_;
            }

            _defer_ = js.Syntax.code('(typeof process !== "undefined" ? process.nextTick : null)');
            if (_defer_ != null) {
                _clear_ = (lnk -> cast(lnk, CallbackLink).cancel());
                return _defer_;
            }
            throw "Not Supported";
        }
        return _defer_;
    }

    public static inline function defer(fn: Void->Void):CallbackLink {
        return new DelegatedCallbackLink(_defer_(fn));
    }
}
// @:access(pm.concurrent.RunLoop.JsLoop)
private class DelegatedCallbackLink implements LinkObject {
    var id: Any;
    // var _rm: Dynamic;
    public function new(id) {
        this.id = id;
    }
    public function cancel() {
        @:privateAccess JsLoop._clear_(id);
    }
}
class JsFiber {
    public var repeat:Bool;
    public var link:Null<CallbackLink>;
    public function new() {
        repeat = false;
        link = null;

        _schedule_(this);
    }

    public dynamic function run() {
        //
    }

    public function cancel() {
        if (link != null) {
            link.cancel();
            link = null;
        }
    }

    public function stop() {
        repeat = false;
        cancel();
    }

    static function _schedule_(fiber: JsFiber) {
        if (fiber.link == null) {
            fiber.link = JsLoop.defer(function() {
                fiber.run();
                fiber.link = null;
                if (fiber.repeat)
                    _schedule_(fiber);
            });
        }
    }
    public static function create(f:JsFiber->Void, repeat:Bool=false):JsFiber {
        var fiber = new JsFiber();
        fiber.repeat = repeat;
        fiber.run = f.bind(fiber);
        return fiber;
    }
}
#end