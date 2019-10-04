package pm.async.impl;

#if js

import pm.async.impl.PromiseObject;
import pm.async.impl.AsyncPromiseObject;

import js.lib.Promise as JsPromise;

class JsPromiseObject<T> implements PromiseObject<T> {
    var promise:js.lib.Promise<T>;
    public var isAsync(get, never):Bool;

    public inline function new(promise) {
        this.promise = promise;
    }

    inline function get_isAsync():Bool {
        return false;
    }

    public function always(resolved: Void->Void):CallbackLink {
        var isCancelled:Bool = false;
        var link:CallbackLink = function() {
            isCancelled = true;
        };
        function callback() {
            if (!isCancelled)
                resolved();
        }
        link = link & then(callback, callback);
        return link;
    }

    public inline function then(yes:Callback<T>, ?nah:Callback<Dynamic>):CallbackLink {
        if (nah == null)
            promise.then(function(res: T) yes(res));
        else {
            promise.then(
                function(res: T) yes(res),
                function(err: Dynamic) nah(err)
            );
        }
        return pm.Functions.noop;
    }

    public function map<O>(f:T->O):PromiseObject<O> {
        return new JsPromiseObject(promise.then(function(res: T) {
            return js.lib.Promise.resolve(f(res));
        }));
    }

    static function toJsPromise<T>(po: PromiseObject<T>):js.lib.Promise<T> {
        if ((po is JsPromiseObject<T>))
            return (cast cast(po, JsPromiseObject<Dynamic>).promise : js.lib.Promise<T>);
        else {
            return new js.lib.Promise(function(resolve, reject) {
                po.then(resolve, reject);
            });
        }
    }

    public function flatMap<O>(f: T -> PromiseObject<O>):PromiseObject<O> {
        return new JsPromiseObject(promise.then(function(result: T) {
            return toJsPromise(f(result));
        }));
    }

    public function handle(f:Callback<Outcome<T, Dynamic>>):CallbackLink {
        var link:CallbackLink;
        var outcome:Null<Outcome<T, Dynamic>> = null;
        function cb(o) {
            if (outcome == null) {
                outcome = o;
                f(outcome);
            }
            else {
                throw new pm.Error('Invalid call');
            }
        }
        link = then(result->cb(Success(result)), error->cb(Failure(error)));
        return link;
    }

    public function next<O>(f: Outcome<T, Dynamic> -> PromiseObject<O>):PromiseObject<O> {
		return (function(done) {
            handle(function(o) {
                f(o).handle(done);
            });
        } : NPromise<O>);
    }

    public inline function simplify():PromiseObject<T> {
        return this;
    }
}

class JsPromiseTrigger<T> extends JsPromiseObject<T> implements PromiseTriggerObject<T> {
    var _resolve:T->Void;
    var _reject:Dynamic->Void;
    public function new() {
        var jsp = new js.lib.Promise(function(res, rej) {
            _resolve = res;
            _reject = rej;
        });
        super(jsp);
    }
    public inline function resolve(result: T):Bool {
        _resolve(result);
        return true;
    }
    public inline function reject(error: Dynamic):Bool {
        _reject(error);
        return true;
    }
    public inline function asPromise():PromiseObject<T> {
        return this;
    }
}

#end
