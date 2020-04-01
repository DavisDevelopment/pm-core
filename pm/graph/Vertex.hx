package pm.graph;

import pm.graph.Edge;
import pm.Helpers.*;

using pm.Arrays;

class Vertex {
    private var _id:Int;
    private var _next:Vertex = null;
    private var _previous:Vertex = null;
    private var _uplinks:Array<Edge> = [];
    private var _downlinks:Array<Edge> = [];

    static inline public function join(v1:Vertex, v2:Vertex) {
        if (nn(v1))
            v1._next = v2;
        if (nn(v2))
            v2._previous = v1;
    }

    static inline public function unjoin(vertex:Vertex) {
        vertex._next = null;
        vertex._previous = null;
    }

    public function new(id = 0) {
        this._id = id;
    }

    public var content:Dynamic;

    public var id(get, never):Int;
    inline function get_id() {return this._id;}

    public var uplinks(get, never):Array<Edge>;
    inline public function get_uplinks():Array<Edge> {
        return this._uplinks;
    }

    public var downlinks(get, never):Array<Edge>;
    public inline function get_downlinks():Array<Edge> {
        return this._downlinks;
    }

    public var first(get, never):Vertex;
    public inline function get_first():Vertex {
        return nn(this._previous) ? this._previous.first : this;
    }

    public var before(get, never):Array<Vertex>;

    public inline function get_before():Array<Vertex> {
        if (nn(this._previous)) {
            return [this._previous].concat(this._previous.before);
        } 
        else {
            return [];
        }
    }

    public var previous(get, never):Vertex;
    inline public function get_previous() {
        return this._previous;
    }

    public var next(get, never):Vertex;
    inline public function get_next() {
        return this._next;
    }

    public var after(get, never):Array<Vertex>;
    public function get_after():Array<Vertex> {
        if (nn(this._next)) {
            return [_next].concat(_next.after);
        } 
        else {
            return [];
        }
    }

    public var last(get, never):Vertex;

    inline public function get_last():Vertex {
        return nn(this._next) ? this._next.last : this;
    }

    public inline function remove():Vertex {
        join(this._previous, this._next);
        unjoin(this);
        return this;
    }

    public function insertBefore(vertex:Vertex):Vertex {
        var previous = this._previous;
        Vertex.join(vertex.previous, vertex.next);
        Vertex.join(previous, vertex);
        Vertex.join(vertex, this);
        return vertex;
    }

    public function insertAfter(vertex:Vertex):Vertex {
        var next = this._next;
        Vertex.join(vertex.previous, vertex.next);
        Vertex.join(this, vertex);
        Vertex.join(vertex, next);
        return vertex;
    }

    public function isBefore(vertex:Vertex):Bool {
        return nn(this._next) && (this._next == vertex || this._next.isBefore(vertex));
    }

    public function isAfter(vertex:Vertex):Bool {
        return nn(this._previous) && (this._previous == vertex || this._previous.isAfter(vertex));
    }

    public function directlyAbove():Array<Vertex> {
        return this._uplinks.map(e -> e.top);
    }

    public function above():Array<Vertex> {
        return directlyAbove().reduce(function(prev:Array<Vertex>, cur:Vertex) {
            var acc = prev.concat([cur].concat(cur.directlyAbove()));
            return acc;
        }, []);
    }

    public function isAbove(vertex:Vertex):Bool {
        if (vertex == this) {
            return false;
        }
        final cb = e -> e == vertex;
        return this.above().some(cb);
    }

    public function directlyBelow():Array<Vertex> {
        return this._downlinks.map(e -> e.bottom);
    }

    public function below():Array<Vertex> {
        return this.directlyBelow().reduce(function(prev:Array<Vertex>, cur:Vertex) {
            // return nullprev, cur, cur.directlyBelow()];
            return prev.concat([cur].concat(cur.directlyBelow()));
        }, []);
    }

    public function isBelow(vertex:Vertex):Bool {
        var __this = this;
        if (vertex == this) {
            return false;
        }
        final cb = e -> e == vertex;
        return this.below().some(cb);
    }

    public function connectTo(vertex:Vertex, id:Int = 0, ?ctor):Edge {
        if (ctor != null) {
            final e:Edge = ctor(id, this, vertex, null);
            _downlinks.push(e);
            vertex._uplinks.push(e);
            return e;
        }
        
        for (e in _downlinks)
            if (e.bottom == vertex)
                throw new pm.Error('The vertices are already connected');
        final e:Edge = {
            id: id,
            top: this,
            bottom: vertex,
            content: null
        };
        _downlinks.push(e);
        vertex._uplinks.push(e);
        return e;
    }

    public function reflow() {
        for (e in _downlinks) {
            if (e.bottom.isBefore(this)) {
                e.bottom.insertBefore(this);
            }
        }
        for (v in above()) {
            v.reflow();
        }
        return this;
    }

    public function availableConnections():Array<ProtoEdge> {
        final protos:Array<ProtoEdge> = new Array();
        final isConnected = (v: Vertex) -> _downlinks.some(e -> e.bottom == v);
        var pointer = this.first;
        while (nn(pointer)) {
            if (pointer != this && !pointer.isBelow(this) && !isConnected(pointer)) {
                protos.push({
                    top: this,
                    bottom: pointer
                });
            }
            pointer = pointer.next;
        }
        return protos;
    }

    public function toString():String {
        return 'Vertex [${this.id}]';
    }

}


//# lineMapping=3,1,4,1,5,1,6,1,7,1,8,6,10,8,12,10,14,11,16,13,18,14,20,20,21,21,22,22,25,29,26,30,27,31,30,34,31,38,34,42,36,45,38,45,39,46,42,50,44,50,45,50,48,53,50,53,51,53,54,56,56,56,57,57,60,61,62,61,63,62,64,63,65,64,66,66,67,67,70,71,72,71,73,72,76,76,78,76,79,77,82,83,84,83,85,84,86,85,87,86,88,88,89,89,92,93,94,93,95,94,98,100,99,101,100,102,101,103,104,110,105,111,106,112,107,113,108,114,109,115,112,122,113,123,114,124,115,125,116,126,117,127,120,134,121,135,124,142,125,143,128,149,129,150,132,156,134,157,135,158,136,159,139,165,141,166,142,167,143,168,144,169,145,170,148,176,149,177,152,183,154,184,155,185,156,186,159,192,161,193,162,194,163,195,164,196,165,197,168,204,170,205,171,205,172,205,174,205,175,206,176,207,177,208,178,209,179,210,180,211,181,212,182,213,183,214,184,215,185,216,186,217,187,218,190,225,192,226,193,226,194,226,196,226,197,227,198,228,199,229,200,230,202,231,203,231,204,231,206,231,207,232,208,233,209,234,212,241,215,243,217,244,218,245,219,246,220,247,221,248,222,249,223,250,224,251,225,252,226,253,227,254,230,260,236,263