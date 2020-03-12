package pm.map;

class AnySet<T> implements ISet<T> {
	public var length(get, never):Int;

	private var map: Dictionary<T>;
	private var toKey: T -> String;

	public function new(?toKey:T->String, ?values:Iterable<T>) {
		this.map = new Dictionary<T>();
		this.toKey = toKey == null ? (x:T) -> serialize_any(x) : toKey;
		if (values != null) for (v in values) add(v);
    }
    
    static inline function serialize_any(x: Dynamic):String {
        return try Std.string(x) catch (e: Dynamic)
        try hx_serialize(x) catch (e: Dynamic)
        '';
    }

    static inline function hx_serialize(x: Dynamic):String {
        var s = new haxe.Serializer();
        s.useCache = true;
        s.serialize(x);
        return s.toString();
    }

    static inline function hashCodeOf(x: Dynamic):Int {
        #if java
            return (cast x : java.lang.Object).hashCode();
        #elseif python
            return untyped hash(x);
        #else
            throw new pm.Error('Invalid $x');
        #end
    }

	public inline function get_length():Int {
		return map.length;
	}

	public function exists(k:T):Bool {
		return map.exists(toKey(k));
	}

	public function remove(k:T):Bool {
		return map.remove(toKey(k));
	}

	public function iterator():Iterator<T> {
		return map.iterator();
	}

	public function toString():String {
		return "{" + [for (x in this) x].join(", ") + "}";
	}

	public function toArray():Array<T> {
		return [for (v in this) v];
	}

	public function add(v: T) {
		// var vExists = exists(v);
		if (!exists(v))
			map.set(toKey(v), v);
		// return vExists;
	}

	public function clear():Void {
		map = new Dictionary<T>();
	}

	public function copy():AnySet<T> {
		var set = new AnySet<T>(toKey, this);
		// set.addMany(this);
		return set;
	}

	/*==================================================
			Operations
		================================================== */
	/**
	 * Returns true if all elements in `this` is also in `other`.
	 * a <= b
	 */
	public function subset(other:Set<T>):Bool {
		// return intersect(other).length == length;
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
	public inline function properSubset(other:Set<T>):Bool {
		return length < other.length && subset(other);
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
	public function disjoint(other:Set<T>):Bool {
		for (x in this)
			if (other.exists(x))
				return false;
		return true;
	}

	/**
	 * Compare with another set by its cardinality.
	 */
	public inline function compareTo(other:Set<T>):Int {
		return this.length - other.length;
	}

	/**
	 * Returns a new set containing all elements from `this`
	 * as well as elements from `other`.
	 *
	 * Operator: this | other
	 * Venn: (###(###)###)
	 */
	public function union(other:Set<T>):Set<T> {
		var s = new AnySet<T>(toKey);
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
	public function intersect(other:Set<T>):Set<T> {
		var s = new AnySet<T>(toKey);
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
	public function difference(other:Set<T>):Set<T> {
		var s = new AnySet<T>(toKey);
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
		var s = new AnySet<T>(toKey);
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
	public function cartesianProduct<U>(other:Set<U>):Set<Pair<T, U>> {
		var s = new AnySet<Pair<T, U>>();
		for (a in this)
			for (b in other)
				s.add(Pair.of(a, b));
		return s;
	}
}