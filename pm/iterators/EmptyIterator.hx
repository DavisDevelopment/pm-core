package pm.iterators;

class EmptyIterator<T> {
	public function new() {}

	public function hasNext():Bool
		return false;

	public function next():T
		throw 'not supported';
}