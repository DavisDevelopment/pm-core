package pm.io.chunk;

import haxe.io.Bytes;
import haxe.io.BytesData;

@:allow(pm.io.chunk)
@:allow(pm.io.chunk.IChunk)
class ByteChunk extends ChunkBase implements IChunkObject {
    //TODO: on JS this pretty much reinvents the wheel

    var data : BytesData;
    var from : Int;
    var to : Int;

    var wrapped(get, null):Bytes;
    private inline function get_wrapped() {
        if (wrapped == null)
            wrapped = Bytes.ofData(data);
        return wrapped;
    }

    function new(data, from, to) {
        super();
        this.data = data;
        this.from = from;
        this.to = to;
    }

    public inline function getByte(index:Int):pm.Byte {
        return Bytes.fastGet(data, from + index);
    }

    override public function flatten(into:Array<ByteChunk>) {
        into.push( this );
    }

    public inline function getLength():Int {
        return to - from;
    }

    public function getSlice(from:Int, to:Int):ByteChunk {
        if (to > this.getLength())
            to = this.getLength();
        
        if (from < 0)
            from = 0;
        
        return
            if (to <= from)
                null;
            else if (to == this.getLength() && from == 0) 
                this;
            else 
                new ByteChunk(data, this.from + from, to + this.from);
    }
        
    public function slice(from:Int, to:Int):Chunk {
        return
        switch getSlice(from, to) {
            case null: 
                Chunk.EMPTY;
            case v:
                v;
        }
    }

    public function blitTo(target:Bytes, offset:Int):Void {
        target.blit(offset, wrapped, from, getLength());
    }

    public inline function toBytes():haxe.io.Bytes {
        return wrapped.sub(from, getLength());
    }

    public inline function toString(?encoding: String):String {
        return wrapped.getString(from, getLength());
    }

    public inline function toData():Dynamic return getData(this);

    static inline function _data(c: ByteChunk):BytesData {
        if (c.from == 0 && c.to == c.wrapped.length) {
            #if (js && !macro)
                // return data.slice(from, to);
                return c.data;
            #else
                return c.wrapped.sub(c.from, c.to - c.from).getData();
            #end
        }
        else {
            #if (js && !macro)
            return c.data.slice(c.from, c.to);
            #else
            return haxe.io.Bytes.ofData(c.data).sub(c.from, c.to - c.from).getData();
            #end
        }
    }
    public static inline function getData(c: ByteChunk):Dynamic {
        return _data( c );
    }

    static public function of(b: Bytes):Chunk {
        if (b.length == 0)
            return Chunk.EMPTY;
        var ret = new ByteChunk(b.getData(), 0, b.length);
        ret.wrapped = b;
        return ret;
    }
}