package pm.iterators;

class SingleIterator<T> {
    var v: T;
    var b: Bool = false;
    public inline function new(value: T) {
        v = value;
    }
    public inline function hasNext():Bool return !b;
    public inline function next():T {
        if ( !b ) {
            b = !b;
            return v;
        }
        else throw new Error('Invalid');
    }
}
