package pm.tree;

import pm.Pair;

import haxe.ds.Option;

import pm.AVLTree;

using Lambda;
using pm.Arrays;

@:access(pm.AVLTree)
class TreeItr <Key, Value> {
    /* Constructor Function */
    public function new(tree: AVLTree<Key, Value>) {
        this.tree = tree;
        this.node = tree.root;
        this.queue = new List();
        this.stopped = false;
    }

/* === Methods === */

    public function isValidNode(node: AVLTreeNode<Key, Value>):Bool {
        return true;
    }

    public function hasNext():Bool {
        if ( stopped ) 
            return false;

        while ( true ) {
            if (node == null && queue.empty())
                return false;

            switch [node.left, node.right] {
                case [null, null]:
                    node = queue.pop();

                case [x, null]|[null, x] if (x != null):
                    node = x;

                case [left, right]:
                    queue.push( right );
                    node = left;
            }

            // ensures that when [hasNext] returns, the next available 'valid' node has been found
            if (!isValidNode( node )) {
                continue;
            }

            //return true;
            break;
        }

        return (node != null);
    }

    public function next():AVLTreeNode<Key, Value> {
        if (node == null) {
            throw new Error('.next() is not allowed to return null');
        }

        return node;
    }

    public function abort():Void {
        stopped = true;
        return ;
    }

/* === Variables === */

    var tree(default, null): AVLTree<Key, Value>;
    var node(default, null): Null<AVLTreeNode<Key, Value>>;
    var queue(default, null): List<AVLTreeNode<Key, Value>>;
    var stopped(default, null): Bool;
}
