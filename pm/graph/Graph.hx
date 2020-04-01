package pm.graph;

import pm.graph.Edge.EdgeBase;
import Type.ValueType;
import pm.graph.Edge.ProtoEdge;
import pm.graph.Edge as TEdge;

import pm.Helpers.*;
import pm.Arch.isInt;
// import pm.Arch.isInt;

using pm.Arrays;

class Graph /* <Edge:TEdge> */ {
    private var _vertices:Array<Vertex>;
    private var _edges:Array<Edge>;
    
    public function new() {
        this._vertices = new Array();
        this._edges = new Array();
    }
    
    public var vertices(get, never):Array<Vertex>;
    public inline function get_vertices():Array<Vertex> {return this._vertices;}
    
    public var edges(get, never):Array<Edge>;
    
    public inline function get_edges():Array<Edge> {
        return this._edges;
    }

    public dynamic function newVertex(id:Int, ?content:Dynamic):Vertex {
        final v = new Vertex(id);
        v.content = content;
        return v;
    }

    public dynamic function newEdge(id:Int, top:Null<Vertex>, bottom:Null<Vertex>, ?content:Dynamic):Edge {
        return new EdgeBase(id, top, bottom, content);
    }
    
    public inline function addVertex(uplinks: Array<Vertex>):Vertex {
        final v = newVertex(this._vertices.length);
        if (this._vertices.length != 0)
            this._vertices[0].last.insertAfter(v);
        this._vertices.push(v);
        for (l in uplinks) {
            var newEdge:Edge = cast l.connectTo(v, _edges.length, this.newEdge);
            this._edges.push(newEdge);
        }
        return v;
    }
    
    public inline function addEdge(top:Vertex, bottom:Vertex):Edge {
        final proto:ProtoEdge = {
            top: top,
            bottom: bottom
        };
        var cb = (e:ProtoEdge) -> e.top == proto.top && e.bottom == proto.bottom;
        final cond = top.availableConnections().some(cb);
        if (cond) {
            throw new pm.Error("Unable to create edge.  Circular connection detected!");
        }
        var e = top.connectTo(bottom, this._edges.length);
        this._edges.push(e);
        return e;
    }
    
    public inline function availableEdges():Array<ProtoEdge> {
        var res:Array<ProtoEdge> = new Array();
        inline function add(e: Array<ProtoEdge>) {
            for (x in e)
                res.push(x);
        }

        // return _vertices.reduce(function(prev:Array<ProtoEdge>, cur:Vertex):Array<ProtoEdge> {
        //     // return nullprev, cur.availableConnections()];
        //     // return prev.concat(cur.availableConnections());
        //     var acc = prev;
        //     for (c in cur.availableConnections())
        //         acc.push(c);
        //     return acc;
        // }, res);
        for (v in _vertices)
            add(v.availableConnections());
        return res;
    }
    
    private inline function _traverse(v:Vertex, i:Int, cb:TraversalCallback):Void {
        // !cb(v, i) && v.next && this._traverse(v.next, i + 1, cb);
        cb(v, i);
        if (v.next != null)
            _traverse(v.next, i+1, cb);
    }
    
    private inline function _traverseLoop(v:Vertex, cb:TraversalCallback) {
        var i:Int = 0;
        do {
            cb(v, i++);
            v = v.next;
        }
        while (v != null);
    }
    
    public function traverse(cb:TraversalCallback) {
        if (this._vertices.length != 0) {
            _traverse(this._vertices[0].first, 0, cb);
        }
    }
    
    public inline function clear() {
        this._vertices = [];
        this._edges = [];
    }

    public dynamic function isEdge(x: Dynamic):Bool {
        var t = (v:Dynamic) -> true;
        inline function test(f:String, ?validate:Dynamic->Bool):Bool {
            // validate = nor(validate, t);
            final has = Reflect.hasField(x, f);
            return has && (validate != null ? validate(Reflect.field(x, f)) : true);
        }

        if (x == null) return false;
        if (Reflect.isObject(x)) {
			return (test('id', isInt)
				&& test('top', v -> v == null || (v is Vertex))
				&& test('bottom', v -> v == null || (v is Vertex))
				&& test('content'));
        }
        else {
            return false;
        }
    }

    public dynamic function toEdge(input: Dynamic):Edge {
        if (isEdge(input)) return (input : Edge);
        throw new pm.Error('Invalid input for toEdge');
    }
}

typedef TraversalCallback = (vertex:Vertex, index:Int)->Void;