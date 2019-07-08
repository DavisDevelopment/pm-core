package pm.async;

import pm.Error.NotImplementedError;
import pm.Noise;
import pm.Outcome;

import pm.async.Callback;
import pm.async.Callback.CallbackLink;
import pm.async.Deferred;

using pm.Functions;

class Future<Val, Err> {
    public var key(default, null):Int = HashKey.next();
    public var tail(default, null):FutureHandle<Val, Err>;

    var d(default, null): Deferred<Val, Err>;

    var ss:{v:Signal<Val>, e:Signal<Err>} = null;
    var _o:Null<Outcome<Val, Err>> = null;
    //var 

    public function new(base:Deferred<Val, Err>):Void {
        this.d = base;
        this.tail = new FutureHandle(this);
        var needSigs = true;
        this.d.handle(function(r: DeferredResolution<Val, Err>) {
            switch ( r ) {
                case Result(x):
                    _o = Success( x );
                    if (ss != null) 
                        ss.v.broadcast( x );

                case Exception(x):
                    _o = Failure( x );
                    if (ss != null)
                        ss.e.broadcast( x );
            }

            needSigs = false;
        });

        if (_o == null) {
            ss = {
                v: new Signal<Val>(),
                e: new Signal<Err>()
            };
        }
    }

    /**
      handle the "thrown" exception
     **/
    public function catchException(onErr: Err -> Void) {
        if (ss != null) {
            ss.e.listen( onErr );
            // ss.e.listen
        }
        else if (_o != null) {
            switch _o {
                case Failure(e):
                    onErr( e );
                case _:
                    //
            }
        }
        else {
            throw new Error();
        }
    }

    /**
      [TODO] have `then` return a `CallbackLink`, or perhaps a `Maybe<CallbackLink>`
     **/
    public function then(onRes:Val->Void, ?onErr:Err->Void):CallbackLink {
        //d.handle(_handleCb(onRes, onErr));
        if (ss != null) {
            var lnk = ss.v.listen(onRes);
            if (onErr != null)
                lnk = lnk & ss.e.listen(onErr);
            return lnk;
        }
        else if (_o != null) {
            switch ( _o ) {
                case Success(x):
                    onRes( x );

                case Failure(x):
                    if (onErr != null)
                        onErr( x );
            }
            return (function() trace('foo'));
        }
        else { 
            trace( this );
            throw new Error();
        }
    }

    public function handle(cb: Callback<Outcome<Val, Err>>):CallbackLink {
        var done = (x -> cb.invoke( x )).once();
        var l = then(
            done.compose((v: Val) -> Outcome.Success( v )),
            done.compose((e: Err) -> Outcome.Failure( e ))
        );
        return l;
    }

    public function omap<OVal, OErr>(fn: Outcome<Val, Err> -> Outcome<OVal, OErr>):Future<OVal, OErr> {
        return new Future<OVal, OErr>(Deferred.asyncBase(function(d) {
            handle(function(o: Outcome<Val, Err>) {
                switch fn( o ) {
                    case Success(res):
                        d.done( res );

                    case Failure(err):
                        d.fail( err );
                }
            });
        }));
    }

    public function map<T>(fn: Val -> T):Future<T, Err> {
        return omap(function(o: Outcome<Val, Err>) {
            return switch o {
                case Success(x): Success(fn( x ));
                case Failure(x): Failure( x );
            }
        });
    }

    public function flatMap<T>(fn: Val -> Future<T, Err>):Future<T, Err> {
        return new Future(function(exit: Callback<Outcome<T, Err>>) {
            handle(function(o: Outcome<Val, Err>) {
                switch o {
                    case Success(x):
                        fn( x ).handle( exit );

                    case Failure(x):
                        exit.invoke(Outcome.Failure( x ));
                }
            });
        });
    }

    /**
      obtain a Promise for the Outcome<Val, Err> of [this] Future
     **/
    public function outcome():Promise<Outcome<Val, Err>> {
        return new Promise<Outcome<Val, Err>>(function(resolve) {
            handle(function(o: Outcome<Val, Err>) {
                resolve( o );
            });
        });
    }

    public static inline function ofOutcomePromise<Val, Err>(prom: Promise<Outcome<Val, Err>>):Future<Val, Err> {
        return new Future<Val, Err>(function(res: Callback<Outcome<Val, Err>>) {
            prom.then(function(o: Outcome<Val, Err>) {
                res.invoke( o );
            });
        });
    }
}

class FutureHandle<T, Err> {
    public var owner(default, null): Future<T, Err>;
    public function new(f) {
        this.owner = f;
    }

    public function flatMap<O, OErr>(fn: Outcome<T, Err> -> Future<O, OErr>):Future<O, OErr> {
        return new Future(function(done) {
            owner.handle(function(outcome) {
                fn(outcome).handle(done);
            });
        });
    }
}