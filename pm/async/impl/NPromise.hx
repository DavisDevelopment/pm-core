package pm.async.impl;

import pm.async.impl.PromiseObject;
import pm.async.impl.Defer;
using pm.async.impl.CommonTypes;
import pm.async.impl.AsyncPromiseObject;
import pm.async.impl.JsPromiseObject;

using pm.Arrays;
using pm.Iterators;

@:runtimeValue
@:expose('pm.async.impl.NPromise')
@:forward(isAsync, simplify)
abstract NPromise<T>(PromiseObject<T>) from PromiseObject<T> to PromiseObject<T> {
	/* === [Instance Fields] === */
	public inline function then(onFulfilled:Callback<T>, ?onError:Callback<Dynamic>):CallbackLink {
		return this.then(onFulfilled, onError);
	}

	public inline function fiber():NPromise<T> {
		return this;
	}

	public inline function map<O>(f:T->O):NPromise<O> {
		return this.map(f);
	}

	public inline function flatMap<O>(f:T->NPromise<O>):NPromise<O> {
		return this.flatMap(f);
	}

	/**
		@param onFinally - invoked after `this` is resolved
	**/
	public function always(onFinally:Void->Void):CallbackLink {
		return then(onFinally, onFinally);
	}

	/**
		@param onComplete - listener function invoked with an `Outcome` value for result of this `NPromise` as the first parameter
	**/
	public function handle(onComplete:Callback<Outcome<T, Dynamic>>):CallbackLink {
		return this.handle(onComplete);
	}

	public inline function next<O>(map:Outcome<T, Dynamic>->NPromise<O>):NPromise<O> {
		return this.next(map);
	}

	/**
		@param outcomeMap - lambda function with 1 `Outcome<T, Dynamic>` parameter, which returns an `Outcome<R, Dynamic>` value
	**/
	public inline function transform<R>(outcomeMap:Outcome<T, Dynamic>->Outcome<R, Dynamic>):NPromise<R> {
        return this.next(function(outcome) {
            return switch outcomeMap(outcome) {
                case Success(result): resolve(result);
                case Failure(error): reject(error);
            }
        });
	}

	@:deprecated('superfluous method `derive` to be removed')
	public inline function derive<O>(f:(root:NPromise<T>, complete:Callback<Outcome<O, Dynamic>>) -> Void):NPromise<O> {
		// TODO
		return createAsync(function(complete:Callback<Outcome<O, Dynamic>>) {
			f(this, complete);
		});
	}

	public inline function merge<T2, R>(other:NPromise<T2>, merger:Combiner<T, T2, R>):NPromise<R> {
		return CommonPromiseMethods.merge(this, other, merger);
	}

	public inline function noisify():NPromise<Noise> {
		return map(_ -> Noise.createByIndex(0));
	}

	/* === [Combinator Methods] === */
	public static function or<T>(a:NPromise<T>, b:NPromise<T>):NPromise<T> {
		return createAsync(function(done) {
			a.handle(function(o) {
				switch o {
					case Success(result):
						return done(o);

					case Failure(error1):
						b.handle(function(o) {
							switch o {
								case Success(_):
									return done(o);

								case Failure(error2):
									return done(Failure(new Pair(error1, error2)));
							}
						});
				}
			});
		});
	}

	// public static function inParallel<T>(a:Array<NPromise<T>>):NPromise<Array<T>> {
	// 	//
	// }

	public static function inParallel<T>(a:Array<NPromise<T>>, ?concurrency:Int, ?lazy:Bool):NPromise<Array<T>> {
		if (a.length == 0) {
			return resolve(new Array<T>());
		} 
		else {
			var exec:Callback<Callback<Outcome<Array<T>, Dynamic>>> = function(cb:Callback<Outcome<Array<T>, Dynamic>>) {
				Console.debug('inParallel.exec called');
				var result:Array<T> = [],
 					pending = a.length,
					links:CallbackLink = null,
					linkArray = [],
					sync = false,
					i = 0,
					iter = a.iterator(),
					next = null;
				
				function done(o) {
					if (links == null)
						sync = true;
					else
						links.cancel();
					cb(o);
				}

				function fail(e:Dynamic) {
					pending = 0;
					done(Failure(e));
				}

				inline function hasNext() {
					return iter.hasNext() && pending > 0;
				}

				function set(index:Int, value) {
					result[index] = value;
					// trace('inParallel($index/${a.length} => ${value})');

					if (--pending == 0)
						done(Success(result));
					else if (hasNext())
						next();
					else
						throw 'betty';
				}

				next = function() {
					var index = i++,
						promise = iter.next();
						// Console.debug('listening to promises[$index]');
					linkArray.push(
						promise.handle(function(o:Outcome<T, Dynamic>) {
							switch o {
								case Success(res):
									set(index, res);

								case Failure(error):
									fail(error);
							}
						})
					);
				}

				while (hasNext() && (concurrency == null || concurrency-- > 0)) {
					next();
				}

				links = linkArray;

				if (sync)
					links.cancel();
			};

			return NPromise.createAsync(exec);
		}
	}

	/* === [Factory Methods / Functions] === */
	/**
		@return a newly created `PromiseTriggerObject<T>`
	**/
	public static inline function trigger<T>():PromiseTriggerObject<T> {
        #if !macro Console.warn('TODO: Create PromiseTrigger class built upon AsyncPromise'); #end
		#if js
		return new JsPromiseTrigger();
		#else
		return new FuturePromiseTrigger();
		#end
	}

	/**
		@param ctor - lambda invoked with a `PromiseTriggerObject<T>`
		@return an `NPromise<T>` object
	**/
	public static function build<T>(ctor:PromiseTriggerObject<T>->Void, enforceAsync = false):NPromise<T> {
		if (enforceAsync)
			ctor = desyncCallback(ctor);
		var t:PromiseTriggerObject<T> = trigger();
		ctor(t);
		return t.asPromise();
	}

	#if js

	@:to
	public static inline function toJsPromise<T>(self:NPromise<T>):js.lib.Promise<T> {
		return new js.lib.Promise(function(resolve, reject) {
			self.then(resolve, reject);
		});
	}

	@:from
	public static function ofJsPromise<T>(native: js.lib.Promise<T>):NPromise<T> {
		return ofPromiseObject(new pm.async.impl.JsPromiseObject(native));
	}

	public static inline function ofJsThenable<T>(o: js.lib.Promise.Thenable<T>):NPromise<T> {
		return ofJsPromise(js.lib.Promise.resolve(o));
	}

	public static function wrapJsPromiseAroundPromise<T>(p: NPromise<T>):NPromise<T> {
		if (((p : PromiseObject<T>) is JsPromiseObject<T>)) {
			return p;
		}
		else {
			return ofJsPromise(p.toJsPromise());
		}
	}

	#end

	@:from
	static inline function ofPromiseObject<T>(p: PromiseObject<T>):NPromise<T> {
		return (p : NPromise<T>);
	}

	@:from
	public static inline function createFromTrigger<T>(trigger:PromiseTriggerObject<T>):NPromise<T> {
		return trigger.asPromise();
	}

    /**
      @usage
        NPromise.createFromDyad(function(resolve, reject) {
            wait(100, function() {
                resolve(value);
            });
        });
     **/
	@:from
	public static function createFromDyad<T>(ctor:(resolve:T->Void, reject:Dynamic->Void)->Void):NPromise<T> {
		return build(trigger -> {
			ctor(function(v:T) {
				if (!trigger.resolve(v))
					throw new pm.Error('Invalid call to .resolve');
			}, function(err:Dynamic) {
				if (!trigger.reject(err))
					throw new pm.Error('Invalid call to .reject');
			});
		});
	}

	@:from
	public static inline function createFromDyad2<T>(ctor:(resolve:Callback<T>, reject:Callback<Dynamic>) -> Void):NPromise<T> {
		return createFromDyad(ctor);
	}

	public static function createFromResultMonad<R>(rm:(callback:Callback<R>) -> Void):NPromise<R> {
		return createAsync(function(complete) {
			rm(function(r:R) {
				return complete(Success(r));
			});
		});
	}

	public static inline function createAsync<T>(exec:Callback<Callback<Outcome<T, Dynamic>>>, ?options:pm.async.impl.AsyncPromiseObject.AsyncPromiseOptions<T>):NPromise<T> {
		return CommonPromiseMethods.createAsync1(exec, options);
	}

	@:from
	public static inline function async<T>(exec:(Outcome<T, Dynamic>->Void)->Void):NPromise<T> {
		return (createAsync((exec : Callback<Outcome<T, Dynamic> -> Void>)) : PromiseObject<T>);
	}

    @:from
    public static inline function fulfillAsync<T>(exec: (callback: (result: T)->Void)->Void):NPromise<T> {
        return createFromResultMonad(cast exec);
    }

    public static inline function createSync<T>(outcome:Lazy<Outcome<T, Dynamic>>, ?options:SyncPromiseOptions<T>):NPromise<T> {
        return CommonPromiseMethods.createSync(outcome, options);
    }

	public static var WRAP_SYNC = false;

	@:from
	public static function sync<T>(outcome: Lazy<Outcome<T, Dynamic>>):NPromise<T> {
		if (!WRAP_SYNC) {
			return createSync(outcome, {
				wrapAsync: false,
				useAsyncCallbacks: false
			}); 
		}
		else {
			return createAsync(function(done) {
				done(outcome);
			});
		}
	}

	@:from
	public static inline function resolve<T>(result:T):NPromise<T> {
		return sync(Lazy.ofConst(Success(result)));
	}

	public static inline function reject<T>(error:Dynamic):NPromise<T> {
		return sync(Failure(error));
	}

	/* === [Utilities] === */

	static inline function bindCallback<T>(callback:Callback<T>, ensureAsync:Bool = false):Callback<T> {
		return ensureAsync ? desyncCallback(callback) : callback;
	}

	static inline function desyncCallback<T>(callback:Callback<T>):Callback<T> {
        Console.warn('Call to NPromise.desyncCallback({0}); Should be handled by implementing class', callback);
		return x -> defer(() -> callback(x));
	}

	private static inline function defer(f:Void->Void) {
		Defer.defer(f);
	}
}
