package pm.iterators;

class IterableIterator<T> {
    public var outer:Iterator<Iterable<T>>;
    public var inner:Iterator<T>;

    public inline function new(o: Iterator<Iterable<T>>) {
        outer = o;
        nextOuter();
    }

    private inline function nextOuter() {
        if (outer.hasNext())
            inner = (outer.next().iterator());
    }

    public function hasNext():Bool {
        // there's more in the current iterator, so its true
        if (inner != null && inner.hasNext()) {
            return true;
        }
        // no more in current iterator. are there more outer?
        else if (outer.hasNext()) {
            nextOuter();
            return hasNext();
        }
        // no more outers and no more inners, so that's the end
        else {
            return false;
        }
    }

    public inline function next():T {
        return hasNext() ? inner.next() : null;
    }
}
