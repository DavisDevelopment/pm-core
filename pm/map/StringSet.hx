package pm.map;

import pm.map.Set as S;

class StringSet implements ISet<String> {
  public var length(get, never): Int;

  var map: Map<String, Bool>;
  var _length(default, null): Int;

  public inline function new(?values: Iterable<String>) {
    map = new Map();
    _length = 0;
    switch values {
      case null:
      case it:
        for (v in it)
          add(v);
    }
  }

  public inline function get_length(): Int
    return _length;

  public inline function add(v: String): Void {
    if (exists(v))
      return;
    _length++;
    map.set(v, true);
  }

  public inline function exists(v: String): Bool
    return map.exists(v);

  public inline function remove(v: String): Bool {
    if (!exists(v))
      return false;
    _length--;
    return map.remove(v);
  }

  public inline function iterator(): Iterator<String>
    return map.keys();

  public inline function clear(): Void {
    map.clear();
    _length = 0;
  }

  public inline function copy(): StringSet {
    final copy = new StringSet();
    copy._length = _length;
    copy.map = map.copy();
    return copy;
  }

  public inline function toArray(): Array<String>
    return [for (v in map.keys()) v];

  public inline function toString(): String {
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
	public function subset(other:S<String>):Bool {
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
	public inline function properSubset(other:S<String>):Bool {
		return length < other.length && subset(other);
		// return set.issubset_proper(other.set);
	}

	/**
	 * Returns true if `this` and `other` have the exact
	 * same elements.
	 * a == b
	 */
	public inline function equals(other: S<String>):Bool {
		return length == other.length && subset(other);
	}

	/**
	 * Returns true if `this` and `other` has no common elements.
	 */
	public function disjoint(other:S<String>):Bool {
		// return set.isdisjoint(other.set);
		for (x in this)
			if (other.exists(x))
				return false;
		return true;
	}

	/**
	 * Compare with another set by its cardinality.
	 */
	public inline function compareTo(other:S<String>):Int {
		return pm.Numbers.Ints.compare(length, other.length);
	}

	/**
	 * Returns a new set containing all elements from `this`
	 * as well as elements from `other`.
	 *
	 * Operator: this | other
	 * Venn: (###(###)###)
	 */
	public function union(other:S<String>):S<String> {
		var s = new S<String>();
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
	public function intersect(other:S<String>):S<String> {
		var s = new S<String>();
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
	public function difference(other:S<String>):S<String> {
		var s = new S<String>();
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
	public function exclude(other:S<String>):S<String> {
		var s = new S<String>();
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
	public function cartesianProduct<U>(other:Set<U>):Set<Pair<String, U>> {
		var s = new S<Pair<String, U>>();
		for (a in this)
			for (b in other)
				s.add(Pair.of(a, b));
		return s;
	}
}
