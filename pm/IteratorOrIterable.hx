package pm;

abstract IteratorOrIterable<@:followWithAbstracts T>(Iterable<T>) to Iterable<T> {
	inline function new(getIt:Void->Iterator<T>) {
		this = {iterator: getIt};
	}

	@:to public inline function iterator():Iterator<T>
		return this.iterator();

	static inline function mk<T>(f:Void->Iterator<T>):IteratorOrIterable<T> {
		return new IteratorOrIterable(f);
	}

	@:from
	static inline function map<T, M:haxe.Constraints.IMap<Dynamic, T>>(m:M):IteratorOrIterable<T> {
		return mk(m.iterator.bind());
	}

	@:from
	@:extern
	@:generic(Container)
	public static inline function fromContainer<T, Container:{iterator:Void->Iterator<T>}>(i:Container):IteratorOrIterable<T> {
		return new IteratorOrIterable(function() return i.iterator());
	}

	@:from @:extern static inline function fromIterable<T>(i:Iterable<T>):IteratorOrIterable<T> {
		return new IteratorOrIterable(function() return i.iterator());
	}

	@:from @:extern static inline function fromIterator<T>(i:Iterator<T>):IteratorOrIterable<T> {
		return mk(function() return i);
	}
}