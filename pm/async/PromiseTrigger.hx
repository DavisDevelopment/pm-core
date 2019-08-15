package pm.async;

import pm.async.Callback;
import pm.async.*;

#if js
import js.lib.Promise as JsPromise;
#end

import pm.Functions.fn;

using pm.Functions;
using pm.Arrays;
using pm.Iterators;
using pm.Outcome;

class PromiseTrigger<TRes, TErr> {
    var t: FutureTrigger<Outcome<TRes, TErr>>;
    public function new() {
        t = new FutureTrigger();
    }

    public function trigger(result: PromiseTriggerRes<TRes, TErr>):Bool {
        return t.trigger(result);
    }

    public function handle(cb: Callback<Outcome<TRes, TErr>>):CallbackLink {
        return t.handle( cb );
    }
    public function then(success:Callback<TRes>, ?failure:Callback<TErr>):CallbackLink {
        return handle(function(o) {
            switch o {
                case Success(result): 
                    success.invoke(result);

                case Failure(error) if (failure != null):
                    failure.invoke(error);
                default:
            }
        });
    }
    public function asPromise():Promise<TRes> {
        var tp = t;//.gather();//asPromise();
        return new Promise<TRes>(function(yes:Callback<TRes>, nah:Callback<TErr>) {
            tp.handle(function(o) {
                switch o {
                    case Success(result):
                        yes.invoke(result);
                    
                    case Failure(error):
                        nah.invoke(error);
                }
            });
        });
    }
}

@:forward
abstract PromiseTriggerRes<A,B> (Outcome<A, B>) from Outcome<A, B> to Outcome<A, B> {
    @:from
    static inline function success<A,B>(res: A):PromiseTriggerRes<A, B> {
        return Success(res);
    }

    @:from
    static inline function failure<A,B>(err: B):PromiseTriggerRes<A, B> {
        return Failure(err);
    }
}

class FutureTrigger<T> {
    var result: T;
    var list: CallbackList<T>;

    public function new() {
        this.list = new CallbackList();
    }
    
    public function handle(callback: Callback<T>):CallbackLink {
        return switch list {
            case null: 
                callback.invoke(result);
                null;
            
            case v:
                v.add(callback);
        }
    }

    public function map<R>(f: T -> R): Promise<R> {
        return switch list {
            case null: Promise.resolve(f(result));
            case v:
                var ret = new FutureTrigger();
                list.add(function (v) ret.trigger(f(v)));
                ret.asPromise();
        }
    }

    public function flatMap<R>(f: T -> pm.async.Promise<R>):Promise<R> {
        return switch list {
            case null: f(result);
            case v:
                var ret = new FutureTrigger();
                list.add(function (v) f(v).then(fn(ret.trigger(_))));
                ret.asPromise();
            }
    }

    /*
    public inline function gather()
        return this;

    public function eager()
        return this;

    public inline function asFuture():Future<T> {
        return this;
    }

    @:noUsing 
    static public function gatherFuture<T>(f:Future<T>):Future<T> {
        var op = null;
        return new Future<T>(function (cb:Callback<T>) {
        if (op == null) {
            op = new FutureTrigger();
            f.handle(op.trigger);
            f = null;        
        }
        return op.handle(cb);
        });  
    }
    */

    /**
    *  Triggers a value for this future
    */
    public function trigger(result: T):Bool {
        return
        if (list == null) false;
        else {
            var list = this.list;
            this.list = null;
            this.result = result;
            list.invoke(result);
            list.clear();//free callback links          
            true;
        }
    }

    static public function gatherFuture<T>(p: Promise<T>):Promise<T> {
        var op = null;
        return new Promise<T>(function(cb: Callback<T>) {
            if (op == null) {
                op = new FutureTrigger();
                p.then(function(x) op.trigger(x));
                p = null;
            }
            return op.handle(cb);
        });
    }

    public function asPromise():Promise<T> {
        var p = new Promise<T>(pm.async.Deferred.successCallback(function(cb) handle(cb)));
        // return gatherFuture(new Promise<T>(Deferred.this.handle);
        // throw 'suck dat booty';
        return p;
    }
    public inline function gather():Promise<T> {
        return gatherFuture(asPromise());
    }
}