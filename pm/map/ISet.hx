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

    // function size():Int;
    // function delete(v: T):Bool;
    // function has(v: T):Bool;
	function subset(other:Set<T>):Bool;
	function properSubset(other:Set<T>):Bool;
	function equals(other:Set<T>):Bool;
    function compareTo(other:Set<T>):Int;
	function disjoint(other:Set<T>):Bool;
	function union(other:Set<T>):Set<T>;
	function intersect(other:Set<T>):Set<T>;
	function difference(other:Set<T>):Set<T>;
	function exclude(other:Set<T>):Set<T>;
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

