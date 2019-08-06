package pm.io;

import haxe.macro.Expr;
import pm.async.*;
import pm.Outcome;
import pm.Lazy;
import haxe.ds.Option;
import haxe.io.*;
import pm.io.Chunk;
import pm.io.chunk.ChunkCursor;
import pm.io.chunk.Seekable;

import pm.ImmutableList;
import pm.LinkedQueue;
import pm.Error;
import pm.Arch;
import pm.Assert.assert;

using StringTools;
using pm.Strings;
using pm.Arrays;
using pm.Options;
using pm.Functions;
using pm.Outcome;

enum DataStreamStep<T> {
    Wait;
    Throw(err: Dynamic);
    Yield(value:T, offset:Int);
}
enum DataStreamInterrupt {
    Exception<E>(error:E, ?pos:haxe.PosInfos);
}
enum DataStreamStatus {
    
}

/**
  TODO: refactor this class to also allow for optimizations when the entire buffer is appended at once
 **/
class DataStream {
    var cursor: ChunkCursor = null;

    /* Constructor Function */
    public function new(?chunk: Chunk) {
        if (chunk != null && chunk.length != 0)
            append(chunk);
    }

    public function append(chunk: Chunk) {
        if (closed) {
            throw new pm.Error("Cannot append to closed DataStream");
        }
        var wasConsumed = this.consumed;
        if (cursor == null) {
            cursor = chunk.cursor();
        }
        else {
            // var tmp = cursor.currentPos;
            cursor.add(chunk);
            // trace(tmp, cursor.currentPos);
        }
        halted = false;
        if (!consumed && wasConsumed) {
            if (observer != null) {
                observer.onData.broadcast(chunk);
            }
        }
    }

    public function prepend(c : Chunk) {
        if (closed) {
            throw new pm.Error("Cannot append to closed DataStream");
        }
        else if (consumed) {
            return append( c );
        }
        
        var nc = c.concat(if (cursor == null) Chunk.EMPTY else cursor.right());
        cursor = nc.cursor();
        halted = false;
    }

    public function tell():Int {
        return cursor.currentPos;
    }

    public function readByte():Res<pm.Byte> {
        // if (closed) return 
        if (cursor == null) return Wait;
        if (!cursor.next() || cursor.currentByte == -1) {
            if (closed) {
                return Throw(new haxe.io.Eof());
            }
            else {
                return Wait;
            }
        }
        return Yield(cursor.currentByte, 0);
    }

    public function readLine():Res<Chunk> {
        return readUntil(Seek.bytewise(function(c) {
            return c.isLineBreaking();
        }));
    }

    public function readUInt16(len: Int):Res<haxe.io.UInt16Array> {
        return readTypedArray(this, haxe.io.UInt16Array, len);
    }

    static macro function mergeIn<T>(res: ExprOf<Res<T>>):ExprOf<T> {
        return macro @:mergeBlock {
            var tmp = null;
            switch ($res) {
                case Wait:
                    return Wait;
                case Throw(e):
                    return Throw(e);
                case Yield(v, _):
                    tmp = v;
            }
            tmp;
        };
    }

    static macro function readTypedArray<T>(self:Expr, arrayType:Expr, length):ExprOf<Res<T>> {
        return macro @:mergeBlock {
            var coeff:Int = $arrayType.BYTES_PER_ELEMENT;
            var chunk:Chunk = mergeIn($self.read($length * coeff));
            Yield($arrayType.fromBytes(chunk.toBytes()), 0);
            // switch ($self.read(length * coeff)) {
            //     case 
            // }
        }
    }

    public function read(?size: Int):Res<Chunk> {
        validate();
        if ( consumed ) return Wait;
        if (size == null || (size != null && cursor.length == size)) {
            var ret = cursor.right();
            cursor.clear();
            cursor = null;

            return Yield(ret, 0);
        }
        else if (cursor.length > size) {
            cursor.moveTo(size);
            var ret = cursor.flush();
            return Yield(ret, 0);
        }
        else {
            if (closed) {
                return Throw(new haxe.io.Eof());
            }
            else {
                return Wait;
            }
        }
    }

    /*
    public function readUntil(sub:Seekable):Res<Chunk> {
        switch read() {
            case Wait:
                return Wait;
            case Throw(e):
                return Throw(e);
            case Yield(chunk, _):
                var c = chunk.cursor();
                switch c.seek() {
                    case Some(left):
                        prepend(c.right());
                        return Yield(left, 0);

                    case None:
                        return Wait;
                }
        }
    }
    */

    public function readUntil(seek: Seek):Res<Chunk> {
        if (consumed) return Wait;
        if (cursor.length == 0) return Wait;
        var data:Chunk = mergeIn(read());
        var pos:SeekResult = -1;
        // try {
            pos = seek.apply(data.cursor());
        /*
        }
        catch (sig : DataStreamInterrupt) {
            switch sig {
                case Exception(error, pos):
                    return Throw(new DataStreamException(error, pos));
            }
        }
        catch (error: Dynamic) {
            throw new DataStreamException(error);
        }
        */

        switch pos {
            case -1:
                if (closed) {
                    return Throw(new haxe.io.Eof());
                }
                else {
                    return Wait;
                }

            case offset:
                cursor.moveBy(offset);
                return Yield(cursor.left(), offset);
        }
    }

    public function buffer(size: Int):Res<Input> {
        return switch read(size) {
            case Wait: Wait;
            case Throw(error): Throw(error);
            case Yield(value, pos): Yield(new ChunkInput(value), pos);
        }
    }

    public function close() {
        this.closed = true;
        if (this.observer != null) {
            this.observer.onClose.broadcast(null);
        }
    }

    inline function validate() {
        if (closed) throw new haxe.io.Eof();
    }

    public function observe() {
        if (observer == null) {
            observer = {
                onClose: new Signal<Dynamic>(),
                onData: new Signal<Chunk>()
            };
        }
        return observer;
    }

    static function outcomeRes<T>(o:Outcome<T, Dynamic>):Res<T> {
        try {
            return Yield(o.manifest(), 0);
        }
        catch (e: DataStreamStep<Dynamic>) {
            return switch e {
                case Wait: Wait;
                case Throw(x): Throw(x);
                case Yield(v, i): Yield(v, i); 
            }
        }
    }

    public var consumed(get, never):Bool;
    private inline function get_consumed() {
        return cursor == null;
    }

    public var closed(default, null): Bool = false;
    public var halted(default, null):Bool = false;

    private var observer:{onClose:Signal<Dynamic>, onData:Signal<Chunk>} = null;
}


private typedef Res<T> = DataStreamStep<T>;
typedef SeekResult = Int;
private typedef SeekFn = (data: ChunkCursor)->SeekResult;
abstract Seek(SeekFn) from SeekFn to SeekFn {
    @:selfCall
    public inline function apply(data: ChunkCursor):SeekResult {
        assert(data != null, new pm.Error());
        return this( data );
    }
    
    @:from
    public static inline function chunk(chunk: Chunk):Seek return ofSeekable(chunk);
    
    @:from
    public static inline function bytes(b: Bytes):Seek return ofSeekable(b);
    
    @:from
    public static inline function string(s: String):Seek return ofSeekable( s );

    @:from
    public static inline function chunkFn(f: Chunk -> SeekResult):Seek {
        return (c -> f(c.right()));
    }
    
    @:from
    public static function ofSeekable(seek: Seekable):Seek {
        return function(cursor: ChunkCursor):SeekResult {
            var tmp = cursor.seek(seek);
            switch (tmp) {
                case Some(c):
                    var res = c.length;
                    return res;

                case None:
                    return -1;
            }
            return -1;
        }
    }

    @:from
    public static inline function ofSofn(sofn: pm.Sofn<ChunkCursor, SeekResult>):Seek {
        return function(cursor: ChunkCursor):SeekResult {
            return sofn.invoke( cursor );
        }
    }

    @:from
    public static inline function bytewise(check: pm.Byte -> Bool):Seek {
        return function(cursor: ChunkCursor):SeekResult {
            do {
                var c:pm.Byte = cursor.currentByte;
                if (c == -1) {
                    return -1;
                }
                else if (check( c )) {
                    return cursor.currentPos;
                }
            }
            while (cursor.next());
            return -1;
        }
    }
}

class ChunkInput extends haxe.io.Input {
    public var chunk(default, null): Chunk;
    public var cursor(default, null): ChunkCursor;
    public function new(chunk) {
        this.chunk = chunk;
        this.cursor = this.chunk.cursor();
    }
    override function readByte():Int {
        this.cursor.next();
        return this.cursor.currentByte;
    }
}

class StillWaitingError extends pm.Error {}
class DataStreamException<Err> extends pm.Error.ValueError<Err> {
    public function new(error:Err, ?msg:String, ?pos:haxe.PosInfos) {
        super(error, msg, 'DataStreamException', pos);
    }
}

class DataStreams {
    public static inline function await<T>(value:Lazy<Res<T>>):Promise<T> {
        throw 'ass';
    }
}