package pm.io.chunk;

import pm.io.chunk.IChunk;

class ChunkBase {
    var flattened:Array<ByteChunk> = null;

    function new() {
        //
    }

    public function getCursor() {
        if (flattened == null) {
            // flatten(flattened = []);
            flattened = new Array();
            Chunk.flatten(cast(this, IChunkObject), flattened);
        }
        return ChunkCursor.create( flattened );
    }

    public function flatten(into: Array<ByteChunk>):Void {}    
}