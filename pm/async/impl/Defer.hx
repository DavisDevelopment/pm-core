package pm.async.impl;

import pm.async.Callback;
import pm.concurrent.RunLoop;

class Defer {
	public static inline function defer(f:Void->Void):CallbackLink {
		var task = RunLoop.current.work(f);
		return (function() {
			task.cancel();
		} : CallbackLink);
	}

	public static inline function bind<T>(callback:Callback<T>):Callback<T> {
		return function(arg:T) {
			defer(function() {
				callback(arg);
			});
		}
	}
}