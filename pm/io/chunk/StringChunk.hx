package pm.io.chunk;

package tink.chunk;

import haxe.io.Bytes;
import haxe.io.BytesData;

@:allow(pm.io.chunk)
@:allow(pm.io.chunk.IChunk)
class StringChunk extends ChunkBase implements IChunkObject {
    private var data : String;
    private var from : Int;
    private var to : Int;

    function new(data, from, to) {
        super();
        this.data = data;
        this.from = from;
        this.to = to;
    }

    public inline function getByte(index:Int):pm.Byte {
        // return Bytes.fastGet(data, from + index);
        return StringTools.fastCodeAt(data, from + index);
    }

    override public function flatten(into: Array<ByteChunk>) {
        into.push(asByteChunk());
    }

    function asByteChunk(?encoding: String):ByteChunk {
        #if (js && !macro)
            var d = js.Syntax.code('Uint8Array.from(Array.from({0}, c=>c.charCodeAt(0)))', toString(encoding)).buffer;
            return new ByteChunk(d, from, to);
        #else
            return ByteChunk.of(toBytes());
        #end
    }

    public inline function getLength():Int {
        return to - from;
    }

    public function getSlice(from:Int, to:Int):StringChunk {
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
                new StringChunk(data, this.from + from, to + this.from);
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

    public function toString(?encoding: String):String {
        if (encoding == null) {
            return data;
        }
        else {
            #if (js && !macro)
                #if hxnodejs
                return js.node.Buffer.from(data).slice(from, to).toString(encoding);
                #else
                    untyped __js__('if (typeof Buffer !== "undefined") {return Buffer.from({0}).slice({1}, {2}).toString({3});}', data, from, to, encoding);
                #end
            #else
            return wrapped.getString(from, getLength());
            #end
        }
    }

    var wrapped(get, null):Bytes;
    private inline function get_wrapped() {
        if (wrapped == null)
            wrapped = Bytes.ofString(data);
        return wrapped;
    }
}