package pm;

// import thx.Semigroup;
import pm.utils.Comparable;
import pm.utils.ComparableOrd;

abstract Ordering(OrderingImpl) from OrderingImpl to OrderingImpl {
	@:from public static function fromInt(value : Int) : Ordering {
		return value < 0 ? LT : (value > 0 ? GT : EQ);
		// return OrderingImpl.clamp(value);
    }

    @:from public static inline function fromFloat(value : Float) : Ordering {
        return value < 0 ? LT : (value > 0 ? GT : EQ);
    }

	@:to public function toInt():Int {
		return switch this {
			case LT: -1;
			case GT: 1;
			case EQ: 0;
		};
	}
}

#if (ordering_as_int && haxe4)
enum abstract OrderingImpl (Int) to Int {
	var LT = -1;
	var EQ =  0;
	var GT =  1;

	public static function clamp(i: Int):OrderingImpl {
		return (
			if (i < 0) OrderingImpl.LT
			else if (i > 0) OrderingImpl.GT
			else OrderingImpl.EQ
		);
	}
}
#else
enum OrderingImpl {
	LT;
	GT;
	EQ;
}
#end

class Orderings {
	public static function negate(o: Ordering):Ordering {
		return switch o {
			case LT: GT;
			case EQ: EQ;
			case GT: LT;
        };
    }
}

class IntOrds {
    
}


@:callable
@:using(pm.Ord.Orderings)

abstract Ord<A> (A -> A -> Ordering) from A -> A -> Ordering to A -> A -> Ordering {
    public function order(a0: A, a1: A): Ordering {
        return this(a0, a1);
    }

	public function max(a0:A, a1:A):A {//
		return switch this(a0, a1) {
			case LT | EQ: a1;
			case GT: a0;
		};
    }

	public function min(a0:A, a1:A):A {//
		return switch this(a0, a1) {
			case LT | EQ: a0;
			case GT: a1;
		};
    }

	public function equal(a0:A, a1:A):Bool {//
		return this(a0, a1) == EQ;
    }

	public function contramap<B>(f:B->A):Ord<B> {
		return function(b0:B, b1:B) {
			return this(f(b0), f(b1));
		};
    }

    public function inverse():Ord<A> {
		return function(a0:A, a1:A) {
			return this(a1, a0);
		};
    }

	public function intComparison(a0:A, a1:A):Int {//
		return switch this(a0, a1) {
			case LT: -1;
			case EQ: 0;
			case GT: 1;
		};
    }

    @:from
    public static inline function fromIntComparison<A>(f:(A, A)->Int):Ord<A> {//
		return function(a:A, b:A) {
			return Ordering.fromInt(f(a, b));
		};
	}
	
	@:to
	public static function toIntCompFn<T>(ord:Ord<T>):(T, T)->Int {
		return function(l:T, r:T):Int {
			return ord.order(l, r);
		}
	}

	public static function forComparable<T:Comparable<T>>():Ord<T> {//
		return function(a:T, b:T) {
			return Ordering.fromInt(a.compareTo(b));
		};
    }

	public static function forComparableOrd<T:ComparableOrd<T>>():Ord<T> {//
		return function(a:T, b:T) {
			return a.compareTo(b);
		};
    }
}
