package pm.map;

import haxe.Constraints.IMap;

using pm.Iterators;
using pm.Arrays;

@:forward
abstract OrderedDictionary<K, V> (OrderedDictionaryType<K, V>) from OrderedDictionaryType<K, V> {
    public function new(?cmp:K->K->Int) {
        if (cmp == null) {
            cmp = function(a:K, b:K):Int {
                return pm.Arch.compareThings(a, b);
            }
        }
        this = new OrderedDictionaryType(cmp);
    }
    @:arrayAccess
    public inline function getByIndex(index: Int):V {
        return this.getByIndex(index);
    }
    @:arrayAccess
    public inline function get(key: K):V {
        return this.get(key);
    }
    @:arrayAccess
    public inline function setByIndex(index:Int, value:V):V {
        this.setByIndex(index, value);
        return value;
    }
    @:arrayAccess
    public inline function set(key:K, value:V):V {
        this.set(key, value);
        return value;
    }
    public static final type = OrderedDictionaryType;
}

class OrderedDictionaryType<Key, V> implements IMap<Key, V> {
    public final cmp: Key -> Key -> Int;
    public var arr(default, null): Array<Key>;
    public var map(default, null): OrderedMap<Key, V>;

    public function new(cmp) {
        this.cmp = cmp;
        this.arr = new Array();
        this.map = new OrderedMap(this.cmp);
    }

    public function set(key:Key, value:V) {
        if (!map.exists(key))
            arr.push(key);
        map.set(key, value);
    }

    public inline function get(key: Key):V {
        return map.get(key);
    }
    public inline function getByIndex(index: Int):V {
        return get(arr[index]);
    }
    public inline function setByIndex(index:Int, value:V) {
        return set(arr[index], value);
    }
    public inline function copy():OrderedDictionaryType<Key, V> {
        var d = new OrderedDictionaryType(cmp);
        d.arr = arr.copy();
        d.map = map.copy();
        return d;
    }
    public function clear() {
        arr.resize(0);
        map.clear();
    }
    public function keyOf(value:V, ?eq:V->V->Bool):Null<Key> {
        if (eq == null) {
            eq = Functions.equality;
        }
        for (key in keys()) {
            if (eq(get(key), value)) {
                return key;
            }
        }
        return null;
    }
    public function indexOf(value:V, ?eq:V->V->Bool):Int {
        if (eq == null) eq = Functions.equality;
        for (i in 0...arr.length) {
            if (eq(get(arr[i]), value)) {
                return i;
            }
        }
        return -1;
    }
    public function remove(key: Key):Bool {
        if (map.exists(key)) {
            var removedFromArr = false;
            for (i in 0...arr.length) {
                if (cmp(arr[i], key) == 0) {
                    removedFromArr = arr.remove(arr[i]);
                    break;
                }
            }
            if (!removedFromArr) {
                throw new pm.Error('Failed to remove $key');
            }
            return map.remove(key);
        }
        return false;
    }
    public inline function exists(key: Key):Bool {
        return map.exists(key);
    }
    public inline function iterator():Iterator<V> {
        return map.iterator();
    }
    public inline function keyValueIterator():KeyValueIterator<Key, V> {
        return map.keyValueIterator();
    }
    public inline function keyArray():Array<Key> {
        return arr.copy();
    }
    public inline function toString():String {
        throw new pm.Error.NotImplementedError();
    }

    public function keys():Iterator<Key> {
        return arr.iterator();
    }

    public var length(get, never):Int;
    private inline function get_length():Int return arr.length;
}