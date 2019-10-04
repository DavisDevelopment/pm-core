package pm.map;

import pm.*;

interface ISet<T> {
    public var length(get, never):Int;

    public function size():Int;
    public function add(value: T):Void;
    public function delete(value: T):Bool;
    public function clear():Void;
    public function has(v: T):Bool;
    public function iterator():Iterator<T>;
    
    public function toArray():Array<T>;
}
typedef SetObject<T> = {
	var length #if !js (get, never) #end:Int;
	function size():Int;
	function add(value:T):Void;
	function delete(value:T):Bool;
	function clear():Void;
	function has(v:T):Bool;
	function iterator():Iterator<T>;
	function toArray():Array<T>;
}