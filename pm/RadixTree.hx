package pm;

import haxe.ds.Option;
using StringTools;
using pm.Strings;
using pm.Numbers;

class RadixTreeNode<T> {
    public var path:String;
    public var fullPath:String;
    public var data: T;
    public var priority: Int;
    public var type: NodeType;
    public var children:Array<RadixTreeNode<T>>;

    public function new(path:String='', fullPath:String='', data:T=null) {
        this.path = path;
        this.fullPath = fullPath;
        this.data = data;
        this.priority = 1;
        this.type = NodeType.DEFAULT;
        this.children = new Array();
    }

    public function append(node: RadixTreeNode<T>) {
        children.push(node);
        sort();
    }

    public function sort() {
        this.children.sort((a, b) -> pm.Numbers.Ints.compare(a.priority, b.priority));
    }

    public function remove(node: RadixTreeNode<T>) {
        final position = this.children.indexOf(node);
        if (position == -1) {
            return ;
        }
        this.children.splice(position, 1);
    }
}

enum abstract NodeType(Int) {
    var DEFAULT = 0;
    var PARAM = 1;
    var CATCHALL = 2;
}

class RadixTree<T> {
    public var root:Null<RadixTreeNode<T>>;
    public function new() {
        this.root = null;
    }
    public function add(path:String, data:T) {
        if (this.isEmpty()) {
            this.root = new Node('', '', null);
        }
        final fullPath = path;
        var node = this.root;
        node.priority++;
        while (node != null) {
            path = path.substr(node.path.length);
            if (path.length == 0) {
                if (node.data != null) {
                    throw new Error('Node already defined');
                }
                node.data = data;
                return this;
            }

            if (node.children.length != 0) {
                var jumpBack = {};
                try {
                    for (nodeIndex in 0...node.children.length) {
                        if (node.children[nodeIndex].path.charAt(0) == path.charAt(0)) {
                            var selectedNode = node.children[nodeIndex];
                            var pathCompareIndex = 0;
                            while (pathCompareIndex < selectedNode.path.length.min(path.length)) {
                                if (path.charAt(pathCompareIndex) != selectedNode.path.charAt(pathCompareIndex)) {
                                    break;
                                }
                                pathCompareIndex++;
                            }

                            // go further down the tree
                            if (pathCompareIndex >= selectedNode.path.length) {
                                node.children[nodeIndex].priority++;
                                node.sort();
                                node = selectedNode;

                                throw jumpBack;
                            }
                            else if (pathCompareIndex >= path.length) {
                                var newChild = new Node(path, fullPath, data);
                                selectedNode.path = selectedNode.path.replace(path, '');
                                node.remove(selectedNode);
                                newChild.priority = selectedNode.priority+1;
                                newChild.append(selectedNode);
                                node.append(newChild);
                                return this;
                            }
                            else if (pathCompareIndex > 0) {
                                var newEdge = new Node(path.substr(0, pathCompareIndex), '', null);
                                selectedNode.path = selectedNode.path.substr(pathCompareIndex);
                                newEdge.priority = selectedNode.priority + 1;
                                node.remove(selectedNode);
                                node.append(newEdge);
                                newEdge.append(selectedNode);
                                node = newEdge;
                                throw jumpBack;
                            }
                        }
                    }
                }
                catch (err: Dynamic) {
                    if (err == jumpBack) continue;
                    else {
                        #if js
                        js.Lib.rethrow();
                        #else
                        throw err;
                        #end
                    }
                }
            }

            //log('no matching child found, appending')
            this.appendNode(node, path, fullPath, data);
            return this;
        }

        return this;
    }
    public function appendNode(node:Node<T>, path:String, fullPath:String, data:T) {
        var offset = 0; 

        var child = new Node('', '', null);
        
        for (index in 0...path.length) {
            var character = path.charAt(index);
            
            if (character != ':' && character != '*') {
                continue;
            }

            if (character == ':') {
                if (node.children.length != 0 && index == 0) {
                    throw new Error('Param node can not be appended to an already existing path');
                }

                if (offset < index - offset) {
                    child.path = path.substr(offset, index - offset);
                    
                    offset = index;
                    node.append(child);
                    node = child;
                }

                child = new Node();
                child.type = NodeType.PARAM;
            }
            else if (character == '*') {
                if (node.children.length != 0 && index == 0) {
                    throw new Error('Catchall node can not be appended to an already existing path');
                }

                if (offset < index - offset) {
                    child.path = path.substr(offset, index - offset);

                    offset = index;
                    node.append(child);
                    node = child;
                }

                child = new Node();
                child.type = NodeType.CATCHALL;
            }
        }

        child.path = path.substr(offset);
        child.fullPath = fullPath;
        child.data = data;
        node.append(child);
        return this;
    }
    public function isEmpty():Bool {
        return this.root == null;
    }

    public function remove(path:String) {
        if (isEmpty()) {
            return this;
        }

        var node = this.root;
        var offset = node.path.length;
        var interrupt = {}; 
        var pathLength = path.length;
        var passedNodes = [];
        function step(child: Node<T>):Null<Outcome<RadixTree<T>, Dynamic>> {
            if (child.type == NodeType.DEFAULT) {
                if (path.charAt(offset) == child.path.charAt(0) && path.indexOf(child.path, offset) == offset) {
                    node = child;
                    offset += node.path.length;
                    return Outcome.Failure(interrupt);
                }
            }
            else if (child.type == NodeType.PARAM) {
                if (path.charAt(offset) != ':') {
                    return Outcome.Success(this);
                }
                var paramEnd = path.indexOf('/', offset);
                paramEnd = paramEnd != -1 ? paramEnd : pathLength;
                if (child.path != path.substr(offset, paramEnd - offset)) {
                    return Outcome.Success(this);
                }
                offset = paramEnd;
                node = child;
                return Outcome.Failure(interrupt);
            }
            else if (child.type == NodeType.CATCHALL) {
                if (path.charAt(offset) != '*') {
                    return Outcome.Success(this);
                }
                if (child.path != path.substr(offset)) {
                    return Outcome.Success(this);
                }
                offset = path.length;
                node = child;
                return Outcome.Failure(interrupt);
            }
            return null;
        }

        while (node != null) {
            passedNodes.push(node);
            if (pathLength == offset) break;
            if (node.children.length == 0) return this;
            var c = false;

            for (index in 0...node.children.length) {
                var child = node.children[index];
                var stepOutcome = step(child);
                switch stepOutcome {
                    case null:
                        break;
                    case Success(t):
                        return t;
                    
                    case Failure(error):
                        if (error == interrupt) {
                            c = true;
                            break;
                        }
                        else {
                            throw error;
                        }

                    default:
                        throw 'Unhandled';
                }
                break;
            }
        }

        passedNodes.reverse();
        node = passedNodes[0];
        var parentNode = passedNodes[1];
        switch node.children.length {
            case 0:
                parentNode.remove(node);

            case 1:
                var childNode = node.children[0];
                childNode.path = node.path + childNode.path;
                parentNode.remove(node);
                parentNode.append(childNode);

            default:
        }

        return this;
    }
}
private typedef Node<T> = RadixTreeNode<T>;