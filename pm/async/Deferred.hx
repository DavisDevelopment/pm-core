package pm.async;

import pm.Error;
import pm.Assert.assert;
import pm.Noise;
import pm.Outcome;

import pm.async.impl.Future as FutureDeferred;
import pm.async.impl.Future.DTrigger;

@:forward
abstract Deferred<Val, Err> (IDeferred<Val, Err>) from IDeferred<Val, Err> to IDeferred<Val, Err> {
/* === Methods === */

    public function isResolved():Bool {
        return this.state.match(Resolved(_));
    }

    public function getResolution():DeferredResolution<Val, Err> {
        return switch ( this.state ) {
            case Resolved(r): r;
            default:
                throw new InvalidOperation('Deferred.getResolution');
        }
    }

    public function hasResult():Bool {
        return this.state.match(Resolved(Result(_)));
    }

    public function hasException():Bool {
        return this.state.match(Resolved(Exception(_)));
    }

    public function sync():Val {
        assert(isResolved(), new InvalidOperation('Deferred.sync'));
        switch (getResolution()) {
            case Result(x):
                return x;

            case Exception(x):
                throw x;
        }
    }

/* === Factories === */

    public static function ofResolution<R, E>(resolution:DeferredResolution<R, E>):Deferred<R, E> {
        switch resolution {
            case _:
                //
        }
        return new SyncDeferred(resolution);
    }

    @:from
    public static inline function resolution<V,E>(res: DeferredResolution<V, E>):Deferred<V, E> {
        return new SyncDeferred( res );
    }

    @:from
    public static inline function lazyResolution<V, E>(res: Lazy<DeferredResolution<V, E>>):Deferred<V, E> {
        return new SyncDeferred(res.get());
    }

    @:from
    static inline function ofError<V>(error: pm.Error):Deferred<V, Error> {
        return Exception(error);
    }

    @:from
    static function ofOutcome<V, E>(o: Outcome<V, E>):Deferred<V, E> {
        return switch o {
            case Success(res): Result(res);
            case Failure(error): Exception(error);
        }
    }

    public static inline function exception<T, E>(e: E):Deferred<T, E> {
        return resolution(Exception( e ));
    }

    @:from
    public static function nilad<T>(m: Void -> T):Deferred<T, Dynamic> {
        return try result(m()) catch (e: Dynamic) exception( e );
    }

    //public static function mAsync<V, E>(exec:(yes:V->Void, nah:E->Void)->Void):Deferred<V, E> {
    // @:from
    public static function asyncBase<V, E>(exec:(dv:AsyncDeferred<V, E>)->Void, sync:Bool=false):Deferred<V, E> {
        var out = new AsyncDeferred<V, E>();
        exec(out);
        return out;
    }

    public static function create<V,E>():AsyncDeferred<V, E> {
        return new AsyncDeferred<V,E>();
    }

    @:from
    public static function outcomeCallback<V,E>(exec:Callback<Outcome<V, E>>->Void):Deferred<V, E> {
        return asyncBase(function(d) {
            exec(function(o: Outcome<V, E>) {
                switch o {
                    case Success(x):
                        d.done( x );

                    case Failure(x):
                        d.fail( x );
                }
            });
        });
    }
    
    @:from
    public static function successCallback<V,E>(exec:Callback<V>->Void):Deferred<V, E> {
        return asyncBase(function(d) {
            exec(function(result: V) {
                d.done(result);
            });
        });
    }

    @:from
    public static function monadicAsync<V, E>(exec: (resolve:V->Void)->Void):Deferred<V, E> {
        return asyncBase(function(d: Deferred<V, E>) {
            exec(function(result: V) {
                d.done( result );
            });
        });
    }

    @:from
    public static function dyadicAsync<V, E>(exec: (resolve:V->Void, reject:E->Void)->Void):Deferred<V, E> {
        return asyncBase(function(d: Deferred<V, E>) {
            exec(
                function(result: V) {
                    d.done( result );
                },
                function(except: E) {
                    d.fail( except );
                }
            );
        });
    }

    @:from
    public static function dyadicCbAsync<V, E>(exec: (?V -> ?E -> Void) -> Void):Deferred<V, E> {
        return dyadicAsync(function(yes, no) {
            exec(function(?result:V, ?exception:E) {
                switch [result, exception] {
                    case [_, null]:
                        yes( result );

                    case [_, _]:
                        no( exception );
                }
            });
        });
    }

    @:from
    public static inline function result<T, E>(v: T):Deferred<T, E> {
        return resolution(Result( v ));
    }
}

class SyncDeferred<V, E> implements IDeferred<V, E> {
    public function new(resolution: DeferredResolution<V, E>):Void {
        this.state = Resolved( resolution );
    }

    public inline function done(x: V) {
        throw new NotImplementedError();
    }

    public inline function fail(x: E) {
        throw new NotImplementedError();
    }

    public inline function handle(fn: Callback<DeferredResolution<V, E>>) {
        fn.invoke(switch state {
            case Resolved(x): x;
            case _: throw new WTFError();
        });
    }

    public var state(default, null): DeferredState<V, E>;
}

class AsyncDeferred<V, E> implements IDeferred<V, E> {
    public function new() {
        state = Pending;
        // this.trigger = FutureDeferred.trigger();
        this.t = new DTrigger();
        this.future = FutureDeferred.async(function(set) {
            t.listen(function() {
                set(switch state {
                    case Resolved(r): r;
                    default: throw new pm.Error.WTFError();
                });
            });
        });
    }

    public function handle(cb: Callback<DeferredResolution<V, E>>):Void {
        switch ( state ) {
            case Resolved(res):
                cb.invoke( res );

            default:
                future.handle(cb);
        }
    }

    public function done(x: V) {
        assert(
            !state.match(Resolved(_)), 
            new InvalidOperation('Deferred<*, *> instance is already resolved; cannot resolve again')
        );
        triggerWithResolution(Result(x));
    }

    public function fail(x: E) {
        assert(!state.match(Resolved(_)), new InvalidOperation('Deferred<*, *> instance is already resolved; cannot resolve again'));
        triggerWithResolution(Exception(x));
    }

    public inline function triggerWithResolution(resolution: DeferredResolution<V, E>) {
        // var res;
        state = Resolved(resolution);
        trigger(switch resolution {
            case Result(r): Success(r);
            case Exception(e): Failure(e);
        });
    }


    public function trigger(outcome: Outcome<V, E>) {
        // var res;
        // state = Resolved(res = switch outcum {
        //     case Success(r): Result(r);
        //     case Failure(e): Exception(e);
        // });

        t.trigger(outcome);

    }
    @:deprecated('resolve is deprecated. Use .trigger instead')
    public inline function resolve(o) {
        trigger(o);
    }

    public var state(default, null): DeferredState<V, E>;
    // private var trigger:pm.async.impl.Future.FutureTrigger<DeferredResolution<V, E>>;
    public var t(default, null): DTrigger<V, E>;
    private var future(default, null):pm.async.impl.Future<DeferredResolution<V, E>>;
}

interface IDeferred<Value, Except> {
    var state(default, null): DeferredState<Value, Except>;

    function done(value: Value):Void;
    function fail(error: Except):Void;

    function handle(onResolved: Callback<DeferredResolution<Value, Except>>):Void;

    //@:noCompletion
    //var _handler(default, set): (r: DeferredResolution<Value, Except>)->Void;
}

@:using(pm.async.Deferred.DeferredStateTools)
enum DeferredState<A, B> {
    Pending;
    //Running;
    //Waiting<C, D>(link: IDeferred<C, D>);
    Resolved(res: DeferredResolution<A, B>);
}

@:using(pm.async.Deferred.DeferredResolutionTools)
enum DeferredResolution<A, B> {
    Result(x: A);
    Exception(x: B);
}

class DeferredResolutionTools {
    public static function toOutcome<V, E>(res: DeferredResolution<V, E>):Outcome<V, E> {
        return switch ( res ) {
            case Result(x): Success(x);
            case Exception(x): Failure(x);
        }
    }

    public static function isResult(r: DeferredResolution<Dynamic, Dynamic>):Bool {
        return r.match(Result(_));
    }

    public static function isException(r: DeferredResolution<Dynamic, Dynamic>):Bool {
        return r.match(Exception(_));
    }

    public static function getResult<T>(r: DeferredResolution<T, Dynamic>):T {
        return switch r {
            case Result(x): x;
            default:
                throw new InvalidOperation('DeferredResolution.getResult');
        }
    }
    public static function getException<T>(r: DeferredResolution<Dynamic, T>):T {
        return switch r {
            case Exception(x): x;
            default:
                throw new InvalidOperation('DeferredResolution.getException');
        }
    }
}

class DeferredStateTools { }
