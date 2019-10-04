package pm.async.impl;

import pm.async.impl.PromiseObject;
import pm.async.impl.Defer;
using pm.async.impl.CommonTypes;

import haxe.ds.Option;
import haxe.extern.EitherType as Or;
using pm.Maybe;

import pm.Arch;
import pm.Assert.assert;
import pm.Functions.noop;

class BaseAsyncPromiseObject<T> /*implements PromiseObject<T>*/ {
    public var listeners:CallbackList<Outcome<T, Dynamic>> = null;
	/**
	  [TODO]
	 **/
	// private var _alwaysListeners:CallbackList<Noise> = null;
    public var outcome(default, null):Null<Outcome<T, Dynamic>> = null;
	public var options(default, null):AsyncPromiseOptions<T>;
	public var isAsync(get, never):Bool;
	private var _isAsync: Bool;

	private var __status : Status<T> = Pending;
    private var __value : Null<T> = null;
    private var __error : Null<Dynamic> = null;

	private var _onAddListener:Void -> Void;
	private var _onBecomeSync:Void -> Void;

    private function new() {
        _onAddListener = Functions.noop;
		options = Arch.clone(defaultInitOptions);
		_onBecomeSync = Functions.noop;
    }

	private function get_isAsync() return this._isAsync;
	public inline function isResolved() return this.__status.equals(Resolved);
	public inline function isPending() return this.__status.equals(Pending);
	public inline function isSync():Bool return (isResolved() && !isAsync);

	public inline function setOnBecomeSync(f: Void->Void) {
		this._onBecomeSync = f;
	}

	function setOutcome(o: Outcome<T, Dynamic>) {
		switch (this.outcome = o) {
			case Success(res):
				__value = res;

			case Failure(error):
				__error = error;
		}
	}

	/**
	  add a callback which will be invoked upon resolution of [this] Promise
	 **/
	public dynamic function addListener(listener: Callback<Outcome<T, Dynamic>>):CallbackLink {
		assert(listeners != null, 'Cannot add a new callback to this Promise');

		// Console.debug(listener);
		var lnk = listeners.add(listener);
		_onAddListener();
		return lnk;
	}

	/**
	  internal method used to mark [this] as having been 'resolved' to some Outcome
	 **/
	function _resolve(o: Outcome<T, Dynamic>):Bool {
		// Console.examine(o);
		if (!isPending()) {
			return false;
		}

		this.__status = Resolved;
		this.setOutcome(o);
		
		if (isAsync && listeners != null && listeners.length != 0) {
			// handle callbacks queued during the execution of the async callbacks
			var tailListeners = new CallbackList();
			addListener = function(f) {
				return tailListeners.add(f);
			};

			// execute async callbacks
			listeners.invoke(this.outcome);
			listeners.clear();
			listeners = null;
			_isAsync = false; // outcome is known, and async-callbacks have been invoked; this is no longer async


			if (tailListeners.length != 0) { // 
				tailListeners.invokeAndClear(this.outcome);
				Console.printlnFormatted('<#009,b>Tail Callbacks Invoked<//>');
			}

			// should no longer be possible to add new async listener
			addListener = function(f) {
				Console.error(new Die('Invalid call'));
				Sys.exit(1);
				return noop;
			};

			_onBecomeSync();
		}

		return true;
	}

	/*
	function __scheduleCallbackInvokation(listeners, tail:Void->Void) {
		Defer.defer(() -> {
			(listeners : CallbackList<Outcome<T, Dynamic>>).invoke(this.outcome);
			tail();
		});
		Console.debug('listener count: ', listeners.length);
	}
	*/

	/**
	  internal method called to initialize [this] Promise
	 **/
	private function _init(executor:AsyncPromiseExecutor<T>) {
		inline _init_base(this, executor, this.options);
	}

	/**
	  [TODO] document this method thoroughly
	 **/
    private static function _init_base<T>(self:BaseAsyncPromiseObject<T>, exec:AsyncPromiseExecutor<T>, ?config:AsyncPromiseOptions<T>) {
		if (config == null) 
			config = Arch.clone_object(defaultInitOptions, CloneMethod.Shallow);

        var outcome:Outcome<T, Dynamic> = null;// the outcome of [self]
        var resolve:Outcome<T, Dynamic>->Void = function(o) {// the function invoked upon resolution of [this] Promise
            outcome = o;
        };

		if (config.safe) {
			try {
				exec(function(o) {
					resolve(o);
				});
			}
			catch (e: Dynamic) {
				resolve(Failure(e));
			}
		}
		else {
        	exec(function(o) resolve(o));
		}

        var isAsync = (outcome == null);// if [outcome] is already assigned a non-null value, then the promise has resolved synchronously
        if (isAsync) {
			// async Promise
			self._isAsync = true;
			self.listeners = new CallbackList();
            resolve = function(o: Outcome<T, Dynamic>) {
				outcome = o;
				
				self._resolve(outcome);
			};
        }
		else {
			// sync Promise
			self._isAsync = false;
			if (config.forceAsync) {
				self._isAsync = true;
				Defer.defer(function() {
					self._resolve(outcome);
				});
			}
			else {
				self._resolve(outcome);
			}
		}
    }

    public static var defaultInitOptions:AsyncPromiseOptions<Dynamic> = {
        safe: false,
		lazy: false,
		forceAsync: false,
		syncCallbacks: false
    };
}

class AsyncPromiseObject<T> extends BaseAsyncPromiseObject<T> implements PromiseObject<T> {
	public function new(exec:AsyncPromiseExecutor<T>, ?options:AsyncPromiseOptions<T>) {
		super();
		if (options != null) {
			this.options = options;
		}
		_init(exec);
	}

	override public function get_isAsync() return super.get_isAsync();

	/**
	  listen for outcome
	 **/
	public inline function handle(cb: Callback<Outcome<T, Dynamic>>):CallbackLink {
		if (isResolved() && !isAsync) {
			cb(this.outcome);
			return noop;
		}
		else {
			return addListener(cb);
		}
	}

	public inline function always(f: Void->Void):CallbackLink {
		if (isResolved() && !isAsync) {
			f();
			return noop;
		}
		else {
			return addListener(f);
		}
	}

	public function then(onFulfillment:Callback<T>, ?onException:Callback<Dynamic>):CallbackLink {
		var asyncCb = isAsync || !options.syncCallbacks;
		var specializeCallbacks = false;
		// Console.debug(asyncCb);
		if (!asyncCb) {
			if (__error != null && onException != null)
				onException(__error);
			else if (__value != null)
				onFulfillment(__value);
			throw new Die();
		}
		else {
			if (specializeCallbacks) {
				throw new Die();
			}
			else {
				return handle(outcomeCallbackFrom({value:onFulfillment, error:onException}));
			}
		}

		return noop;
	}
	
	public function map<O>(f: T -> O):PromiseObject<O> {
		return new AsyncPromiseObject<O>(function(done) {
			handle(outcome -> done(outcome.map(f)));
		});
	}

	public function flatMap<O>(f: T -> PromiseObject<O>):PromiseObject<O> {
		return new AsyncPromiseObject(function(done) {
			handle(outcome -> switch outcome.map(f) {
				case Success(result_promise): result_promise.handle(done);
				case o: done(cast o);
			});
		});
	}

	public function next<O>(f: Outcome<T, Dynamic> -> PromiseObject<O>):PromiseObject<O> {
		return new AsyncPromiseObject<O>(function(done) {
			handle(function(outcome) {
				f(outcome).handle(done);
			});
		});
	}

	public inline function simplify():PromiseObject<T> {
		if (isResolved() && !isAsync) {
			return CommonPromiseMethods.createSync(outcome, {wrapAsync: false});
		}
		else return this;
	}

	static function outcomeCallbackFrom<T>(cb: {value:Callback<T>, ?error:Callback<Dynamic>}) {
		return switch cb {
			case {value: onValue, error:null}:
				function(o: Outcome<T, Dynamic>) switch o {
					case Success(value):
						onValue.invoke(value);
					default:
				};

			case {value: onValue, error: onError}:
				function(o: Outcome<T, Dynamic>) switch o {
					case Success(value):
						onValue.invoke(value);
					case Failure(error):
						onError.invoke(error);
				}
		}
	}
}

typedef AsyncPromiseExecutor<T> = (callback: (outcome: Outcome<T, Dynamic>) -> Void) -> Void;
typedef AsyncPromiseOptions<T> = {
    ?safe: Bool,
	?lazy: Bool,
	?forceAsync: Bool,
	?syncCallbacks: Bool,
	?parent: Or<BaseAsyncPromiseObject<T>, PromiseObject<T>>
}

enum AsyncPromiseStatus<T> {
	Pending;
	Resolved;
}
private typedef Status<T> = AsyncPromiseStatus<T>;

/**
	[TODO] make this class *not* lazy, as in `exec` is invoked immediately
	and deference to the next frame is done only on listener invokation or when explicitly demanded
**/
class AsyncLazyPromise<T> {
	public var listeners:CallbackList<pm.Outcome<T, Dynamic>>;
	public var outcome(default, null):Null<pm.Outcome<T, Dynamic>> = null;

	/**  Constructor Function  **/
	public function new(exec:Callback<Outcome<T, Dynamic>>->Void, sync = false) {
		listeners = new CallbackList();
		var init = function() {
			exec(function(outcome:pm.Outcome<T, Dynamic>):Void {
				if (this.outcome == null) {
					this.outcome = outcome;
					this.listeners.invokeAndClear(this.outcome);
					this.listeners = null;
				} else {
					throw new pm.Error('Why tho?');
				}
			});
		};
		if (sync)
			init();
		else
			Defer.defer(init);
	}

	/* === [Instance Methods] === */
	/**
		@param res - Callback for the successful result of [this] Promise
		@param err - Callback for the error value upon a failure of [this] Promise
		@returns a `CallbackLink` object
	**/
	public function then(res:Callback<T>, ?err:Callback<Dynamic>):CallbackLink {
		if (outcome != null) {
			switch outcome {
				case Success(result):
					res(result);

				case Failure(error):
					if (err != null) {
						err(error);
					}
			}
			return function():Void {
				throw new pm.Error("Invalid call");
			}
		} else {
			return listeners.add(function(outcome) {
				switch outcome {
					case Success(result):
						res(result);

					case Failure(error):
						if (err != null) {
							err(error);
						}
				}
			});
		}
	}

	// public function map<O>(f:T->O):PromiseObject<O> {
	// 	if (outcome != null) {
	// 		return new SyncPromise(Lazy.ofFn(() -> outcome.map(f)));
	// 	} else {
	// 		/**
	// 			[NOTE] `AsyncLazyPromise`'s constructor 'defers' its executor by default
	// 			which causes
	// 			<code>
	// 							  return new AsyncLazyPromise(function(done) {
	// 								  listeners.add(function(outcome) {
	// 									  done(outcome.map(f));
	// 								  });
	// 							  });
	// 			</code>
	// 			to fail, because `listeners` has already been nullified by the time the executor is invoked.
	// 			Adding second parameter `sync=true` corrects issue, by forcing immediate invokation of `exec`
	// 		**/
	// 		return new AsyncLazyPromise(function(done) {
	// 			listeners.add(function(outcome) {
	// 				done(outcome.map(f));
	// 			});
	// 		}, true // second parameter mandatory, see comment above
	// 		);
	// 	}
	// }

	// /**
	// 	@param f - accepts [result] as argument, and returns a `Promise<O>` object
	// 	@returns a `Promise<O>` instance
	// **/
	// public function flatMap<O>(f:T->PromiseObject<O>):PromiseObject<O> {
	// 	return new AsyncLazyPromise(function(done) {
	// 		handle(function(out) {
	// 			switch out {
	// 				case Success(res):
	// 					f(res).handle(done);

	// 				case Failure(error):
	// 					done(Failure(error));
	// 			}
	// 		});
	// 	}, true);
	// }

	/**
		@param f - a `Callback` which accepts the `Outcome<T, Dynamic` of `this`
		@returns a `CallbackLink` instance
	**/
	public inline function handle(f:Callback<Outcome<T, Dynamic>>):CallbackLink {
		if (outcome != null) {
			f(outcome);
			return function() {
				throw 'Invalid call';
			};
		} else {
			return listeners.add(f);
		}
	}

	/**
		creates a new `Promise<O>` from `this`'s `Outcome`
	**/
	// public inline function next<O>(f:Outcome<T, Dynamic>->PromiseObject<O>):PromiseObject<O> {
	// 	return new AsyncLazyPromise(function(done) {
	// 		handle(function(out) {
	// 			f(out).handle(done);
	// 		});
	// 	});
	// }
}