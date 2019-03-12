package pm.iterators;

class MappedIterator<TIn, TOut> {
    var i(default, null): Iterator<TIn>;
    var fn(default, null): TIn -> TOut;

    public function new(iterator, mapper) {
        i = iterator;
        fn = mapper;
    }

    public function hasNext():Bool return i.hasNext();
    public function next():TOut return fn(i.next());
}
