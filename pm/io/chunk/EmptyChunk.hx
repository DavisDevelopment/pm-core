package pm.io.chunk;

import haxe.io.Bytes;
import haxe.io.BytesData;
import pm.io.chunk.*;

@:allow(pm.io.chunk)
@:allow(pm.io.chunk.IChunk)
class EmptyChunk extends ChunkBase implements IChunkObject {
    public function new() {
        super();
    }
    
    public function getByte(i: Int):Int {
        return 0;
    }
        
    public function getLength():Int {
        return 0;
    }

    override function flatten(into: Array<ByteChunk>) {
        return ;
    }
        
    public function slice(from:Int, to:Int):Chunk {
        return this;
    }
        
    public function blitTo(target:Bytes, offset:Int):Void {
        return ;
    }
        
    public function toString(?encoding: String):String {
        return '';
    }
        
    public function toBytes():Bytes {
        return EMPTY;
    }

    public function toData():Dynamic {
        return toString();
    }
        
    static var EMPTY = Bytes.alloc(0);
}