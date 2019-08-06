package pm.io.chunk;

import haxe.io.Bytes;

import js.node.Buffer;

import pm.io.Chunk;
import pm.io.chunk.IChunk;
import pm.io.chunk.*;

class BufferChunk implements IChunkObject {
    private var buffer : Buffer;

    public function new(buffer) {
        this.buffer = buffer;
    }

    public inline function getByte(i:Int):Int  {
        return buffer[i];
    }

    public inline function getCursor():ChunkCursor {
        return (toBytes() : Chunk).cursor();
    }

    public inline function flatten(into) {
        ((toBytes() : Chunk) : IChunkObject).flatten(into);
    }

    public inline function getLength():Int {
        return buffer.length;
    }

    public function slice(from:Int, to:Int):Chunk {
        if (to > this.getLength())
            to = this.getLength();
        
        if (from < 0)
            from = 0;
        
        return
            if (to <= from) 
                Chunk.EMPTY;
            else if (to == this.getLength() && from == 0) 
                this ;
            else {
                trace(from, to);
                new BufferChunk(buffer.slice(from, to));
            }
    }

    public function toString(?encoding: String):String {
        return encoding == null ? buffer.toString() : buffer.toString(encoding);
    }

    public function toBytes():Bytes {
        var copy = alloc(buffer.length);
        
        buffer.copy(copy);
        return copy.hxToBytes();
    }

    public function toData():Dynamic {
        return buffer;
    }

    static var alloc:Int->Buffer = 
        if (untyped __js__('"allocUnsafe" in Buffer')) Buffer.allocUnsafe;
        else function (size) return new Buffer(size);

    public function blitTo(target:Bytes, offset:Int):Void {
        return buffer.copy(Buffer.hxFromBytes(target), offset);
    }
}
