package pm.map;

import js.lib.Set;
import pm.map.Set as S;

class IntSet implements ISet<Int> {
	final set:Set<Int>;

	public var length(get, never):Int;

	public inline function new(?values:Iterable<Int>) {
		set = new Set(switch values {
			case null: null;
			case it: [for (v in it) v];
		});
	}

	public inline function get_length():Int {return set.size;}

	public inline function add(v:Int):Void {
		set.add(v);
	}

	public inline function exists(v:Int):Bool {
		return set.has(v);
	}

	public inline function remove(v:Int):Bool {
		return set.delete(v);
	}

	public inline function iterator():Iterator<Int> {
		return new js.lib.HaxeIterator(set.values());
	}

	public inline function clear():Void {
		set.clear();
	}

	public inline function copy():IntSet {
		return new IntSet(this);
	}

	public inline function toArray():Array<Int> {
		return [for (v in this) v];
	}

	public inline function toString():String {
		return '$set';
  }
  
	/**
	 * Returns true if all elements in `this` is also in `other`.
	 * a <= b
	 */
	public function subset(other:pm.map.IntSet):Bool {
		return set.issubset(other.set);
		for (x in this)
			if (!other.exists(x))
				return false;
		return true;
	}

	/**
	 * Returns true if all elements in `this` is also in `other`
	 * and `other` has more elements than `this`.
	 * a < b
	 */
	public inline function properSubset(other:pm.map.IntSet):Bool {
		// return length < other.length && subset(other);
		return set.issubset_proper(other.set);
	}

	/**
	 * Returns true if `this` and `other` have the exact
	 * same elements.
	 * a == b
	 */
	public inline function equals(other:Set<T>):Bool {
		return length == other.length && subset(other);
	}

	/**
	 * Returns true if `this` and `other` has no common elements.
	 */
	public function disjoint(other:pm.map.IntSet):Bool {
		return set.isdisjoint(other.set);
		for (x in this)
			if (other.exists(x))
				return false;
		return true;
	}

	/**
	 * Compare with another set by its cardinality.
	 */
	public inline function compareTo(other:Set<T>):Int {
		return pm.Numbers.Ints.compare(length, other.length);
	}

	/**
	 * Returns a new set containing all elements from `this`
	 * as well as elements from `other`.
	 *
	 * Operator: this | other
	 * Venn: (###(###)###)
	 */
	public function union(other:S<Int>):S<Int> {
		var s = new IntSet();
		for (x in this)
			s.add(x);
		for (x in other)
			s.add(x);
		return s;
	}

	/**
	 * Returns a new set containing common elements that
	 * appears in both sets.
	 *
	 * Operator: this & other
	 * Venn: (   (###)   )
	 */
	public function intersect(other:S<Int>):S<Int> {
		var s = new IntSet();
		for (x in this)
			if (other.exists(x))
				s.add(x);
		return s;
	}

	/**
	 * Returns a new set containing elements that appears in
	 * `this` that does not appear in `other`.
	 *
	 * Operator: this - other
	 * Venn: (###(   )   )
	 */
	public function difference(other:S<Int>):pm.map.Set<Int> {
		var s = new IntSet();
		for (x in this)
			if (!other.exists(x))
				s.add(x);
		return s;
	}

	/**
	 * Returns a new set containing elements that appears in
	 * either `this` or `other`, but not both.
	 *
	 * Operator: this ^ other
	 * Venn: (###(   )###)
	 */
	public function exclude(other:Set<T>):Set<T> {
		var s = new IntSet();
		for (x in this)
			if (!other.exists(x))
				s.add(x);
		for (x in other)
			if (!this.exists(x))
				s.add(x);
		return s;
	}

	/**
	 * Return a new set by performing a cartesian product on `other`.
	 */
	public function cartesianProduct<U>(other:Set<U>):Set<Pair<Int, U>> {
		var s = new S<Pair<T, U>>();
		for (a in this)
			for (b in other)
				s.add(Pair.of(a, b));
		return s;
	}
}
