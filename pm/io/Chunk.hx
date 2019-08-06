package pm.io;

#if (js && !macro)
import js.JsIterator;
import js.Symbol;
import js.Syntax;
import js.Object;
#end

import pm.LazyItr;
import pm.Numbers.Ints;
import haxe.io.*;
import pm.io.chunk.*;
import pm.io.chunk.IChunk;

using Type;
using Reflect;
using pm.Arrays;
using pm.Iterators;
using pm.Functions;

/**
  `pm.io.Chunk` is abstraction for readonly binary data, that can be sliced and concatenated without copying the actual payload.
 **/
@:pure
abstract Chunk(IChunkObject) from IChunkObject to IChunkObject {
    public var length(get, never):Int;
    private inline function get_length() {
        return this.getLength();
    }

    @:arrayAccess
    @:noCompletion
    public inline function getItem(offset: Int):Int {
        return getByte( offset );
    }

    public inline function getByte(offset: Int):pm.Byte {
        return this.getByte( offset );
    }

    @:to
    public inline function asChunkObject():IChunkObject {
        return this;
    }

    public function concat(that: Chunk):Chunk {
        return switch [length, that.length] {
            case [0, 0]: EMPTY;
            case [0, _]: that;
            case [_, 0]: this;
            case _: CompoundChunk.make(this, that);
        }
    }

    public static function flatten(chunk:Chunk, into:Array<ByteChunk>) {
        _flatten([chunk], into);
    }

    @:access(pm.io.chunk.CompoundChunk)
    static function _flatten(queue:Array<Chunk>, into:Array<ByteChunk>) {
        while (queue.length > 0) {
            var chunk:IChunkObject = queue.shift();
            if ((chunk is ByteChunk)) {
                into.push(cast chunk);
            }
            else if ((chunk is CompoundChunk)) {
                var chunk:CompoundChunk = cast chunk;
                if (chunk.left.length > 0)
                    queue.push( chunk.left );

                if (chunk.right.length > 0)
                    queue.push( chunk.right );
            }
            else {
                continue;
            }
        }
    }

    /**
      provides interface for reading data
     **/
    public inline function cursor() {
        return this.getCursor();
    }
    
    /*    
    public inline function iterator() {
        return new ChunkIterator(this.getCursor());
    }    
    */

    public inline function slice(from:Int, to:Int):Chunk {
        return this.slice(from, to);
    }
        
    public inline function blitTo(target:Bytes, offset:Int) {
        return this.blitTo(target, offset);
    }
    
    public inline function toHex() {
        return this.toBytes().toHex();
    }

    public inline function getString(?encoding: String):String {
        return this.toString(encoding);
    }

    public function getParts():Array<ByteChunk> {
        var res = [];
        flatten(this, res);
        return res;
    }

    public function indexOf(v:Seekable, afterIndex:Int = 0):Int {
        var bytes:Array<Int> = cast v;
        if (bytes.length > length - afterIndex) {
            return -1;
        }
        else {
            for (offset in afterIndex...length) {
                var failed:Bool = false;
                for (i in 0...bytes.length) {
                    if (this.getByte(offset + i) == bytes[i]) {
                        continue;
                    }
                    else {
                        failed = true;
                        break;
                    }
                }
                if (!failed) {
                        return offset;
                }
            }
            return -1;
        }
    }

    public function compare(that: Chunk):Int {
        var len:Int = Ints.min(length, that.length);
        for (i in 0...len) {
            var cmp = Ints.compare(this.getByte(i), that.getByte(i));
            if (cmp != 0) {
                return cmp;
            }
        }
        return Ints.compare(length, that.length);
    }

    public function equals(that: Chunk):Bool {
        if (length != that.length) return false;
        for (i in 0...length) {
            if (getByte(i) != that.getByte(i)) {
                return false;
            }
        }
        return true;
    }

    /**
      flatten out the structure of [this] Chunk by returning a new Chunk from the `haxe.io.Bytes` value of [this] Chunk
      @returns `Chunk.ofBytes(toBytes())`
     **/
    public inline function dirtyFlatten():Chunk {
        return ofBytes(toBytes());
    }
        
    @:to
    public inline function toString() {
        return this.toString();
    }

    @:to
    public inline function toBytes() {
        return this.toBytes();
    }

    public inline function getData():Dynamic {
        return this.toData();
    }
    
    #if (nodejs && !macro)
    @:to 
    public inline function toBuffer() {
        return js.node.Buffer.hxFromBytes(this.toBytes());
    }
    #end
        
    
    static public function join(chunks:Array<Chunk>, copy:Bool=false):Chunk {
        return switch chunks {
            case null | []: EMPTY;
            case [v]: v;
            case v:
                if (!copy) {
                    var ret = v[0] & v[1];
                    for (i in 2...v.length)
                        ret = ret & v[i];
                    ret;
                }
                else {
                    var b = new BytesBuffer();
                    for (c in v) {
                        b.addBytes(c, 0, c.length);
                    }
                    b.getBytes();
                }
        }
    }

    @:op(A + B)
    // @:commutative
    public static inline function concatenation(a:Chunk, b:Chunk):Chunk {
        return a.concat( b );
    }

    @:from 
    public static function ofBytes(b: Bytes):Chunk {
        var bchunk:IChunkObject = ByteChunk.of( b );
        return bchunk;
    }
        
    @:from
    public static inline function ofString(s:String):Chunk {
        return ofBytes(Bytes.ofString( s ));
    }
        
    #if (nodejs && !macro)
    @:from
    public static inline function ofBuffer(s: js.node.Buffer):Chunk {
        // return new tink.chunk.nodejs.BufferChunk(s);
        // throw 'Unimplemented';
        return ofBytes(s.hxToBytes());
    }
    #end

    public static function is(x: Dynamic):Bool {
        return (x is IChunkObject);
    }

    /**
      return a `Chunk` from any value, with support for platform-specific types
      @param x - the untyped value to convert to a `Chunk` 
      @param fast - whether to skip over slower, more expensive conversions for performance
      @param strict - when `true`, values that are not explicitly handled by `Chunk.from` result in an `InvalidOperationError` being thrown. Otherwise, unhandled values are simply converted via `Chunk.ofString(Std.string(x))`
     **/
    public static function from(x:Dynamic, fast:Bool=true, strict:Bool=true):Chunk {
        inline function has(n) return Reflect.hasField(x, n);
        inline function call(o:Dynamic, method:String, args:Array<Dynamic>):Dynamic return o.callMethod(o.field(method), args);
        inline function _from() return from.bind(_, fast, strict);

        if (Chunk.is(x)) return cast(x, IChunkObject);
        if ((x is String)) return cast(x, String);

        //(JavaScript) TypedArray instances and NodeJS Buffers
        #if (js && !macro)
        if (x.buffer != null && (x.buffer is js.lib.ArrayBuffer)) {
            return Bytes.ofData(cast x.buffer);
        }

            #if hxnodejs
            if ((x is js.node.Buffer)) return cast(x, js.node.Buffer);
            #end
        #end
        
        if ((x is Bytes)) return cast(x, Bytes);
        if ((x is Array<Dynamic>)) {
            return join(cast(x, Array<Dynamic>).map(_from()));
        }
        
        if (!fast) {
            /**
              to support things like:
              
              ```haxe
              var data:Chunk = Chunk.from(function() {
                  return ['abc', 'def'];
              }, false);
              ```
             **/
            if (x.isFunction()) {
                try {
                    return from(x(), false, true);
                }
                catch (e: Dynamic) {
                    //
                }
            }

            // {function hxToChunk():Chunk;}
            if (has('hxToChunk')) {
                return from(x.hxToChunk(), false);
            }

            // Iterable<Dynamic>
            if (has('iterator')) {
                try {
                    var itr = pm.Arch.makeIterator( x );
                    return join(itr.array().map(_from()));
                }
                catch (e: Dynamic) {
                    //
                }
            }

            // JavaScript Iterable<Dynamic>
            #if (js && !macro)  
            if (Syntax.strictNeq(Syntax.typeof(untyped x[Symbol.iterator]), 'undefined')) {
                var jsItr:JsIterator<Dynamic> = x.callMethod(untyped x[Symbol.iterator], []);
                // (x, Symbol.iterator), []);
                var litr:LazyItr<Dynamic> = {
                    next: function():LazyItrStep<Dynamic> {
                        var nn = jsItr.next();
                        return {
                            done: nn.done,
                            value: nn.value
                        };
                    }
                };
                // var li:LazyItr<Dynamic> = litr;
                return from(litr.iterator().array().map(_from()));
            }
            #end

            if ( !strict ) {
                return ofString(Std.string(x));
            }
        }

        throw new pm.Error.InvalidOperation('ChunkConversion', 'Cannot cast ${Type.getClass(x).getClassName()} to pm.io.Chunk');
    }
        
    public static function ofHex(s: String):Chunk {
        var length = s.length >> 1;
        var bytes = Bytes.alloc(length);
        for(i in 0...length) 
            bytes.set(i, Std.parseInt('0x' + s.substr(i * 2, 2)));
        return bytes;
    }
        
    @:op(a & b) 
    static function catChunk(a:Chunk, b:Chunk) {
        return a.concat(b);
    }
        
    @:op(a & b) 
    static function rcatString(a:Chunk, b:String) {
        return catChunk(a, b);
    }

    @:op(a & b) 
    static function lcatString(a:String, b:Chunk) {
        return catChunk(a, b);
    }

    @:op(a & b) 
    static function lcatBytes(a:Bytes, b:Chunk) {
        return catChunk(a, b);
    }
        
    @:op(a & b) 
    static function rcatBytes(a:Chunk, b:Bytes) {
        return catChunk(a, b);
    }
        
    public static var EMPTY(default, null):Chunk = ((new EmptyChunk() : IChunkObject) : Chunk); // haxe 3.2.1 ¯\_(ツ)_/¯
}