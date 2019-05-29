package pm.async;

import pm.Error.NotImplementedError;
import pm.Noise;
import pm.Outcome;

import pm.async.Callback;
import pm.async.Deferred;
import pm.async.Future;

import pm.Functions.fn as mfn;

using pm.Functions;

@:forward
abstract Promise<T> (TProm<T>) from TProm<T> to TProm<T> {
    public inline function new(d: Deferred<T, Dynamic>) {
        this = new Future<T, Dynamic>( d );
    }

    public function then(resolved:Callback<T>, ?rejected:Callback<Dynamic>):Promise<T> {
        this.then((x -> resolved.invoke(x)), rejected != null ? (x -> rejected.invoke(x)) : null);
        return this;
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

    public function derive<O>(fn:(root:Promise<T>, accept:O->Void, reject:Dynamic->Void)->Void):Promise<O> {
        var dd = Deferred.create();
        fn(this, mfn(dd.done(_)), mfn(dd.fail(_)));
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

    @:from
    public static inline function make<T>(d: Deferred<T, Dynamic>):Promise<T> {
        return new TProm<T>( d );
    }

    @:from
    public static function flatten<T>(p: Promise<Promise<T>>):Promise<T> {
        return p.flatMap( Functions.identity );
    }

    public static inline function resolve<T>(value: T):Promise<T> {
        return new TProm<T>(Deferred.result( value ));
    }

    public static inline function reject<T>(value: Dynamic):Promise<T> {
        return new TProm<T>(Deferred.exception( value ));
    }
}

typedef TProm<T> = pm.async.Future<T, Dynamic>;
typedef TOut<T> = pm.Outcome.Outcome<T, Dynamic>;
