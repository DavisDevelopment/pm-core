package pm.graph;

import pm.graph.Vertex;

typedef Edge = {
    var id: Int;
    var top: Null<Vertex>;
    var bottom: Null<Vertex>;
    var content: Dynamic;
}

typedef ProtoEdge = {
    var top: Null<Vertex>;
    var bottom: Null<Vertex>;
}

class EdgeBase<T> {
    public var id:Int;
    public var top:Null<Vertex> = null;
    public var bottom:Null<Vertex> = null;
    public var content: T;

    public function new(id, top, bottom, ?content) {
        this.id = id;
        this.top = top;
        this.bottom = bottom;
        this.content = content;
    }
}