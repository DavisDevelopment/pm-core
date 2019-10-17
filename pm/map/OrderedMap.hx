package pm.map;

import pm.iterators.EmptyIterator;
import haxe.Constraints.IMap;
import haxe.ds.BalancedTree.TreeNode;

import pm.iterators.*;

/**
 * Modified from BalancedTree
 * [TODO]
 *  - refactor iteration methods to use Generator<?>, once finished
 */
#if yield
@:yield
#end
class OrderedMap<K, V> implements IMap<K, V> {
	public var length(default, null):Int;

	private var root: TreeNode<K, V>;
	private var compare: K -> K -> Int;

	/**
		Creates a new OrderedMap, which is initially empty.
		`cmp` is a function that compares two keys.
		When `cmp` is not specified, it defaults to Reflect.compare.
	**/
	public function new(?cmp : #if haxe4 (a:K, b:K)->Int #else K->K->Int #end) {
		length = 0;
		compare = cmp == null ? ((a:K, b:K)->pm.Arch.compareThings(a, b)) : cmp;
	}

	/**
		Binds `key` to `value`.
		If `key` is already bound to a value, that binding disappears.
		If `key` is null, the result is unspecified.
	**/
	public function set(key:K, value:V) {
		if (!exists(key))
			++length;
		root = setLoop(key, value, root);
	}

	/**
		Returns the value `key` is bound to.
		If `key` is not bound to any value, `null` is returned.
		If `key` is null, the result is unspecified.
	**/
	public function get(key: K):Null<V> {
		var node = root;
		while (node != null) {
			var c = compare(key, node.key);
			if (c == 0)
				return node.value;
			if (c < 0)
				node = node.left;
			else
				node = node.right;
		}
		return null;
	}

	/**
		Removes the current binding of `key`.
		If `key` has no binding, `this` BalancedTree is unchanged and false is
		returned.
		Otherwise the binding of `key` is removed and true is returned.
		If `key` is null, the result is unspecified.
	**/
	public function remove(key: K) {
		try {
			root = removeLoop(key, root);
			--length;
			return true;
		} 
        catch (e: String) {
			return false;
		}
	}

	/**
		Tells if `key` is bound to a value.
		This method returns true even if `key` is bound to null.
		If `key` is null, the result is unspecified.
	**/
	public function exists(key: K):Bool {
		var node = root;
		while (node != null) {
			var c = compare(key, node.key);
			if (c == 0)
				return true;
			else if (c < 0)
				node = node.left;
			else
				node = node.right;
		}
		return false;
	}

	/**
		Iterates over the bound values of `this` BalancedTree.
		This operation is performed in-order.
	**/
	public function iterator():Iterator<V> {
		var ret = [];
		iteratorLoop(root, ret);
		return ret.iterator();
	}

	public function nodes():Iterator<TreeNode<K, V>> { 
		var ret = [];
		nodeIteratorLoop(root, ret);
		return ret.length == 0 ? new EmptyIterator() : ret.iterator();
	}

	public function keyValueIterator() {
		return inline new MappedIterator(nodes(), function(node) return {key:node.key, value:node.value});
	}

	public function keys() {
		return inline new MappedIterator(nodes(), function(node) return node.key);
	}

	public inline function clear() {
		root.dispose();
		root = null;
		length = 0;
	}

	function setLoop(k:K, v:V, node:TreeNode<K, V>) {
		if (node == null)
			return new TreeNode<K, V>(null, k, v, null);
		var c = compare(k, node.key);
		return 
            if (c == 0) new TreeNode<K, V>(node.left, k, v, node.right, node.get_height()); else if (c < 0) {
			    var nl = setLoop(k, v, node.left);
			    balance(nl, node.key, node.value, node.right);
		    } 
            else {
			    var nr = setLoop(k, v, node.right);
			    balance(node.left, node.key, node.value, nr);
		    }
	}

	function removeLoop(k:K, node:TreeNode<K, V>) {
		if (node == null)
			throw "Not_found";
		var c = compare(k, node.key);
		return 
            if (c == 0) 
                merge(
                    node.left,
			        node.right
                ); 
            else if (c < 0) 
                balance(removeLoop(k, node.left), node.key, node.value, node.right); 
            else 
                balance(node.left, node.key, node.value, removeLoop(k, node.right));
	}

	function iteratorLoop(node:TreeNode<K, V>, acc:Array<V>) {
		if (node != null) {
			iteratorLoop(node.left, acc);
			acc.push(node.value);
			iteratorLoop(node.right, acc);
		}
	}

	function nodeIteratorLoop(node:TreeNode<K, V>, acc:Array<TreeNode<K, V>>) {
		if (node != null) {
			nodeIteratorLoop(node.left, acc);
			acc.push(node);
			nodeIteratorLoop(node.right, acc);
		}
	}

	public inline function copy() {
		var m = new OrderedMap(this.compare);
		m.root = deepCopyNode(this.root);
		m.length = this.length;
		return m;
	}

	inline function deepCopyNode(node: TreeNode<K, V>) {
		return switch node {
			case null: null;
			case _: new TreeNode(
				deepCopyNode(node.left),
				node.key,
				node.value,
				deepCopyNode(node.right)
			);
		}
	}

	function merge(t1, t2) {
		if (t1 == null)
			return t2;
		if (t2 == null)
			return t1;
		var t = minBinding(t2);
		return balance(t1, t.key, t.value, removeMinBinding(t2));
	}

	function minBinding(t: TreeNode<K, V>) {
		return
        if (t == null) 
            throw "Not_found"; 
        else if (t.left == null) 
            t;
        else 
            minBinding(t.left);
	}

	function removeMinBinding(t: TreeNode<K, V>) {
		return if (t.left == null) t.right; else balance(removeMinBinding(t.left), t.key, t.value, t.right);
	}

	function balance(l:TreeNode<K, V>, k:K, v:V, r:TreeNode<K, V>):TreeNode<K, V> {
		var hl = l.get_height();
		var hr = r.get_height();
		return if (hl > hr + 2) {
			if (l.left.get_height() >= l.right.get_height())
				new TreeNode<K, V>(l.left, l.key, l.value, new TreeNode<K, V>(l.right, k, v, r));
			else
				new TreeNode<K, V>(new TreeNode<K, V>(l.left, l.key, l.value, l.right.left), l.right.key, l.right.value,
					new TreeNode<K, V>(l.right.right, k, v, r));
		} else if (hr > hl + 2) {
			if (r.right.get_height() > r.left.get_height())
				new TreeNode<K, V>(new TreeNode<K, V>(l, k, v, r.left), r.key, r.value, r.right);
			else
				new TreeNode<K, V>(new TreeNode<K, V>(l, k, v, r.left.left), r.left.key, r.left.value,
					new TreeNode<K, V>(r.left.right, r.key, r.value, r.right));
		} else {
			new TreeNode<K, V>(l, k, v, r, (hl > hr ? hl : hr) + 1);
		}
	}

	public function toString() {
		return root == null ? '{}' : '{${root.toString()}}';
	}
}

/**
	A tree node of `haxe.ds.BalancedTree`.
**/
private class TreeNode<K, V> {
	@:native('l') 
	public var left : TreeNode<K, V>;
	@:native('r') 
	public var right : TreeNode<K, V>;
	@:native('k') 
	public var key : K;
	@:native('v') 
	public var value : V;

	@:native('lH')
	#if as3
	public
	#end
	var _height : Int;

	public function new(l, k, v, r, h = -1) {
		left = l;
		key = k;
		value = v;
		right = r;
		if (h == -1)
			_height = (left.get_height() > right.get_height() ? left.get_height() : right.get_height()) + 1;
		else
			_height = h;
	}

	extern public inline function get_height():Int
		return this == null ? 0 : _height;

	extern public inline function dispose() {
		if (this != null) {
			left.dispose();
			left = null;
			right.dispose();
			right = null;
			key = null;
			value = null;
			_height = -1;
		}
	}

	public function toString() {
		return (left == null ? "" : left.toString() + ", ") + '$key=$value' + (right == null ? "" : ", " + right.toString());
	}
}

class TreeWalker<K, V> {
	var node:TreeNode<K, V>;

	public function new(root) {
		this.node = root;
	}
	public function compute():TreeStep<K, V> {
		if (node == null) {
			return End;
		}
		else {
			var steps = [End, End, End];
			if (node.left != null)
				steps[0] = Walk(new TreeWalker(node.left));
			steps[1] = Yield(node);
			if (node.right != null)
				steps[2] = Walk(new TreeWalker(node.right));
			return switch steps {
				case [End, self, End]: self;
				case [left, self, End]: Lnk(left, self);
				case [End, self, right]: Lnk(self, right);
				case [left, self, right]: Lnk(left, Lnk(self, right));
				default:
					throw new Error('Invalid: ${steps}');
			}
		}
	}

	public function pack() {
		var currentIter:Iterator<TreeNode<K, V>> = cast new EmptyIterator();
		var currentStep = End;
		var stack = new LinkedStack();
		var completion = {};
		
		function inner_next() {
			switch currentStep {
				case End:
					currentIter = null;

				case Yield(node):
					currentIter = new SingleIterator(node);
					currentStep = End;

				case Walk(walker):
					currentIter = walker.get().pack();
					currentStep = End;

				case Lnk(current, next):
					stack.push(next.get());
					currentIter = Std.is(currentIter, EmptyIterator)?currentIter:new EmptyIterator();
					currentStep = current;
			}
		}

		function outer_next():TreeNode<K, V> {
			while (true) {
				if (currentIter == null && currentStep.match(End)) {
					// throw new Error('Invalid call; iteration has finished');
					if (stack.isEmpty()) {
						throw new Error('Invalid call; iteration is complete');
					}
					else {
						currentStep = stack.pop();
						inner_next();
					}
				}
				else if (currentIter.hasNext()) {
					return currentIter.next();
				}
				else {
					inner_next();
					continue;
				}
			}
		}

		var isComplete = false;
		function hasNext():Bool {
			if (isComplete) return false;
			else if (!(currentIter == null && currentStep.match(End) && stack.isEmpty())) {
				return currentIter.hasNext();
			}
			else {
				isComplete = true;
				return false;
			}
		}

		return {
			hasNext: hasNext,
			next: outer_next
		};
	}
}

enum TreeStep<K,V> {
	End;
	Yield(node: TreeNode<K, V>);
	Walk(walker: Lazy<TreeWalker<K, V>>);
	Lnk(current:TreeStep<K, V>, next:Lazy<TreeStep<K, V>>);
}