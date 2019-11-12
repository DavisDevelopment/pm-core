package pm.async.impl;

import pm.async.impl.CommonTypes.OutcomePromiseObject;
import pm.async.impl.NPromise;
import pm.async.impl.AsyncPromiseObject;

import pm.Ref;
import pm.ObjectPool;
import pm.LinkedStack;
import pm.ImmutableList;
import pm.Noise;
import pm.Assert.assert;

using pm.Functions;

@:forward
@:forwardStatics(wrap, reduce)
@:access(pm.async.impl.PromiseHandle.PromiseHandleObject)
abstract PromiseHandle<T>(PromiseHandleObject<T>) from PromiseHandleObject<T> to PromiseHandleObject<T> {
    public inline function new(promise: NPromise<T>) {
        this = I.wrap(promise);
    }
}

private typedef I<T> = PromiseHandleObject<T>;

class PromiseHandleObject<T> {
    @:noCompletion
    public var promise(default, null): NPromise<T>;

    /**  [Analytics Fields]  **/
    private var _passedSanityChecks:Null<Bool> = null;
    private var _simplifyLink:Null<CallbackLink> = null;

    /**  Constructor Function  **/
    public function new(promise: NPromise<T>) {
        this.promise = promise;
    }

    public function validate(sanityChecks:Bool=true) {
        if (sanityChecks)
            this.sanityChecks();

        _passedSanityChecks = true;
    }

    private function sanityChecks() {
        assert(checkSyncCoherence(), new Error('Invalid sync coherence'));
    }

    /**
      checks that the value of `promise.isAsync` corresponds with the actual synchronicity of the promise
     **/
    private function checkSyncCoherence():Bool {
        final saysIsSync:Bool = (promise : PromiseObject<T>).isAsync;
        var isSync:Bool = false;
        var tmp = promise.always(function() {
            isSync = true;
        });
        if (!isSync) {
            tmp.cancel();
        }
        return (isSync == saysIsSync);
    }

    public inline function then(onFulfilled:Callback<T>, ?onError:Callback<Dynamic>) {
        return promise.then(onFulfilled, onError);
    }

    public inline function handle(onOutcome: Callback<Outcome<T, Dynamic>>) {
        return promise.handle(onOutcome);
    }

    public inline function always(onResolved: Void->Void) {
        return promise.always(onResolved);
    }

    public inline function map<O>(f: T -> O):PromiseHandle<O> return wrap(promise.map(f));
    public function flatMap<O>(f: T -> PromiseHandle<O>):PromiseHandle<O> {
        return wrap(promise.flatMap(f.map(h -> h.simplify().promise)));
    }
    public function next<O>(map: Outcome<T, Dynamic> -> PromiseHandle<O>):PromiseHandle<O> {
        return wrap(promise.next(map.map(h -> h.simplify().promise)));
    }
    public function transform<R>(outcomeMap: Outcome<T, Dynamic> -> Outcome<R, Dynamic>):PromiseHandle<R> {
        return wrap(promise.transform(outcomeMap));
    }
    public inline function merge<T2, R>(other:PromiseHandle<T2>, merger:Combiner<T, T2, R>):PromiseHandle<R> {
        return wrap(promise.merge(other.promise, merger));
    }

    public inline function noisify():PromiseHandle<pm.Noise> {
        return wrap(promise.noisify());
    }

    /**
      attempts to streamline/optimize [this] PromiseHandle<T> by replacing the underlying `NPromise<T>` with one more specialized to the task that it's performing
     **/
    public function simplify():PromiseHandle<T> {
        var p:PromiseObject<T> = promise;
        var ps:PromiseObject<T> = p.simplify();
        while (p != ps) {
            p = ps;
            ps = p.simplify();
        }
        this.promise = ps;
        return this;
    }

    function set_promise(new_promise: NPromise<T>):NPromise<T> {
        if (this.promise != null)
            detachFrom(this.promise);
        var ret = this.promise = new_promise;
        ret = (this.promise = attachTo(ret));
        return ret;
    }

    private function attachTo(p: PromiseObject<T>):PromiseObject<T> {
        var simplified = simplifyPromise(p);
        if (simplified == p) {
            /**
              [TODO] test for actual async behavior, rather than the `isAsync` flag in this particular case
             **/
            if (p.isAsync) {
                if (!Std.is(p, AsyncPromiseObject)) {
                    p = wrapPromiseInAsync(p);
                    return attachTo( p );
                }
                else {
                    var ap:AsyncPromiseObject<T> = cast p;
                    var unlinked = false, link:CallbackLink = function() {
                        unlinked = true;
                        _simplifyLink = null;
                    };
                    ap.setOnBecomeSync(function() {
                        if (!unlinked) {
                            this.simplify();
                        }
                    });
                    this._simplifyLink = link;
                }
            }
        }
        trace('.attachTo');
        return simplified;
    }

    private function detachFrom(p: PromiseObject<T>) {
        assert(p == this.promise, 'Cannot disconnect from a Promise that is connected');
        if (this._simplifyLink != null) {
            _simplifyLink.cancel();
        }
        @:bypassAccessor this.promise = null;
    }

    public static inline function isSimplestPromise<T>(p: PromiseObject<T>):Bool {
        var simplified = simplifyPromise(p);
        return (simplified == p);
    }

    private static inline function simplifyPromise<T>(promise: PromiseObject<T>):PromiseObject<T> {
        var simple:PromiseObject<T> = promise.simplify();
        while (simple != promise) {
            promise = simple;
            simple = promise.simplify();
        }
        return simple;
    }

    private static function wrapPromiseInAsync<T>(promise: PromiseObject<T>):AsyncPromiseObject<T> {
        if (Std.is(promise, AsyncPromiseObject)) {
            return cast promise;
        }
        else {
            assert(Std.is(promise, PromiseObject), new pm.Error('Invalid $promise'));
            
            return new AsyncPromiseObject(function(done) {
                promise.handle(function(outcome) {
                    done(outcome);
                });
            });
        }
    }

    /**
      [TODO] refactor to actually _wrap_ `p` in an `AsyncPromise<T>`
     **/
    public static function wrap<T>(p: PromiseObject<T>):PromiseHandle<T> {
        if (Std.is(p, AsyncPromiseObject)) {
            var ap:AsyncPromiseObject<T> = cast p;
            //
            if (ap.isSync()) {
                return new PromiseHandleObject(ap.simplify());
            }
            else {
                var handle:PromiseHandle<T> = new PromiseHandleObject((ap : NPromise<T>));
                ap.setOnBecomeSync(function update() {
                    handle.simplify();
                });
                return handle;
            }
        }
        else if (p.isAsync) {
            var wrapper:AsyncPromiseObject<T> = new AsyncPromiseObject(
                function(done) {
                    p.handle(function(o) {
                        done(o);
                    });
                }
            );
            return wrap(wrapper);
        }
        else {
            return new PromiseHandleObject(p).simplify();    
        }
    }

	public static function reduce<T, Agg>(array:Iterable<Promise<T>>, reducer:Agg->Outcome<T, Dynamic>->Agg, init:Agg):Promise<Agg> {
		var iter = array.iterator();
		var masterAgg:Agg = init;
		var trigger = Promise.trigger();
		function next() {
			if (iter.hasNext()) {
                trace('aww, yie');
				iter.next().handle(o -> {
					masterAgg = reducer(masterAgg, o);
					Defer.defer(next);
				});
			} 
            else {
                trace('dat\'s done, sha');
				trigger.resolve(masterAgg);
			}
		}

		var promise = Promise.createFromTrigger(trigger);
		next();
		return promise;
	}
}