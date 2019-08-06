package pm.io.js.node;

import js.node.Buffer;
import js.node.stream.Readable.IReadable;

import pm.io.chunk.BufferChunk;

import pm.async.*;
import pm.*;

// using tink.CoreApi;
using pm.Functions;
using pm.Outcome;


class WrappedReadable {

    var native : IReadable;
    var name : String;
    var end : Future<Null<Chunk>, Error>;
    var chunkSize : Int;
        
    public function new(name, native, chunkSize, onEnd) {
        this.name = name;
        this.native = native;
        this.chunkSize = chunkSize;
        
        end = new Future(function (cb) {
            native.once('end', function () cb(Success(cast null)));
            native.once('error', function (e:{ code:String, message:String }) cb(Failure(new Error('${e.code} - Failed reading from $name because ${e.message}'))));      
        }).tail.flatMap(function(o) return switch o {
            case Success(o): switch o {
                case Success(o): Promise.resolve(o);
                case Failure(err): Promise.reject(err);
            }
            case Failure(err): Promise.reject(err);
        });

        if (onEnd != null) {
            end.handle(function(_) { 
                js.Node.process.nextTick(onEnd);
            });
        }
    }

    public function read():Promise<Null<Chunk>> {
        return (cast new Future(function (cb) {
            function attempt() {
                try { 
                    switch (native.read( chunkSize )) {
                        case null:
                            native.once('readable', attempt);
                        
                        case chunk:
                            var buf:Buffer = 
                                if (Std.is(chunk, String))
                                    new Buffer((chunk:String))
                                else
                                    chunk;
                                
                        cb(Success((cast new BufferChunk(buf) : Chunk)));
                    }
                }
                catch (e : Dynamic) {
                    cb(Failure(new pm.Error.ValueError(e, 'Error while reading from $name')));
                }
            }
                        
            attempt();
            //end.handle(cb);
        }) : Promise<Null<Chunk>>)
        .first(end);
    }
}
