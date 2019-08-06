package parse.io.chunk;

interface IChunk {}
interface IChunkObject extends IChunk {
    public function getByte(index: Int):pm.Byte;
    public function getLength():Int;
    public function getCursor():ChunkCursor;
    public function flatten(into: Array<ByteChunk>):Void;
    public function slice(from:Int, to:Int):Chunk;
    public function toString(?encoding: String):String;
    public function toBytes():haxe.io.Bytes;
    public function toData():Dynamic;
    public function blitTo(target:haxe.io.Bytes, targetOffset:Int):Void;
}

//typedef ByteChunk = ByteChunk;