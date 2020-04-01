package pm.map;

import pm.*;

interface ISet<T> {
    public var length(get, never):Int;

    public function add(value: T):Void;
    public function remove(value: T):Bool;
    public function exists(v: T):Bool;
    public function iterator():Iterator<T>;
    function copy():ISet<T>;
    function toArray():Array<T>;
    function toString():String;
    function clear():Void;

	/**
	 * Returns true if all elements in `this` is also in `other`.
	 * a <= b
	 */
    function subset(other:Set<T>):Bool;
	/**
	 * Returns true if all elements in `this` is also in `other`
	 * and `other` has more elements than `this`.
	 * a < b
	 */
    function properSubset(other:Set<T>):Bool;
	/**
	 * Returns true if `this` and `other` have the exact
	 * same elements.
	 * a == b
	 */
    function equals(other:Set<T>):Bool;
	/**
	 * Compare with another set by its cardinality.
	 */
    function compareTo(other:Set<T>):Int;
	/**
	 * Returns true if `this` and `other` has no common elements.
	 */
    function disjoint(other:Set<T>):Bool;
	/**
	 * Returns a new set containing all elements from `this`
	 * as well as elements from `other`.
	 *
	 * Operator: this | other
	 * Venn: (###(###)###)
	 */
    function union(other:Set<T>):Set<T>;
	/**
	 * Returns a new set containing common elements that
	 * appears in both sets.
	 *
	 * Operator: this & other
	 * Venn: (   (###)   )
	 */
    function intersect(other:Set<T>):Set<T>;
	/**
	 * Returns a new set containing elements that appears in
	 * `this` that does not appear in `other`.
	 *
	 * Operator: this - other
	 * Venn: (###(   )   )
	 */
    function difference(other:Set<T>):Set<T>;
	/**
	 * Returns a new set containing elements that appears in
	 * either `this` or `other`, but not both.
	 *
	 * Operator: this ^ other
	 * Venn: (###(   )###)
	 */
    function exclude(other:Set<T>):Set<T>;
	/**
	 * Return a new set by performing a cartesian product on `other`.
	 */
    function cartesianProduct<U>(other:Set<U>):Set<Pair<T, U>>;
    
}

typedef SetObject<T> = {
	var length #if !js (get, never) #end:Int;
	// function size():Int;
	function add(value:T):Void;
	function remove(value:T):Bool;
	function clear():Void;
	function exists(v:T):Bool;
	function iterator():Iterator<T>;
    function toArray():Array<T>;
    function toString():String;
    function copy():SetObject<T>;
}

