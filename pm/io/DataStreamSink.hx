package pm.io;

import haxe.macro.Expr.ExprOf;
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

class DataStreamSink {
    public var stream(default, null): DataStream;
    public function new(stream) {
        this.stream = stream;
        this.dataEvent = new Signal();
        this.closeEvent = new Signal();
        var ob = this.stream.observe();
        ob.onClose.once(function() {
            events.push(EClosed);
        });
        ob.onData.on(function(chunk: Chunk) {
            events.push(EChunk(chunk));
        });
        register( this );
    }

    function _loop() {
        if (!events.empty()) {
            for (event in events) {
                sig.broadcast(event);
            }
        }
    }

/* === Fields === */

    public var sig(default, null): Signal<SinkEvent>;
    // public var closeEvent(default, null): Signal<Dynamic>;
    var events : Array<SinkEvent>;

/* === Statics === */

    static var instances: Array<DataStreamSink> = new Array();
    static var loopStarted:Bool = false;
    static function loop() {
        var start = !loopStarted;
        if (!loopStarted) {
            loopStarted = true;
        }

        if (!start) {
            for (sink in instances) {
                sink._loop();
            }
        }

        Callback.defer( loop );
    }

    static function register(i: DataStreamSink) {
        instances.push( i );
        loop();
    }
}

enum SinkEvent {
    EChunk(chunk: Chunk);
    EConsumed;
    EClosed;
    EEnded;
}