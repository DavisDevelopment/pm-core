package moon.data.iterators;

class IteratorIterator<T> {
    public var outer:Iterator<Iterator<T>>;
    public var inner:Iterator<T>;

    public function new(it: Iterator<Iterator<T>>) {
        outer = it;
        nextOuter();
    }

    public static inline function of<T>(it: Iterable<Iterator<T>>):IteratorIterator<T> {
        return new IteratorIterator<T>(it.iterator());
    }

    private inline function nextOuter() {
        if (outer.hasNext())
            inner = outer.next();
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
