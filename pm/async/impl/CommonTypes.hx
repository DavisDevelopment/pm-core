package pm.async.impl;

import pm.Object.Doc;
import pm.async.impl.PromiseObject;
import pm.async.impl.AsyncPromiseObject;
import pm.async.impl.Future.FutureTrigger;

import pm.Functions.noop;

import pm.Error;

class FuturePromiseObject<T> implements PromiseObject<T> {
	// var trigger:pm.async.impl.Future.FutureTrigger<Outcome<T, Dynamic>>;
	private var future:pm.async.impl.Future<Outcome<T, Dynamic>>;
	public var isAsync(get, never):Bool;

	public function new(future:Future<Outcome<T, Dynamic>>) {
		// trigger = pm.async.impl.Future.trigger();
		// future = trigger.asFuture();
		this.future = future;
	}

	public inline function get_isAsync():Bool @:privateAccess {
		return true;
	}

	public function then(resolved:Callback<T>, ?rejected:Callback<Dynamic>):CallbackLink {
		return _then(this, resolved, rejected);
	}

	public inline function always(f: Void->Void):CallbackLink {
		return handle(f);
	}

	public inline function map<O>(f:T->O):PromiseObject<O> {
		return new FuturePromiseObject(future.map(o -> switch o {
			case Success(res): Success(f(res));
			case Failure(e): Failure(e);
		}));
	}

	public function flatMap<O>(f:T->PromiseObject<O>):PromiseObject<O> {
		return next(function(out:Outcome<T, Dynamic>) {
			return switch out.map(f) {
				case Success(promise): promise;
				case Failure(error): new FailurePromise(error);
			}
		});
	}

	public inline function handle(f:Callback<Outcome<T, Dynamic>>):CallbackLink {
		return future.handle(f);
	}

	public function next<O>(nxt:Outcome<T, Dynamic>->PromiseObject<O>):PromiseObject<O> {
		// throw 'Not Implemented';
		return new FuturePromiseObject<O>(future.flatMap(function(out) {
			return toFuture(nxt(out));
		}));
	}

	public inline function simplify():PromiseObject<T> {
		return this;
	}

	static inline function toFuture<O>(promise:PromiseObject<O>):Future<Outcome<O, Dynamic>> {
		return Future.async(function(done) {
			promise.handle(function(outcome:Outcome<O, Dynamic>) {
				done(outcome);
			});
		});
	}

	static function _then<T>(self:FuturePromiseObject<T>, onFulfilled:Callback<T>, ?onRejected:Callback<Dynamic>):CallbackLink {
		// var solved:Bool = false,
		//     link:CallbackLink = function() solved = true;
		return self.future.handle(function(o) {
			switch o {
				case Success(result):
					onFulfilled(result);
				case Failure(error):
					if (onRejected != null)
						onRejected(error);
			}
		});
	}
}

/**
  a PromiseTrigger<T> which uses a Future as the underlying mechanism
 **/
class FuturePromiseTrigger<T> extends FuturePromiseObject<T> implements PromiseTriggerObject<T> {
	var t : FutureTrigger<Outcome<T, Dynamic>>;

	public function new() {
		this.t = Future.trigger();
		super(t.asFuture());
	}

	public inline function resolve(res:T):Bool {
		return t.trigger(Success(res));
	}

	public inline function reject(err:Dynamic):Bool {
		return t.trigger(Failure(err));
	}

	public inline function trigger(o: Outcome<T, Dynamic>):Bool {
		return t.trigger(o);
	}

	public inline function asPromise():PromiseObject<T> {
		return this;
	}
}

/**
	a `Promise<T>` class which is based upon an `Outcome<T, Dynamic>` value, which is provided to the constructor
**/
class OutcomePromiseObject<T> implements PromiseObject<T> {
	public var outcome(default, null) : Outcome<T, Dynamic>;
	public var resolution(get, never):Outcome<T, Dynamic>;
	// public var forceAsync(default, null):Bool = false;
	public var options(default, null):SyncPromiseOptions<T>;
	static var defaultOptions:SyncPromiseOptions<Dynamic> = {
		wrapAsync: false,
		forceAsync: false,
		useAsyncCallbacks: false
	};

	public var isAsync(get, never):Bool;
	public inline function get_isAsync():Bool return false;

	public function new(?options) {
		// resolution = r;
		this.options = nor(options, defaultOptions);
	}

	/* === [Instance Methods] === */
	private inline function get_resolution() {
		return outcome;
	}

	public inline function always(onResolution: Void->Void):CallbackLink {
		onResolution.call();
		return noop;
	}

	public inline function simplify():PromiseObject<T> {
		return this;
	}

	public inline function then(res:Callback<T>, ?err:Callback<Dynamic>):CallbackLink {
		return handle(function(o) switch o {
			case Success(v): res(v);
			case Failure(e):
				if (err != null)
					err(e);
		});
	}

	public inline function map<O>(f:T->O):PromiseObject<O> {
		return new SyncPromise(outcome.map(f));
	}

	public function flatMap<O>(f:T -> PromiseObject<O>):PromiseObject<O> {
		return next(function(out:Outcome<T, Dynamic>) {
			return switch out.map(f) {
				case Success(promise): promise;
				case Failure(error): new FailurePromise(error, cast options);
			}
		});
	}

	public inline function handle(f: Callback<Outcome<T, Dynamic>>):CallbackLink {
		if (options.useAsyncCallbacks || options.forceAsync) {
			return Defer.defer(function() {
				f(resolution);
			});
		} 
		else {
			f(resolution);
			return noop;
		}
	}

	public inline function next<O>(f:Outcome<T, Dynamic>->PromiseObject<O>):PromiseObject<O> {
		return CommonPromiseMethods.createAsync1(function(callback) {
			return handle(function(outcome) {
				f(outcome).handle(callback);
			});
		});
	}
}

class ResultPromise<T> extends OutcomePromiseObject<T> {
	public var result:T;

	public function new(value:T, ?options) {
		this.result = value;
		this.outcome = Success(this.result);
		// throw this.result;
		super(options);
	}
}

class FailurePromise<T> extends OutcomePromiseObject<T> {
	public var error:Dynamic;

	public inline function new(error:Dynamic, ?options) {
		this.error = error;
		this.outcome = Failure(this.error);
		super(options);
	}
}

class SyncPromise<T> extends OutcomePromiseObject<T> {
	public function new(out:Outcome<T, Dynamic>, ?options) {
		this.outcome = out;
		super(options);
	}

	public static function create<T>(outcome, ?options):PromiseObject<T> {
		var o = @:privateAccess Arch.clone_object(OutcomePromiseObject.defaultOptions, ShallowRecurse);
		if (options != null) {
			Arch.clone_object_onto(options, o);
		}
		var wrap = o.wrapAsync ? {force:nor(o.forceAsync, false)} : null;
		if (wrap == null) {
			// no async-wrapping
			return new SyncPromise(outcome, o);
		}
		else switch wrap {
			case null|{force:null}:
				throw new pm.Error.WTFError();
			case {force: false}:
				return NPromise.createAsync(function(done) {
					done(outcome);
				});
			case {force: true}:
				return NPromise.createAsync(function(done) {
					Defer.defer(function() {
						done(outcome);
					});
				});
		}
	}
}

typedef SyncPromiseOptions<T> = {
	?wrapAsync: Bool,
	?forceAsync: Bool,
	?useAsyncCallbacks: Bool
}

/**
  static class of base implementations for Promise methods
 **/
@:expose
class CommonPromiseMethods {
    public static function merge<T1, T2, Out>(a:PromiseObject<T1>, b:PromiseObject<T2>, combiner:Combiner<T1, T2, Out>):PromiseObject<Out> {
        return @:privateAccess NPromise.createAsync(function(done) {
            a.handle(function(aOut) {
                b.handle(function(bOut) {
                    combiner.call(aOut, bOut).handle(done);
                });
            });
        });
    }

    public static inline function createAsync1<T>(executor: Callback<Callback<Outcome<T, Dynamic>>>, ?options:AsyncPromiseOptions<T>):PromiseObject<T> {
        return new AsyncPromiseObject(executor, options);
    }

    public static function createAsync2<T>(executor):PromiseObject<T> {
        return createAsync1(function(done:Callback<Outcome<T, Dynamic>>) {
            function resolve(result: T) {
                done(Success(result));
            }
            function reject(error: Dynamic) {
                done(Failure(error));
            }
            executor(resolve, reject);
        });
    }

	/**
	  create a synchronous (in principal) new PromiseObject<T>
	 **/
	public static function createSync<T>(outcome:Lazy<Outcome<T, Dynamic>>, ?options:{?wrapAsync:Bool, ?forceAsync:Bool, ?useAsyncCallbacks:Bool}):PromiseObject<T> {
		if (options == null) options = @:privateAccess OutcomePromiseObject.defaultOptions;
		if (options.wrapAsync) {
			return createAsync1(
				if (!options.forceAsync)
					function(done) {
						done(outcome.get());
					}
				else
					function(done) {
						Defer.defer(() -> done(outcome.get()));
					}
			);
		}
		else {
			return new SyncPromise(outcome.get(), options);
		}
	}
}

class WrappedError extends Error {
	public var exception(default, null): Dynamic;
	function new(e, ?message, ?type, ?position:haxe.PosInfos) {
		super(message, type, position);
		this.exception = e;
		inline _auto();
	}
	function _auto() {
		if ((exception is String)) {
			this.message = '$exception';
		}
		#if js
		else if ((exception is js.lib.Error)) {
			final jsErr:js.lib.Error = cast exception;
			this.message = jsErr.message;
			this.name = jsErr.name;
			//Console.debug(jsErr.stack);
		}
		#end
	}
	public inline function rethrow() {
		throw exception;
	}

	public static function wrap(e:Dynamic, flat:Bool=true, ?pos:haxe.PosInfos):WrappedError {
		if (flat && (e is WrappedError)) {
			return cast(e, WrappedError);
		}
		return new WrappedError(e, pos);
	}
}

class Die extends Error {

}