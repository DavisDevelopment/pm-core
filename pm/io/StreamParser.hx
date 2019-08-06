package pm.io;

import haxe.io.Bytes;
import haxe.io.BytesBuffer;
import pm.*;
import pm.async.*;
import pm.async.Stream;

import pm.io.Chunk;
import pm.io.chunk.ChunkCursor;

import haxe.ds.Option;
import pm.Assert.assert;
import pm.Helpers.nor;
import pm.Helpers.matchFor;

using pm.async.Async;
using pm.Strings;
using pm.Arrays;
using pm.Functions;
using pm.Numbers;
using pm.Outcome;
using pm.Options;

enum ParseStep<Result> {
    Progressed;
    Done(result:Result, ?push:Chunk);
    Failed(error: Error);
}
enum ParseEnd<Result> {
    Yield(result:Result, rest:Chunk);
    Reject(e:Error, rest:Chunk);
    Raise(e: Error);
}

enum ParseResult<Result, Quality> {
    Parsed(data:Result, rest:Source<Quality>):ParseResult<Result, Quality>;
    Invalid(e:Error, rest:Source<Quality>):ParseResult<Result, Quality>;
    Broke(e: Error):ParseResult<Result, Quality>;
}

abstract StreamParser<Result>(StreamParserObject<Result>) from StreamParserObject<Result> to StreamParserObject<Result> {

    /**
      perform a Stream-Parse step
      @param source - the source Stream to read from
      @param p - the parser to use
      @param consume - callback which processes the parsed-out value (if any)
      @param finish - callback marking the end of the Source
      @returns result value of the pm
     /*
    static function doParse<R, Q, F>(source:Stream<Chunk, Q>, p:StreamParserObject<R>, consume:R -> Next<{resume:Bool}>, finish:Void -> F):Promise<ParseResult<F, Q>> {
        var cursor:ChunkCursor = Chunk.EMPTY.cursor();
        var resume:Bool = true;
        
        function mk(source: Source<Q>) {
            assert(source != null, new pm.io.IOError.NullError(source));
            //assert(cursor.right()!=null, 'null cursor.right');

            if (cursor.currentPos < cursor.length) {
                return source.prepend(cursor.right());
            }
            else {
                return source;
            }
        }
        
       function flush():Source<Q> {
            return switch cursor.flush() {
                //case null: cast Source.EMPTY;
                case c if (c.length == 0): (cast Source.EMPTY : Source<Q>);
                case c: c;
            }
        }

        function puke(e: Q):Error {
            return new pm.Error.ValueError(e);
        }
        return source.forEach(function (chunk: Chunk):Next<Handled<Error>> {
            // `continue` on empty chunks
            if (chunk.length == 0) 
                return Next.sync(Resume); // TODO: review this fix

            // plop [chunk] onto the end of the data
            cursor.shift( chunk );
            
            return Next.async(
                function(cb) {
                    function next() {
                        cursor.shift();
                        var lastPos = cursor.currentPos;
                        switch (p.progress(cursor)) {
                            case Progressed:
                                if (lastPos != cursor.currentPos && cursor.currentPos < cursor.length)
                                    next();
                                else
                                    cb(Resume);

                            case Done(v): 
                                consume(v).then(function (o) {
                                    resume = o.resume;
                                    if (resume) {
                                        if (lastPos != cursor.currentPos && cursor.currentPos < cursor.length) {
                                            next();
                                        }
                                        else {
                                            cb(Resume);
                                        }
                                    } else
                                    cb(Finish);
                                });
                                
                            case Failed(e): 
                                cb(Clog(e));
                        }
                    }
                    next();
                }
            );
        })
        .flatMap(function(c: Conclusion<Chunk, Error, Q>):Next<ParseResult<F, Q>> {
                // trace('$c');
                // trace(c.match(Halted(_)));
                function betty(r: ParseResult<F, Q>) {
                    trace('$r');
                    return r;
                }
                
                return switch c {
                    case Halted(rest):
                        trace(rest);
                        Next.sync(betty(Parsed(finish(), mk(rest))));

                    case Clogged(e, rest):
                        trace(rest);
                        Next.sync(betty(Invalid(e, mk(rest))));

                    case Failed(e):
                        Next.sync(betty(cast Broke(cast e)));

                    case Depleted if (cursor.currentPos < cursor.length): 
                        Next.sync(betty(Parsed(finish(), mk(Chunk.EMPTY))));

                    case Depleted if( !resume ):
                        Next.sync(betty(Parsed(finish(), flush())));

                    case Depleted:
                        switch p.eof(cursor) {
                            case Success(result):
                                consume(result).map(function (_) {
                                    return Parsed(finish(), flush());
                                });
                            
                            case Failure(e):
                                Next.sync(Invalid(e, flush()));
                        }     
                }
            });
    }
    */

    static public function _parse<R, Q, F>(src:Stream<Chunk, Q>, parser:StreamParserObject<R>, consume:(r:R)->Next<{resume:Bool}>, finish:Void->F):Promise<ParseResult<F, Error>> {
        var buffer:Chunk = Chunk.EMPTY;
        var resume:Bool = true;
        function echo(x:Dynamic)
            #if js
            untyped console.log( x );
            #else
            trace( x );
            #end
        function inspect(s: Source<Q>)
            s.all().then(echo, echo);
        
        function mk(s: Source<Q>):Source<Q> return if (buffer.length > 0) s.prepend(buffer) else s;
        
        function flush():Source<Q> return
            if (buffer == null || buffer.length == 0)
                (cast Source.EMPTY : Source<Q>);
            else Source.ofChunk(buffer);

        var walk = src.forEach(function(chunk: Chunk):Next<Handled<Error>> {
            if (chunk.length == 0)
                return Next.sync(Handled.Resume);

            var origChunk = chunk;
            chunk = buffer & chunk;

            return Next.async(function(done) {
                function next() {
                    switch (parser.pm( chunk )) {
                        case Progressed:
                            buffer = chunk;
                            return done(Resume);

                        case Failed(error):
                            return done(Handled.Clog(error));

                        case Done(result, push):
                            // return next(Handled.Finish);
                            buffer = push;
                            consume(result).handle(function(o:Outcome<{resume:Bool}, Dynamic>) {
                                switch o {
                                    case Success(o):
                                        resume = o.resume;
                                        if ( resume ) {
                                            if (buffer.length > 0) {
                                                next();
                                            }
                                            else {
                                                done(Resume);
                                            }
                                        }
                                        else {
                                            done(Finish);
                                        }

                                    case Failure(e):
                                        done(Clog(new pm.Error.ValueError(e)));
                                }
                            });
                    }
                }
                next();
            });
        });
        // walk.flat
        return walk.flatMap(cast (function(c: Conclusion<Chunk, Error, Q>):Next<ParseResult<F, Dynamic>> {
            switch c {
                case Halted(rest):
                    Source.ofStream(rest).all().then(echo, echo);
                    return Next.sync(Parsed(finish(), mk(cast Source.ofStream(rest))));

                case Clogged(error, at):
                    return Next.sync(Invalid(error, mk(cast at)));

                case Failed(e):
                    return Next.sync(Broke(new pm.Error.ValueError(e)));

                case Depleted if (buffer.length > 0):
                    return Next.sync(Parsed(finish(), mk(Chunk.EMPTY)));

                case Depleted if (!resume):
                    return Next.sync(Parsed(finish(), flush()));

                case Depleted:
                    switch (parser.tail(buffer)) {
                        case ParseEnd.Yield(result, rest):
                            return consume(result).map(function(_) {
                                return Parsed(finish(), flush());
                            });

                        case ParseEnd.Reject(e, at):
                            return Next.sync(Invalid(e, mk(at)));

                        case ParseEnd.Raise(e):
                            return Next.sync(Broke(e));
                    }
            }
        }));
    }

    static public function pm<R, Q>(src:Source<Q>, parser:StreamParser<R>):Next<ParseResult<R, Error>> {
        var res = null;
        function onResult(r) {
            res = r;
            trace(Std.string(res));

            return Next.sync({
                resume: false 
            });
        }

        assert(src != null, 'urinal');
        assert(parser != null, 'pisser');

        return _parse(src, parser, onResult, function () {
            return res;
        });
    }

    static public function parseStream<R, Q>(s:Source<Q>, p:StreamParser<R>):RealStream<R> {
        return Generator.stream(function next(step) {
            if ( s.depleted ) {
                step(End);
            }
            else {
                    pm(s, p).then(
                        function(o) {
                            switch o {
                                case Parsed(result, rest):
                                    s = cast rest;
                                    // trace(Std.string(result));
                                    step(Link(result, Generator.stream(next)));
                                
                                case Invalid(e, _) | Broke(e):
                                    step(cast Fail( e ));
                            }
                        },
                        function(error) {
                            step(cast Fail(error));
                        }
                    );
            }
        });
    }
}

/*
class Splitter implements StreamParserObject<Option<Chunk>> {
    var delim : Chunk;
    var buf : BytesBuffer;

    public function new(delim) {
        this.delim = delim;
    }

    public function progress(cursor: ChunkCursor):ParseStep<Option<Chunk>> {
        var seek = cursor.seek(this.delim);
        var consumed = cursor.hasNext();
        
        switch seek {
            case Some(chunk):
                var sub = cursor.flush();
                cursor.moveBy(chunk.length);
                cursor.prune();
                return ParseStep.Done(Some(sub));

            case None:
                return ParseStep.Progressed;
                if ( consumed ) {
                    return ParseStep.Done(Some(cursor.right()));
                }
                else {
                    return ParseStep.Progressed;
                }
        }
    }

    public function eof(cursor: ChunkCursor):Outcome<Option<Chunk>, Error> {
        return switch progress(cursor) {
            case Progressed: Failure(new pm.Error('NotFound'));
            case Failed(error): Failure(error);
            case Done(result): Success(result);
        }
    }
}

class OSplitter extends BytewiseParser<Option<Chunk>> {
    var delim:Chunk;
    // var buf = Chunk.EMPTY;
    var buf:BytesBuffer;
    
    public function new(delim) {
        this.delim = delim;
        this.buf = new BytesBuffer();
    }

    override function read(char: Int):ParseStep<Option<Chunk>> {
        if (char == -1) 
            return Done(None);
        
        //buf = Chunk.join([buf, String.fromCharCode(char)]);
        buf.addByte(char);
        return if (buf.length >= delim.length) {
            var b:Chunk = buf.getBytes();
            var bcursor = b.cursor();
            bcursor.moveBy(buf.length - delim.length);
            var dcursor = delim.cursor();
            
            for (i in 0...delim.length) {
                if (bcursor.currentByte != dcursor.currentByte) {
                    return Progressed;
                }
                else {
                    bcursor.next();
                    dcursor.next();
                }
            }

            var out = Done(Some(b.slice(0, bcursor.currentPos - delim.length)));
            trace(out);
            buf = new BytesBuffer();
            return out;
        }
        else {
            Progressed;
        }
    }
}

class SimpleBytewiseParser<Result> extends BytewiseParser<Result> {
    var _read:Int->ParseStep<Result>;
    public function new(f) {
        this._read = f;
    }
    override public function read(char: Int) {
        return _read(char);
    } 
}

class BytewiseParser<Result> implements StreamParserObject<Result> { 
    function read(char: Int):ParseStep<Result> {
        return throw 'abstract';
    }

    public function progress(cursor: ChunkCursor) {        
        do switch read(cursor.currentByte) {
            case Progressed:
            case Done(r): 
                cursor.next();
                return Done(r);
            case Failed(e):
                return Failed(e);
        }
        while (cursor.next());
        
        return Progressed;
    }

    public function eof(rest: ChunkCursor) {
        return switch read( -1) {
            case Progressed: Failure(cast(new pm.Error.ValueError(new haxe.io.Eof()), Error));
            case Done(r): Success(r);
            case Failed(e): Failure(e);
        }
    }
}
*/


/**
  [NOTE]
    ...
 **/
class Splitter implements StreamParserObject<Option<Chunk>> {
    var buffer: Chunk;
    var delim: Chunk;
    public function new(delim) {
        this.delim = delim;
        this.buffer = Chunk.EMPTY;
    }

    public function pm(chunk: Chunk):ParseStep<Option<Chunk>> {
        chunk = buffer & chunk;
        var cursor = chunk.cursor();
        var seek = cursor.seek( delim );
        switch seek {
            case Some(before):
                cursor.moveBy(delim.length);
                return Done(Some(before), cursor.right());

            case None:
                return Progressed;
        }
    }

    public function tail(rest: Chunk):ParseEnd<Option<Chunk>> {
        rest = buffer & rest;
        
        return switch pm(rest) {
            case Progressed: ParseEnd.Reject(new pm.Error('NotFound'), rest);
            case Done(res, rest): ParseEnd.Yield(res, rest);
            case Failed(error): ParseEnd.Raise(error);
        }
    }
}

interface StreamParserObject<Result> {
    // function progress(cursor: ChunkCursor):ParseStep<Result>;
    // function eof(rest: ChunkCursor):Outcome<Result, Error>;
    public function pm(chunk: Chunk):ParseStep<Result>;
    public function tail(rest: Chunk):ParseEnd<Result>;
}
