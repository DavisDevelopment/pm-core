package pm.map;

import pm.map.Set as S;

class IntSet implements ISet<Int> {
	public var length(get, never):Int;

	var map:Map<Int, Bool>;
	var _length(default, null):Int;

	public inline function new(?values:Iterable<Int>) {
		map = new Map();
		_length = 0;
		switch values {
			case null:
			case it:
				for (v in it)
					add(v);
		}
	}

	public inline function get_length():Int {
		return _length;
	}

	public inline function add(v:Int):Void {
		if (exists(v))
			return;
		_length++;
		map.set(v, true);
	}

	public inline function exists(v:Int):Bool {
		return map.exists(v);
	}

	public inline function remove(v:Int):Bool {
		if (!exists(v))
			return false;
		_length--;
		return map.remove(v);
	}

	public inline function iterator():Iterator<Int> {
		return map.keys();
	}

	public inline function clear():Void {
		map.clear();
		_length = 0;
	}

	public inline function copy():IntSet {
		final copy = new IntSet();
		copy._length = _length;
		copy.map = map.copy();
		return copy;
	}

	public inline function toArray():Array<Int> {
		return [for (v in map.keys()) v];
	}

	public inline function toString():String {
		final buf = new StringBuf();
		buf.add('{');
		for (v in this)
			buf.add('$v,');
		buf.add('}');
		return buf.toString();
	}

	/**
	 * Returns true if all elements in `this` is also in `other`.
	 * a <= b
	 */
	public function subset(other:S<Int>):Bool {
		// return set.issubset(other.set);
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
	public inline function properSubset(other:S<Int>):Bool {
		return length < other.length && subset(other);
		// return set.issubset_proper(other.set);
	}

	/**
	 * Returns true if `this` and `other` have the exact
	 * same elements.
	 * a == b
	 */
	public inline function equals(other:Set<Int>):Bool {
		return length == other.length && subset(other);
	}

	/**
	 * Returns true if `this` and `other` has no common elements.
	 */
	public function disjoint(other: Set<Int>):Bool {
		// return set.isdisjoint(other.set);
		for (x in this)
			if (other.exists(x))
				return false;
		return true;
	}

	/**
	 * Compare with another set by its cardinality.
	 */
	public inline function compareTo(other:Set<Int>):Int {
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
	public function exclude(other: S<Int>):S<Int> {
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
		var s = new S<Pair<Int, U>>();
		for (a in this)
			for (b in other)
				s.add(Pair.of(a, b));
		return s;
	}
}
