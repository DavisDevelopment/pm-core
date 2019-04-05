package pm.async;

import pm.Error.NotImplementedError;
import pm.Noise;
import pm.Outcome;

import pm.async.Callback;
import pm.async.Deferred;
import pm.async.Future;

@:forward
abstract Promise<T> (TProm<T>) from TProm<T> to TProm<T> {
    public inline function new(d: Deferred<T, Dynamic>) {
        this = new Future<T, Dynamic>( d );
    }

    public inline function then(resolved:Callback<T>, ?rejected:Callback<Dynamic>):Promise<T> {
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

    @:from
    public static inline function make<T>(d: Deferred<T, Dynamic>):Promise<T> {
        return new TProm<T>( d );
    }
}

typedef TProm<T> = pm.async.Future<T, Dynamic>;
typedef TOut<T> = pm.Outcome.Outcome<T, Dynamic>;
