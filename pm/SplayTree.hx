package pm;

class SplayTree<K, V> {
    public function new() {
        root = null;
    }

    function compareKeys(a:K, b:K):Int {
        return Arch.compareThings(a, b);
    }
    inline function lt(a:K, b:K):Bool {
        return compareKeys(a, b) < 0;
    }
    inline function gt(a:K, b:K):Bool {
        return compareKeys(a, b) > 0;
    }

    public function isEmpty():Bool {
        return false;
    }

    public function splay(key: K):Void {
        if (isEmpty()) {
            return ;
        }

        var dummy, left, right;
        dummy = left = right = new SplayTreeNode(null, null);
        var current = this.root;
        while (true) {
            if (lt(key, current.key)) {
                if (current.left == null) {
                    break;
                }
                if (lt(key, current.left.key)) {
                    // rotate right
                    var tmp = current.left;
                    current.left = tmp.right;
                    tmp.right = current;
                    current = tmp;
                    if (current.left == null) {
                        break;
                    }
                }
                // link right
                right.left = current;
                right = current;
                current = current.left;
            }
            else if (gt(key, current.key)) {
                if (current.right == null) {
                    break;
                }
                if (gt(key, current.right.key)) {
                    // rotate left
                    var tmp = current.right;
                    current.right = tmp.left;
                    tmp.left = current;
                    current = tmp;
                    if (current.right == null) {
                        break;
                    }
                }

                // link left
                left.right = current;
                left = current;
                current = current.right;
            }
            else {
                break;
            }
        }

        // Assemble
        left.right = current.left;
        right.left = current.right;
        current.left = dummy.right;
        current.right = dummy.left;
        this.root = current;
    }

    public function traverse(f: SplayTreeNode<K, V> -> Void):Void {
        var nodesToVisit = new LinkedQueue();
        while (nodesToVisit.size() > 0) {
            var node = nodesToVisit.dequeue();
            if (node == null) {
                continue;
            }
            f( node );
            nodesToVisit.enqueue(node.left);
            nodesToVisit.enqueue(node.right);
        }
    }

    public function reduceNodes<Agg>(reducer:Agg -> SplayTreeNode<K, V> -> Agg, init:Agg):Agg {
        var agg:Agg = init;
        traverse(function(node) {
            agg = reducer(agg, node);
        });
        return agg;
    }

    public var root(default, null):SplayTreeNode<K, V>;
}

class SplayTreeNode<K, V> {
    public var key: K;
    public var value: V;

    public inline function new(key, value) {
        this.key = key;
        this.value = value;
    }

    public var left: SplayTreeNode<K, V> = null;
    public var right:SplayTreeNode<K, V> = null;
}