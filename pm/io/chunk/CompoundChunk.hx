package pm.io.chunk;

import haxe.io.Bytes;
import haxe.io.BytesData;
import pm.io.chunk.*;

using pm.Arrays;

@:allow(pm.io.chunk)
@:allow(pm.io.chunk.IChunk)
class CompoundChunk extends ChunkBase implements IChunkObject {
  private var left:Chunk;
  private var right:Chunk;
  
  var split: Int;
  var length: Int;
  
  public inline function getByte(i: Int):pm.Byte {
    return i < split ? left.getByte(i) : right.getByte(i - split);
  }
  
  public inline function getLength():Int {
    return this.length;
  }
    
  public function new(left:Chunk, right:Chunk) {
    super();
    //TODO: try balancing here
    this.left = left;
    this.right = right;
    this.split = left.length;
    this.length = split + right.length;
  }

  @:access(pm.io.chunk.IChunk)
  public static function make(a:Chunk, b:Chunk):Chunk {
    if ((a is pm.io.chunk.EmptyChunk)) {
      if ((b is pm.io.chunk.EmptyChunk)) {
        return Chunk.EMPTY;
      }
      else {
        return b;
      }
    }
    else {
      return new CompoundChunk(a, b);
    }
  }
  
  override public function flatten(into: Array<ByteChunk>) {
    return Chunk.flatten(this, into);
  }
    
  public inline function slice(from:Int, to:Int):Chunk {
    return left.slice(from, to).concat(right.slice(from - split, to - split));
  }
    
  public function blitTo(target:Bytes, offset:Int):Void {
    left.blitTo(target, offset);
    right.blitTo(target, offset + split);
  }
    
  public inline function toString(?encoding: String):String {
    // /*[ORIGINAL]*/ return toBytes().toString();
    return left.getString( encoding ) + right.getString( encoding );
  }
    
  public function toBytes() {
    var ret = Bytes.alloc(this.length);
    blitTo(ret, 0);
    return ret;
  }

  public function toData():Dynamic {
    return (ByteChunk.of(toBytes()) : IChunkObject).toData();
  }
}