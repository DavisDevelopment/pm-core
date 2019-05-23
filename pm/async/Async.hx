package pm.async;

import pm.Functions.fn;

import pm.HashKey;
import pm.LinkedQueue;

import haxe.ds.Option;

using pm.Arrays;
using pm.Iterators;
using pm.Functions;
using pm.Options;
using pm.Outcome;

@:forward
abstract Async<I, O>(AsyncObject<I, O>) from AsyncObject<I,O> to AsyncObject<I, O> {
    public static inline function make<I, O>(func: AsyncFn<I, O>):Async<I, O> {
        return new FuncAsync<I, O>(func);
    }
    @:from
    public static inline function ofOutcomeDyad<I, O>(func:I->Callback<Result<O>>->Void):Async<I, O> {
        return make(function(input: I):Handle<O> {
            return new Promise<Result<O>>(function(yes, _) {
                func(input, function(res: Result<O>) {
                    yes(res);
                });
            });
        });
    }
    @:from
    public static inline function ofJsStyleDyad<I, O>(func:(input:I, callback:(?result:O, ?error:Dynamic)->Void)->Void):Async<I, O> {
        return ofOutcomeDyad(function(input:I, cb:Callback<Result<O>>) {
            func(input, function(?res:O, ?err:Dynamic) {
                if (err != null) {
                    cb.invoke(Failure(err));
                }
                else {
                    cb.invoke(Success(res));
                }
            });
        });
    }
}

interface AsyncObject<Input, Output> {
    var key(default, null): Int;
    function invoke(input: Input):Handle<Output>;
}

class AsyncBase<I, O> implements AsyncObject<I, O> {
    function new() {
        //
    }

    public function invoke(input: I):Handle<O> {
        return Handle.exception('NotImplemented');
    }

    public var key(default, null):Int = HashKey.next();
}
class FuncAsync<I, O> extends AsyncBase<I, O> {
    var f: AsyncFn<I, O>;
    public function new(func) {
        f = func;
        super();
    }

    override function invoke(i: I):Handle<O> {
        return f.invoke( i );
    }
}

typedef Result<T> = Outcome<T, Dynamic>;

typedef THandle<T> = Promise<Result<T>>;
@:forward
abstract Handle<T> (THandle<T>) from THandle<T> to THandle<T> {
    @:from public static inline function ofTPromise<T>(p: Promise<T>):Handle<T> {
        return p.outcome();
    }
    @:from public static inline function sync<T>(o: Result<T>):Handle<T> {
        return Promise.resolve( o );
    }
    @:from public static inline function result<T>(v: T):Handle<T> return sync(Success(v));
    @:from public static inline function exception<T>(err: Dynamic):Handle<T> return sync(Failure(err));
}

@:forward
@:using(pm.Functions)
@:callable
abstract AsyncFn<I, O> (I -> Handle<O>) from I -> Handle<O> to I -> Handle<O> {
    @:selfCall
    public function invoke(i: I):Handle<O> {
        return this(i);
    }
    @:from public static inline function ofSync<I,O>(f: I -> O):AsyncFn<I, O> {
        return function(i: I):Handle<O> {
            return Handle.result(f(i));
        }
    }
    @:from public static inline function ofSyncOutcome<I, O>(f: I -> Result<I>):AsyncFn<I, O> {
        return function(i: I):Handle<O> {
            return Handle.sync(f(i));
        }
    }
}

typedef TF0 = Option<Dynamic> -> Void;
@:forward
@:callable
@:using(pm.Functions)
abstract VCb (TF0) from TF0 to TF0 {
    public inline function done() {
        this.call(None);
    }

    public inline function fail(error: Dynamic) {
        this.call(Some(error));
    }

    @:op(a + b)
    public static function join(a:VCb, b:VCb):VCb {
        return a.join(b);
    }

    @:from public static function jsStyle(fn:(error:Null<Dynamic>)->Void):VCb {
        return function(error: Option<Dynamic>) {
            return fn(switch error {
                case None: null;
                case Some(error): error;
            });
        }
    }
    @:from public static function jsStyle2(fn:(?error:Dynamic)->Void):VCb {
        return function(error: Option<Dynamic>) {
            return fn(switch error {
                case None: null;
                case Some(error): error;
            });
        }
    }
    @:from public static inline function ignoreError(fn: Void -> Void):VCb {
        return function(_) {
            return fn();
        }
    }
}
typedef TF1 = VCb -> Void;
typedef Va = VoidAsync;

@:forward
@:callable
@:using(pm.Functions)
@:using(pm.async.Async.VoidAsyncs)
abstract VoidAsync(TF1) from TF1 to TF1 {
    @:op(A & B)
    public static inline function join(a:VoidAsync, b:VoidAsync):VoidAsync {
        return function(done: VCb) {
            a(function(res) {
                if (res.isSome())
                    done(res);
                else {
                    b(done);
                }
            });
        }
    }

    @:from public static inline function make(fn: VCb -> Void):VoidAsync {
        return function(cb: VCb) {
            fn(cb);
        }
    }

    @:from public static function jsStyle(fn: (done: (error:Null<Dynamic>)->Void)->Void):VoidAsync {
        return function(done: VCb) {
            fn(function(error:Null<Dynamic>) {
                switch error {
                    case null:
                        done.done();

                    case _:
                        done.fail(error);
                }
            });
        }
    }

    @:from public static function jsStyle2(fn: (done: (?error:Dynamic)->Void)->Void):VoidAsync {
        return function(done: VCb) {
            fn(function(?error:Dynamic) {
                switch error {
                    case null:
                        done.done();

                    case _:
                        done.fail(error);
                }
            });
        }
    }
}

class VoidAsyncs {
    public static function queue(a:Array<VoidAsync>, complete:VCb) {
        var _finished_ = {};
        function next() {
            function ncb(err:Option<Dynamic>) {
                switch err {
                    case Some(error):
                        if (error == _finished_) {
                            complete.done();
                        }
                        else {
                            complete.fail(error);
                        }

                    case None:
                        next();
                }
            }

            if (a.empty()) {
                return ncb(Some(_finished_));
            }

            var f = a.shift();
            f.call( ncb );
        }
        next();
    }

    public static function pool(a:Array<VoidAsync>, complete:VCb) {
        var finished:Int = 0, lastLength:Int = a.length;
        var interrupt = {};
        var nextCb;
        inline function fwdFeed() {
            for (i in lastLength...a.length) {
                a[i](nextCb);
            }
        }
        nextCb = function(?error: Dynamic) {
            if (error != null) {
                if (error == interrupt) {
                    complete.done();
                }
                else {
                    complete.fail(error);
                }
            }
            else {
                finished++;
                if (lastLength != a.length) {
                    fwdFeed();
                }
                if (finished == a.length) {
                    complete.done();
                }
            }
        }
            
        for (va in a) {
            va.call( nextCb );
        }
    }

    public static function createPooler<T>(make: T -> VoidAsync):Array<T> -> VCb -> Void {
        return function(elems: Array<T>, done:VCb) {
            pool(elems.map(make), done);
        }
    }
}