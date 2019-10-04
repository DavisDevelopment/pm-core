package pm.async.impl;

/**
	interface which represents `NPromise<T>` implementations
**/
interface PromiseObject<T> {
	var isAsync(get, never):Bool;

	function handle(f:Callback<Outcome<T, Dynamic>>):CallbackLink;
	function then(onFulfilled:Callback<T>, ?onRejected:Callback<Dynamic>):pm.async.Callback.CallbackLink;
	function always(onResolution: Void->Void):CallbackLink;
	
	// function rescue(goalie: Dynamic -> Maybe<RescueStep<T>>):Void;
	
	function map<TOut>(f:T->TOut):PromiseObject<TOut>;
	function flatMap<TOut>(f:T->PromiseObject<TOut>):PromiseObject<TOut>;
	function next<TOut>(map:Outcome<T, Dynamic>->PromiseObject<TOut>):PromiseObject<TOut>;

	function simplify():PromiseObject<T>;
}

/**
	interface which represents the writable interface to a `PromiseObject<T>`
**/
interface PromiseTriggerObject<T> {
	function resolve(result:T):Bool;
	function reject(error:Dynamic):Bool;
	function asPromise():PromiseObject<T>;
}

// enum RescueStep<T> {
// 	Caught(glove: )
// }