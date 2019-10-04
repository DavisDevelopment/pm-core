package pm.async;

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

    public function inspect(?pos: haxe.PosInfos):Promise<T> {
        this.handle(function(outcome) {
            trace(outcome, pos);
        });
        return this;
    }

    public static function all<T>(promises: Array<Promise<T>>):Promise<Array<T>> {
        var llAll = NPromise.inParallel(promises.map(p -> p.underlying));
        return create(llAll);
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
    @:from public static inline function createSync<T>(outcome: Lazy<Outcome<T, Dynamic>>):Promise<T> {
        return create(NPromise.sync(outcome));
    }
    @:from public static inline function sync<T>(outcome: Outcome<T, Dynamic>):Promise<T> {
        return createSync(outcome);
    }
    @:from public static function deferred<T>(deferred: Deferred<T, Dynamic>):Promise<T> {
        return async(function(done) {
            deferred.handle(function(resolution) {
                switch resolution {
                    case Result(x): done(Success(x));
                    case Exception(x): done(Failure(x));
                }
            });
        });
    }

    @:from public static function resolve<T>(value: T):Promise<T> {
        return NPromise.resolve(value);
    }
    
    public static function reject<T>(error: Dynamic):Promise<T> {
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
}