package pm.async.impl;

import pm.async.impl.CommonTypes;

typedef TCombiner<A, B, C> = (left:Outcome<A, Dynamic>, right:Outcome<B, Dynamic>) -> NPromise<C>;
typedef TResultCombiner<A,B,C> = (left:A, right:B)->NPromise<C>;

@:callable
abstract Combiner<In1, In2, Out>(TCombiner<In1, In2, Out>) from TCombiner<In1, In2, Out> to TCombiner<In1, In2, Out> {
	
    @:from
	public static function flat<A, B, C>(callback: A->B->C):Combiner<A, B, C> {
		return function (a:Outcome<A, Dynamic>, b:Outcome<B, Dynamic>):PromiseObject<C> {
			return switch [a, b] {
				case [Success(a), Success(b)]: NPromise.resolve(callback(a, b));
				case [Failure(err), _], [_, Failure(err)]: NPromise.reject(err);
			}
		};
	}

	@:from
	public static function successes<In1, In2, Out>(callback: TResultCombiner<In1, In2, Out>):Combiner<In1, In2, Out> {
		return function(a:Outcome<In1, Dynamic>, b:Outcome<In2, Dynamic>):NPromise<Out> {
			return switch [a, b] {
				case [Success(a), Success(b)]: callback(a, b);
				case [Failure(err), _] | [_, Failure(err)]: NPromise.reject(err);
			}
		};
	}
}