package pm.io;

import pm.io.StreamParser.ParseResult;
import haxe.ds.Option;
import haxe.io.*;
import pm.*;
import pm.async.*;
import pm.async.Stream;
import pm.async.Stream.Conclusion;

using pm.async.Async;
using pm.Strings;
using pm.Arrays;
using pm.Functions;
using pm.Numbers;

@:forward(reduce)
@:using(pm.io.Source.RealSourceTools)
abstract Source<E>(SourceObject<E>) from SourceObject<E> to SourceObject<E> {
    public static var EMPTY:Source<Dynamic> = Empty.make();
    
    @:to
    public inline function dirty():Source<Error> {
        return cast this;
    }

    public var depleted(get, never):Bool;
    inline function get_depleted() return this.depleted;

    @:to
    public function chunked():Stream<Chunk, E> {
        return this;
    }

    @:from
    public static inline function ofStream<E>(stream: Stream<Chunk, E>):Source<E> {
        return stream;
    }

    @:from
    public static inline function ofError(error: Error):RealSource {
        return cast Stream.ofError(error);
    }

    public static inline function exception<Err>(error: Err):Source<Err> {
        return ofStream(Stream.ofError(error));
    }

/*
    @:from
    public static inline function ofFuture<E1, E2>(future: Future<Source<E1>, E2>):Source<Dynamic> {
        return Stream.flatten((cast future : Promise<Source<Dynamic>>));
    }
*/

    @:from
    public static inline function ofPromise<E>(p: Promise<Source<E>>):Source<E> {
        return ofStream(Stream.flatten(Next.async(function(next) {
            p.then(
                function(src: Source<E>) {
                    next(src.realize());
                },
                function(err) {
                    next((exception(err)).realize());
                }
            );
        })));
    }

    static public function concatAll<E>(s: Stream<Chunk, E>) {
        return s.reduce(Chunk.EMPTY, function(res:Chunk, cur:Chunk) {
            return Progress(res.concat(cur));
        });
    }

    // public function pipeTo<EOut, Result>(target:SinkYielding<EOut, Result>, ?options):Future<PipeResult<E, EOut, Result>> { 
    //     return target.consume(this, options);
    // }

    public inline function append(that: Source<E>):Source<E> {
        return ofStream(this.append( that ));
    }

    public inline function prepend(that: Source<E>):Source<E> { 
        return ofStream(this.prepend( that ));
    }

    // public inline function transform<A>(transformer: Transformer<E, A>):Source<A> {
    //     return transformer.transform( this );
    // }

    public function skip(len: Int):Source<E> {
        return ofStream(this.regroup(function(chunks:Array<Chunk>) {
            var chunk = chunks[0];
            if(len <= 0) return Converted(Stream.single(chunk));
            var length = chunk.length;
            var out = Converted(if(len < length) Stream.single(chunk.slice(len, length)) else Empty.make());
            len -= length;
            return out;
        }));
    }

    public function limit(len: Int):Source<E> {
        if(len == 0) return cast Source.EMPTY;
        return ofStream(this.regroup(function(chunks:Array<Chunk>) {
            if (len <= 0)
                return Terminated(None);
            
            var chunk = chunks[0];
            var length = chunk.length;
            var out = 
            if (len == length)
                Terminated(Some(Stream.single(chunk)));
            else
                Converted(Stream.single(if(len < length) chunk.slice(0, len) else chunk));
            len -= length;
            return out;
        }));
    }

    public function split(delimiter: Chunk):SplitResult<Error> {
        var src:RealSource = realize();
        
        var s = RealSourceTools.pm(src, new pm.io.StreamParser.Splitter(delimiter));
        
        // TODO: make all these lazy
        return {
            before: 
                ofPromise(
                    s.map(
                        function(pair: Pair<Option<Chunk>, RealSource>) {
                            return switch pair.left {
                                case Some(chunk): 
                                    (chunk : RealSource);

                                case None: 
                                    realize();
                            }
                        }
                    )
                ),
            delimiter: s.flatMap(function(pair) {
                return switch pair.left {
                    case Some(_): Promise.resolve(delimiter);
                    case None: Promise.reject(new Error('NotFound', 'Delimiter not found'));
                }
            }),
            after: 
                ofPromise(
                    s.map(
                        function(pair: Pair<Option<Chunk>, RealSource>) {
                            return pair.right;
                        }
                    )
                )
        };
    }

    public function splitAll(delimiter: Chunk):RealSource {
        var src:RealSource = realize();
        // trace('$src');

        var res = (RealSourceTools.parseStream(src, new pm.io.StreamParser.Splitter(delimiter)).map(function(o: Option<Chunk>) {
            switch o {
                case Some(value):
                    return Chunk.ofBytes(value.toBytes());

                case None:
                    return Chunk.EMPTY;
            }
        }) : Source<Dynamic>);
        // trace(res);
        return res;
    }

    @:to
    public static inline function realize<E>(src: Source<E>):RealSource {
        return src.dirty();
    }

    @:to
    public inline function all():Promise<Chunk> {
        return RealSourceTools.all(cast this);
    }
    
    @:from
    public static function ofChunk<E>(chunk: Chunk):Source<E> {
        Assert.assert(chunk != null, 'null Chunk');
        //trace('==POOP==');
        var stream = new Single<Chunk, E>(chunk);
        var src:Source<E> = ofStream(stream);
        return src;
        //(new Single<Chunk, E>( chunk ));
    }
    
    @:from
    public static function ofString<E>(s: String):Source<E> {
        // return ((cast ofChunk(s) : Source<E>) : SourceObject<E>);
        return ofChunk(Chunk.ofString( s ));
    }
    
    @:from
    public static inline function ofBytes<E>(b:Bytes):Source<E> {
        return ((cast ofChunk(b) : Source<E>) : SourceObject<E>);
    }

#if (nodejs && !macro)
    @:noUsing 
    static public inline function ofNodeStream(name:String, readStream:js.node.stream.Readable.IReadable, ?options:{?chunkSize:Int, ?onEnd:Void->Void}):RealSource {
        if (options == null) 
            options = {};
        return pm.io.js.node.NodeSource.wrap(
            name,
            readStream,
            options.chunkSize,
            options.onEnd
        );
    }
    
    /**
      wrap/convert [this] `Source` instance to a Nodejs ReadStream
     **/
    public function toNodeStream():js.node.stream.Readable.IReadable {
        // https://github.com/HaxeFoundation/hxnodejs/pull/91
        var native = @:privateAccess new js.node.stream.PassThrough(); 
        
        var source:Stream<Chunk, Dynamic> = chunked();
        function write() {
            source.forEach(function(chunk: Chunk) {
                var ok = native.write(js.node.Buffer.hxFromBytes(chunk.toBytes()));
                return ok ? Resume : Finish;
            })
            .handle(function(o: Outcome<Conclusion<Chunk, Dynamic, Dynamic>, Dynamic>) {
                switch o {
                    case Success(conclusion):
                        switch conclusion {
                            case Conclusion.Depleted:
                                native.end(function() {
                                    write();
                                });
                            
                            case Conclusion.Halted(rest):
                                source = rest;
                                native.once(
                                    'drain', 
                                    cast write
                                );
                            
                            case Conclusion.Failed(e):
                                native.emit(
                                    'error', 
                                    new js.Error('$e')
                                );

                            case Clogged(error, at):
                                native.emit(
                                    'error', 
                                    new js.Error('$error')
                                );
                        }

                    case Failure(error):
                        native.emit(
                            'error',
                            new js.Error(Std.string(error))
                        );
                }
            });
        }
        
        write();
        
        return native;
    }

#end

/* === Operator Overloads === */

    @:op(A & B)
    public static inline function andThen<E>(a:Source<E>, b:Source<E>):Source<E> {
        return a.append( b );
    }

    @:op(A & B)
    // @:commutative
    public static inline function rcatChunk<E>(a:Source<E>, b:Chunk):Source<E> {
        return andThen(a, b);
    }

    @:op(A & B)
    public static inline function lcatChunk<E>(a:Chunk, b:Source<E>):Source<E> {
        return b.prepend( a );
    }
}

// @:structInit
typedef Op<InRes, InQ, OutRes, OutQ> = {
    function apply(input:Stream<InRes, InQ>):Stream<OutRes, OutQ>;
};

typedef Transform<InQuality, OutQuality> = {
    function transform(stream: Source<InQuality>):Source<OutQuality>;
};

@:notNull
abstract Operator<IR, IQ, OR, OQ> (Op<IR, IQ, OR, OQ>) from Op<IR, IQ, OR, OQ> {
    
    public inline function apply(input: Stream<IR, IQ>):Stream<OR, OQ> {
        return this.apply( input );
    }
}

@:structInit
class SplitResult<E> {
    public final before: Source<E>;
    public final delimiter: Promise<Chunk>;
    public final after: Source<E>;

    public inline function new(before, delimiter, after) {
        this.before = before;
        this.delimiter = delimiter;
        this.after = after;
    }
}

typedef SourceObject<E> = Stream<Chunk, E>;//StreamObject<Chunk, E>;

//@:using(pm.io.Source.RealSourceTools)
typedef RealSource = Source<Error>;

class RealSourceTools {
    public static inline function all(src: RealSource):Promise<Chunk> {
        return new Promise(function(accept, reject) {
            Source.concatAll(src).map(o -> switch o {
                case Reduced(c):
                    return Success(c);
                
                case Failed(e)|Crashed(e, _):
                    return Failure(e);
            }).then(
                function(o: Outcome<Chunk, Error>) {
                    switch o {
                        case Success(chunk):
                            accept(chunk);

                        case Failure(error):
                            reject(error);
                    }
                },
                reject
            );
        });
    }

    static public function pm<R>(s:RealSource, p:StreamParser<R>):Promise<Pair<R, RealSource>> {
        var prom:Promise<Pair<R, RealSource>> = (Future.ofOutcomePromise(StreamParser.pm(s, p).map(function(r: ParseResult<R, Error>) {
            return switch r {
                case Invalid(e, rest): Failure(e);
                case Broke(e): Failure(e);
                case Parsed(data, rest): Success(new Pair(data, rest));
            }
        })));
        return prom;
        /*
        return cast StreamParser.pm(s, p)
         .map(function (r) return switch r {
            case Parsed(data, rest): 
                Success(new Pair(data, rest));
            case Invalid(e, _) | Broke(e):
                Failure(e);
         });
        */
    }
    
    static public function parseStream<R>(s:RealSource, p:StreamParser<R>):RealStream<R> {
        return StreamParser.parseStream(s, p);
    }
}