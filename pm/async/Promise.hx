package pm.async;

import pm.async.impl.PromiseObject.PromiseTriggerObject;
import haxe.Timer;
import haxe.ds.Either;
import haxe.ds.Option;

import pm.async.Callback;
import pm.async.impl.*;
using pm.async.impl.CommonTypes;
import pm.async.impl.NPromise;
import pm.async.impl.PromiseHandle;
import pm.Outcome;
import pm.Helpers.*;

using pm.Functions;

@:forward
@:using(pm.async.impl.PromiseHandle)
@:using(pm.async.Promises)
@:using(pm.async.Promises.FunctionPromises)
abstract Promise<T> (PromiseHandle<T>) from PromiseHandle<T> to PromiseHandle<T> {
    public var reference(get, never):PromiseHandle<T>;
    inline function get_reference() return (this : PromiseHandle<T>);
    
    public var underlying(get, never):NPromise<T>;
    inline function get_underlying() return reference.promise;

    public inline function new(d: NPromise<T>) {
        this = create(d);
    }

    public inline function then(onFulfilled, ?onError):Promise<T> {
        this.then(onFulfilled, onError);
        return this;
    }

    public inline function catchException(onError: Callback<Dynamic>):Promise<T> {
        return handle(o -> switch o {
            case Failure(e): onError(e);
            default:
        });
    }

    public function rescue(net: (error: Dynamic)->Option<Promise<T>>):Promise<T> {
        return this.next(function(o) {
            return switch o {
                case Success(_): this;
                case Failure(error):
                    switch net(error) {
                        case None: this;
                        case Some(caught): caught;
                    }
            }
        });
    }
    
    public inline function handle(onOutcome):Promise<T> {
        this.handle(onOutcome);
        return this;
    }
    
    public inline function map<O>(f: T -> O):Promise<O> {
        var h = this.map(f);
        return h;
        // return create(this.map(f));
    }

    public inline function flatMap<O>(f: T -> Promise<O>):Promise<O> {
        return this.flatMap(f);
    }

    public inline function outcome():Promise<Outcome<T, Dynamic>> {
        return asyncFulfill(function(yield) {
            this.handle(yield);
        });
    }

    public function inspect(?pos:haxe.PosInfos):Promise<T> {
        var logFormatted = haxe.Log.formatOutput(null, pos);
		var pattern = (~/((?:.+)\.hx:(\d+):\s*)null\s*$/gm);
        pm.Assert.assert(pattern.match(logFormatted));
        var prefix = pattern.matched(1);

        this.handle(function(outcome) {
            #if Console.hx
            switch outcome {
                case Success(result):
                    trace(result);

                case Failure(error):
                    trace(prefix, error);
            }
            #else
            trace(outcome, pos);
            #end
        });
        return this;
    }

    public function timeout(milliseconds:Int, outcome:Lazy<Outcome<T, Dynamic>>):Promise<T> {
        return withTimeout(this, milliseconds, {outcome:outcome});
    }

    public function failAfter(ms:Int, ?error:Dynamic, ?pos:haxe.PosInfos):Promise<T> {
        return timeout(ms, Failure(error != null ? error : new Error('Promise timed out', null, pos)));
    }

    public static function delayedSync<T>(time_ms:Int, outcome:Lazy<Outcome<T,Dynamic>>, ?timerHook:Timer->Void):Promise<T> {
        return async(function(yeet) {
            var yeet = ()->yeet(outcome.get());
            var t = haxe.Timer.delay(yeet, time_ms);
            if (timerHook != null) timerHook(t);
        });
    }

    public static function withTimeout<T>(self:Promise<T>, time_ms:Int, o:{?outcome:Outcome<T,Dynamic>, ?delegate:Promise<T>}):Promise<T> {
        // var time_ms:Int = Math.round(seconds * 1000);
        var trigger = NPromise.trigger();
        var timerHasRung = false;
        var timer = new haxe.Timer(time_ms);
        timer.run = function() {
            timerHasRung = true;
            switch o {
                case {delegate:null, outcome:null}:
                    trigger.reject('invalid options object');

                case {outcome:o}:
                    switch o {
                        case Success(v):
                            trigger.resolve(v);
                        case Failure(e):
                            trigger.reject(e);
                    }

                default:
                    throw 'how dare u';
            }
        };
        self.always(function() {
            if (!timerHasRung) {
                timer.stop();
            }
        });
        self.then(
            function(result){
                trigger.resolve(result);
            },
            function(error) {
                trigger.reject(error);
            }
        );

        return Promise.ofPromiseObject(trigger.asPromise());
    }

    public static function all<T>(promises: Array<Promise<T>>):Promise<Array<T>> {
        var llAll = NPromise.inParallel(promises.map(p -> p.underlying));
        return create(llAll);
    }
    public static inline function reduce<T,Agg>(promises:Iterable<Promise<T>>, reducer, init:Agg):Promise<Agg> {
        return Ph.reduce(promises, reducer, init);
    }

    @:from
    static function of<T>(h: PromiseHandle<T>):Promise<T> {
        return (h : Promise<T>);
    }

    @:from
    public static inline function create<T>(init: NPromise<T>):Promise<T> {
        return PromiseHandle.wrap(init);
    }

    @:from
    public static inline function ofPromiseObject<T>(promise: PromiseObject<T>):Promise<T> {
        return create(promise);
    }
    @:from public static inline function asyncDyad<T>(ctor: (resolve:T->Void, reject:Dynamic->Void)->Void):Promise<T> {
        return create(NPromise.createFromDyad(ctor));
    }
    @:from public static inline function async<T>(exec: (Outcome<T, Dynamic> -> Void) -> Void):Promise<T> {
        return create(NPromise.async(exec));
    }
    @:from public static inline function asyncFulfill<R>(ctor: (callback: R -> Void)->Void):Promise<R> {
        return create(NPromise.createFromResultMonad( cast ctor ));
    }
    @:from public static inline function asyncNiladUnsafe(exec: (callback: Void->Void)->Void):Promise<Noise> {
        return function(done) {
            exec(function() {
                done(Success(Noise.createByIndex(0)));
            });
        };
    }
    @:from public static inline function asyncMonad(monad: AsyncMonad):Promise<Noise> {
        return Promise.async(function(done) {
            return monad.call(function(outcome) {
                switch outcome {
                    case Some(v):
                        done(Failure(v));

                    case None:
                        done(Success(Noise.createByIndex(0)));
                }
            });
        });
    }
    @:from public static inline function createSync<T>(outcome: Lazy<Outcome<T, Dynamic>>):Promise<T> {
        return create(NPromise.sync(outcome));
    }

    /**
      create a new synchronous `Promise<T>` instance which yields the given `Outcome<T,?>`
     **/
    @:from
    public static function sync<T>(outcome: Outcome<T, Dynamic>):Promise<T> {
        return createSync(outcome);
    }

    @:from 
    public static function deferred<T>(deferred: Deferred<T, Dynamic>):Promise<T> {
        return async(function(done) {
            deferred.handle(function(resolution) {
                switch resolution {
                    case Result(x): done(Success(x));
                    case Exception(x): done(Failure(x));
                }
            });
        });
    }

#if js
    @:from
    public static function ofJsPromise<T>(promise: js.lib.Promise<T>):Promise<T> {
        return ofPromiseObject(NPromise.ofJsPromise(promise));
    }

#end

    @:from 
    public static function resolve<T>(value: T):Promise<T> {
        return NPromise.resolve(value);
    }
    
    public static function reject<T>(error:Dynamic, ?pos:haxe.PosInfos):Promise<T> {
        return NPromise.reject(error);
    }

    public static function ofAny(x: Any):Promise<Dynamic> {
        if ((x is PromiseHandleObject<Dynamic>)) {
            return (x : PromiseHandleObject<Dynamic>);
        }
        if ((x is PromiseObject<Dynamic>)) {
            return (x : PromiseObject<Dynamic>);
        }
        return reject('Invalid value $x');
    }

    public static inline function trigger<T>():PromiseTriggerObject<T> {
        return NPromise.trigger();
    }
    
    @:from 
    public static inline function createFromTrigger<T>(trigger: PromiseTriggerObject<T>):Promise<T> {
        return ofPromiseObject(NPromise.createFromTrigger(trigger));
    }
}

private typedef Am = (callback:(outcome: Option<Dynamic>)->Void)->Void;
@:callable
@:forward
abstract AsyncMonad (Am) from Am to Am {
    @:from public static inline function jsStyle(exec: (error: Null<Dynamic>)->Void):AsyncMonad {
        return function(callback: Option<Dynamic>->Void) {
            return exec(function(error) {
                return switch error {
                    case null: Option.None;
                    default: Some(error);
                }
            });
        };
    }
}
typedef Ph<T> = pm.async.impl.PromiseHandle<T>;