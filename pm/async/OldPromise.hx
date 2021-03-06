package pm.async;

import haxe.Timer;
import pm.Error.NotImplementedError;
import pm.Assert.assert;
import pm.Noise;
import pm.Outcome;
import haxe.ds.Either;
import haxe.ds.Option;

import pm.async.Callback;
import pm.async.Deferred;
import pm.async.Future;

import pm.Functions.fn as mfn;

using pm.Functions;
using pm.Outcome;
using pm.Options;
using pm.Arrays;

/**
  represents the outcome of some future event, specifically with regards to the "return value" of said event
 **/
@:forward
abstract Promise<T> (TProm<T>) from TProm<T> to TProm<T> {
    public inline function new(d: Deferred<T, Dynamic>) {
        this = new Future<T, Dynamic>( d );
    }

    #if debug
    public function inspect(?pos: haxe.PosInfos):Promise<T> {
        trace(pos);
        return handle(function(o) {
            // trace(pos);
            var text:String = '';//Std.string(o);
            try {
                text = Std.string(o);
            }
            catch (err: Dynamic) {
                trace(err);
                throw err;
            }
            if (text.length >= 750) {
                text = 'Promise(${this.key}) finished with a ' + (o.isSuccess()?'Success':'Failure') + ' value';
            }
            trace(text, pos);
        });
    }
    #else
    public inline function inspect(?pos:haxe.PosInfos):Promise<T> {
        trace(pos);
        return this;
    }
    #end

    public function then(resolved:Callback<T>, ?rejected:Callback<Dynamic>):Promise<T> {
        this.then((x -> resolved.invoke(x)), rejected != null ? (x -> rejected.invoke(x)) : null);
        return this;
    }

    public inline function handle(handler: Callback<Outcome<T, Dynamic>>):Promise<T> {
        this.handle(handler);
        return this;
    }

    public inline function always(cb: Void -> Void):Promise<T> {
        return then(
            _ -> cb(),
            _ -> cb()
        );
    }

    public inline function omap<OT>(fn: TOut<T> -> TOut<OT>):Promise<OT> {
        return this.omap( fn );
    }

    public inline function map<O>(fn: T -> O):Promise<O> {
        return this.map( fn );
    }

    public inline function flatMap<O>(fn: T -> Promise<O>):Promise<O> {
        return this.flatMap( fn );
    }

    public function derive<O>( fn: (root:Promise<T>, accept:O->Void, reject:Dynamic->Void)->Void):Promise<O> {
        var dd:Deferred<O, Dynamic> = Deferred.create();
        fn(
            this,
            // mfn(dd.done(_)),
            (o -> dd.done(o)),
            // mfn(dd.fail(_))
            (e -> dd.fail(e))
        );
        return Promise.make( dd );
    }

    @:to
    public inline function dynamicify():Promise<Dynamic> {
        return cast this;
    }

    @:to
    public function noisify():Promise<Noise> {
        return map(x -> Noise);
    }

    public inline function first(that: Promise<T>):Promise<T> return or(this, that);

    public inline function isResolved():Bool @:privateAccess return this.d.isResolved();
    // public inline function 

    private var tail(get, never):FutureHandle<T, Dynamic>;
    inline function get_tail() return this.tail;

    /**
      returns a `Promise` which yields the output of the first of its parameters to resolve (@see "resolve"), and discards the other.
     **/
    @:op(A || B)
    public static function or<T>(left:Promise<T>, right:Promise<T>):Promise<T> {
        // throw '[TODO]';
        if (left.isResolved()) return left;
        if (right.isResolved()) return right;
        var trigger = Promise.trigger(), link:CallbackLink = null;
        
        /**
         [NOTE]
          maintains mutual exclusivity by dissolving the `Promise<T>  =>  Callback<Outcome<?, ?>>` link for both promises upon either one resolving
         **/
        function winner(o) {
            assert(
                (link != null),
                new pm.Error.WTFError('`link == null` should be an unsatisfiable condition')
            );

            trigger.trigger( o );
            link.dissolve();
        }

        link = ((left : Future<T, Dynamic>).handle(winner) & (right : Future<T, Dynamic>).handle(winner));

        return trigger.asPromise();
    }

    static public function inParallel<T>(a:Array<Promise<T>>, ?concurrency:Int, ?lazy:Bool):Promise<Array<T>> { 
        if (a.length == 0) {
            return resolve(new Array<T>());
        }
        else {
            var future:Deferred<Array<T>, Dynamic> = function (cb: Callback<Outcome<Array<T>, Dynamic>>) {
                var result = [], 
                    pending = a.length,
                    links:CallbackLink = null,
                    linkArray = [],
                    sync = false,
                    i = 0,
                    iter = a.iterator(),
                    next = null;

                trace('future...');
                
                function done(o) {
                    if (links == null) 
                        sync = true;
                    else 
                        links.cancel();
                    cb(o);
                }

                function fail(e:Error) {
                    pending = 0;
                    done(Failure(e));
                }
                
                inline function hasNext() {
                    return iter.hasNext() && pending > 0;
                }
                
                function set(index:Int, value) {
                    trace('set[$index] = (...)');
                    result[index] = value;
                    if (--pending == 0) 
                        done(Success(result));
                    else if(hasNext())
                        next();
                }
                
                next = function() {
                    trace('inParallel.next');
                    var index = i++;
                    linkArray.push(
                        (iter.next().outcome() : Future<Outcome<T, Dynamic>, Dynamic>).then(
                            function(o: Outcome<T, Dynamic>) {
                                switch o {
                                    case Success(result):
                                        set(index, result);

                                    case Failure(error):
                                        fail(error);
                                }
                            }
                        )
                    );
                }
                
                while(hasNext() && (concurrency == null || concurrency-- > 0)) {
                   next();
                }
                
                links = linkArray;

                if ( sync )
                    links.cancel();
            };
            return new Promise<Array<T>>(future);
        }
    }

    /**
      creates a Promise which will resolve to an array containing the values resolved from each of the provided promises
     **/
    public static function all<T>(promises: Array<Promise<T>>):Promise<Array<T>> {
        // trace('all...');
        return inParallel(promises);
        if (promises.empty()) {
            return Promise.resolve(new Array<T>());
        }

        return new Promise<Array<T>>(function(resolve, reject) {
            // trace('all...');
            
            var queue:Array<Promise<T>> = promises.copy();
            var results:Array<T> = Arrays.alloc(promises.length);
            var due = promises.length,
                dun = 0;

            function step(p:Promise<T>, index:Int, o:Outcome<T, Dynamic>) {
                // trace('($p, $index, $o)');
                queue.remove(p);
                switch o {
                    case Success(result):
                        results[index] = result;
                        if (queue.empty()) {
                            // trace('Promise.all() complete');
                            resolve(results);
                        }
                    
                    case Failure(error):
                        reject(error);
                }
            }

            inline function enqueue(prom:Promise<T>, index:Int) {
                prom.then(
                    result -> step(prom, index, Success(result)),
                    error -> step(prom, index, Failure(error))
                );
            }

            for (i in 0...promises.length) {
                enqueue(promises[i], i);
            }
            
        });
    }

    @:op(A & B)
    public static function both<L, R>(l:Promise<L>, r:Promise<R>):Promise<Pair<L, R>> {
        return l.next(left -> r.next(right -> new Pair<L, R>(left, right)));
    }

    public function timeout(ms: Int):Promise<T> {
        return (this : Promise<T>) || _clock_canceller_(new Timer( ms ));
    }
    static function _clock_canceller_<T>(t:Timer):Promise<T> {
        var tr = Promise.trigger();
        t.run = () -> {
            t.stop();
            t.run = (function() return);
            tr.reject('Promise:timed-out');
        };
        return tr.asPromise();
    }

    public inline function next<R>(n: Next<T, R>):Promise<R> {
        return ofFuture(tail.flatMap(function(o) {
            return switch o {
                case Success(res): n(res);
                case Failure(error): Promise.reject(error);
            }
        }));
    }

    public function merge<A, R>(other:Promise<A>, merger:Combiner<T, A, R>):Promise<R> { 
        
        return next(function(t) {
            return other.next(function(a) {
                // return merger(t, a);
                return merger(t, a);
            });
        });
    }

    public function outcomeMap<TOut, TErr>(mapper: Outcome<T, Dynamic> -> Outcome<TOut, TErr>):Deferred<TOut, TErr> {
        var output = Deferred.create();
        function handler(o: Outcome<T, Dynamic>) {
            output.resolve(mapper.call( o ));
        }
        then(
            result -> {
                handler(Success(result));
            },
            error -> {
                handler(Failure(error));
            }
        );
        return (output : Deferred<TOut, TErr>);
    }

    public function tryCatch<Br>(rescuer:Dynamic->Option<Promise<Br>>):Promise<Either<T, Br>> {
        return this.outcome().flatMap(function(o) {
            switch o {
                case Success(result):
                    throw 0;
                case Failure(error):
                    throw 0;
            }
        });
        /*
        tail.flatMap(function(o) {
            return switch o {
                case Success(result): Success(Left(result));
                case Failure(error):
                    switch (rescuer(error)) {
                        case Some(next):
                            //

                        case None:
                            Failure(error);
                    }
                        
            }
        })
        */
    }

#if js

    @:to
    public function native():js.Promise<T> {
        return new js.Promise<T>(function(accept, reject) {
            then(
                function(x) {
                    accept(x);
                },
                function(x) {
                    reject(x);
                }
            );
        });
    }

    @:from
    public static function ofJsPromise<A>(p: js.Promise<A>):Promise<A> {
        return new Promise<A>(function(y, n) p.then(y, n));
    }

#end

#if (tink || tink_core)

    @:from static public function ofTinkPromise<T>(promise: tink.core.Promise<T>):Promise<T> {
        // #if (js && !macro)
        // return ofJsPromise(@:privateAccess promise.toJsPromise());
        // #else
        return new Promise(function(accept, reject) {
            // tink.core.Promise.Next.
            promise.handle(function(o) {
                switch o {
                    case Success(result):
                        accept(result);

                    case Failure(error):
                        reject(error);
                }
            });
        });
        // #end
    }

#end

    public static function promisifySimple<T>(x: Dynamic):Promise<T> {
        if ((x is IDeferred<Dynamic, Dynamic>)) {
            return make(cast x);
        }
        else if ((x is Future<Dynamic, Dynamic>)) {
            return (cast cast(x, Future<Dynamic, Dynamic>) : Promise<T>);
        }
        else {
            throw new pm.Error('Invalid argument $x');
        }
    }

    @:from
    public static inline function make<T>(d: Deferred<T, Dynamic>):Promise<T> {
        return new TProm<T>( d );
    }

    /*
    @:from
    */
    public static inline function ofFuture<Result, Exception>(future: Future<Result, Exception>):Promise<Result> {
        return (future : TProm<Result>);
    }

    @:from
    public static inline function ofOutcome<Result, Exception>(outcome: Outcome<Result, Exception>):Promise<Result> {
        return make(outcome);
    }

    // @:from
    public static function flatten<T>(p: Promise<Promise<T>>):Promise<T> {
        return p.flatMap( Functions.identity );
    }

    @:from
    public static inline function resolve<T>(value: T):Promise<T> {
        return new TProm<T>(Deferred.result( value ));
    }

    public static inline function reject<T>(value: Dynamic):Promise<T> {
        return new TProm<T>(Deferred.exception( value ));
    }

    public static function trigger<T>(?forceAsync:Bool, ?isLazy:Bool, ?isCached:Bool):PTrig<T> {
        return new PTrig(forceAsync, isLazy);
    }
}

typedef TProm<T> = pm.async.Future<T, Dynamic>;
typedef TOut<T> = pm.Outcome.Outcome<T, Dynamic>;

@:callable
private abstract Next<In, Out>(In->Promise<Out>) from In->Promise<Out> {    
    @:from 
    static function ofSafeSync<In, Out>(f:In -> Out):Next<In, Out> {
        return function(x: In):Promise<Out> {
            return Promise.resolve(f(x));
        }
    }

    // @:from 
    // static function ofSafe<In, Out>(f:In -> Outcome<Out, Error>):Next<In, Out> {
    //     return function (x) return f(x);
    // }
        
    @:from 
    static function ofSync<In, Out, Err>(f:In -> Future<Out, Err>):Next<In, Out> {
        return function (x) return f(x);
    }
        
    @:op(a * b) 
    static function _chain<A, B, C>(a:Next<A, B>, b:Next<B, C>):Next<A, C>{
        return function (v) return a(v).next(b);
    }
}

@:callable
abstract Combiner<In1, In2, Out>(In1->In2->Promise<Out>) from In1->In2->Promise<Out> {
    // @:from 
    // static function ofSafe<In1, In2, Out>(f:In1 -> In2 -> Outcome<Out, Error>):Combiner<In1, In2, Out> {
    //     return function (x1, x2) return f(x1, x2);
    // }

    @:from 
    static function ofSafeSync<In1, In2, Out>(f:In1 -> In2 -> Out): Combiner<In1, In2, Out> {
        return function(x1:In1, x2:In2):Promise<Out>
            return Promise.resolve(f(x1, x2));
    }
    
    @:from 
    static function ofSync<In1, In2, Out>(f:In1 -> In2 -> Promise<Out>):Combiner<In1, In2, Out> {
        return function (x1, x2) return f(x1, x2);
    }
}

private class PTrig<Out> {
    var _config : {forceAsync:Bool, lazy:Bool};
    var d : pm.async.Deferred.AsyncDeferred<Out, Dynamic>;
    var _promise: Promise<Out> = null;

    @:allow(pm.async.Promise)
    function new(forceAsync=false, forceLazy=false) {
        d = Deferred.create();
        _config = {
            forceAsync: forceAsync,
            lazy: forceLazy
        };
    }

    public function trigger<Err>(o:Outcome<Out, Err>) {
        var res = (() -> d.resolve( o ));
        if ( _config.forceAsync )
            res = (f -> function() Callback.defer(f))(res);
        
        // var res = if (!_config.forceAsync) res() else Callback.defer(res); 
        // if ( forceAsync ) {
        //    Callback.defer(() -> d.resolve( o ))
        //}
        return res.call();
    }
    public function accept(value: Out) return trigger(Success(value));
    public function reject<Err>(error: Err) return trigger(Failure(error));

    public function asPromise():Promise<Out> {
        if (_promise == null) {
            _promise = Promise.make((d : Deferred<Out, Dynamic>));
        }
        return _promise;
    }
}
