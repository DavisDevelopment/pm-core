package pm;

import haxe.io.Error as IOError;
import pm.Assert.assert;

#if cpp
import cpp.NativeArray;
#end

class Arrays {
/* === Non-Mixin Methods === */
    public static inline function alloc<T>(len: Int):Array<T> {
        var a: Array<T>;

        #if flash
            a = untyped __new__(Array, len);
            return a;
        #elseif js
            #if (haxe_ver >= 4.000)
                a = js.Syntax.construct(Array, len);
            #else
                a = untyped __new__(Array, len);
            #end
            return a;
        #elseif cpp
            return NativeArray.create( len );
        #elseif java
            return untyped Array.alloc(len);
        #elseif cs
            return cs.Lib.arrayAlloc(len);
        #else
            a = new Array<T>();
            a.resize( len );
            return a;
        #end
    }

    /**
      Copies `n` elements from `src`, beginning at `srcPos` to `dst`, beginning at `dstPos`.

      Copying takes place as if an intermediate buffer was used, allowing the destination and source to overlap.
     **/
    public static function blit<T>(src:Array<T>, srcPos:Int, dst:Array<T>, dstPos:Int, n:Int) {
        if (n > 0) {
            assert(srcPos < src.length, "srcPos out of range");
            assert(dstPos < dst.length, "dstPos out of range");
            //assert(srcPos + n <= src.length && dstPos + n <= dst.length, "n out of range");

            #if cpp

                cpp.NativeArray.blit(dst, dstPos, src, srcPos, n);

            #else

            if (src == dst) {
                if (srcPos < dstPos) {
                    var i = srcPos + n;
                    var j = dstPos + n;
                    for (k in 0...n) {
                        i--;
                        j--;
                        src[j] = src[i];
                    }
                }
                else if (srcPos > dstPos) {
                    var i = srcPos;
                    var j = dstPos;
                    for (k in 0...n) {
                        src[j] = src[i];
                        i++;
                        j++;
                    }
                }
            }
            else {
                if (srcPos == 0 && dstPos == 0) {
                    for (i in 0...n) 
                        dst[i] = src[i];
                }
                else
                    if (srcPos == 0) {
                        for (i in 0...n)
                            dst[dstPos + i] = src[i];
                    }
                    else
                        if (dstPos == 0) {
                            for (i in 0...n)
                                dst[i] = src[srcPos + i];
                        }
                        else {
                            for (i in 0...n)
                                dst[dstPos + i] = src[srcPos + i];
                        }
            }
            #end
        }
    }

    /**
      check whether `a` contains the value `x`
     **/
    public static inline function has<T>(a:Array<T>, x:T):Bool {
        #if (js && js_es >= 6)
        return untyped a.includes(x);
        #else
        return a.indexOf( x ) != -1;
        #end
    }

    public static function fill<T>(a:Array<T>, v:T) {
        #if js
        if (untyped js.Syntax.code('Array.prototype.fill'))
            untyped a.fill( v );
        return ;
        #end

        for (i in 0...a.length)
            a[i] = v;
        return ;
    }

    public static function nullify<T>(a: Array<T>) {
        fill(a, null);
    }

    /**
      TODO implement `append` using `blit`
     **/
    public static function append<T>(a:Array<T>, b:Array<T>) {
        for (x in b)
            a.push( x );
        //a.resize(a.length + b.length);
        //var i = a.length;
        //while ((i - a.length) <= b.length) {
            //a[i] = b[i - a.length];
            //++i;
        //}
        //for (i in 0...b.length) {
            //a[a.length + i] = b[i];
        //}
        //return a;
    }

    #if js inline #end
    public static function reduce<A, B>(arr:Array<A>, reducer:B -> A -> B, init:B):B {
        #if js
        untyped {
            return arr.reduce(reducer, init);
        }
        #else
        for (x in arr)
            init = reducer(init, x);
        return init;
        #end
    }

    #if js inline #end
    public static function reduceRight<A, B>(a:Array<A>, fn:B->A->B, agg:B):B {
        #if js
        return untyped a.reduceRight(fn, agg);
        #else
        var i = a.length;
        while (--i >= 0)
            agg = fn(agg, a[i]);
        return agg;
        #end
    }

    #if js inline #end
    public static function reduceInit<T>(a:Array<T>, fn:T->T->T):Null<T> {
        #if js
        return untyped a.reduce(fn);
        #else
        var agg = a.shift();
        if (agg == null) return null;
        else if (empty( a )) return agg;
        else return reduce(a, fn, agg);
        #end
    }

    #if js inline #end
    public static function forEach<T>(a:Array<T>, fn:T -> Void) {
        #if js
        untyped a.forEach( fn );
        #else
        for (x in a)
            fn( x );
        #end
    }
    
    #if js inline #end
    public static function every<T>(a:Array<T>, fn:T->Bool):Bool {
        #if js
            untyped {
                return a.every( fn );
            }
        #else
            for (x in a)
                if (!fn( x ))
                    return false;
            return true;
        #end
    }

    #if js inline #end
    public static function flatMap<I, O>(a:Array<I>, fn:I -> Array<O>):Array<O> {
        #if js 
            untyped {
                return a.flatMap( fn );
            }
        #else
            var o = [];
            for (x in a) {
                var chnk = fn( x );
                append(o, chnk);
            }
            return o;
        #end
    }

    public static function chunk<T>(array:Array<T>, size:Int):Array<Array<T>> {
        var chunks = [];//alloc(Math.floor((array.length + 0.0) / size));
        var zipr = array.slice( 0 ), i = 0;
        while (zipr.length > size)
            chunks.push(zipr.splice(0, size));
        if (zipr.length > 0)
            chunks.push(zipr);
        return chunks;

        /*
        for (pos in 0...chunks.length)
            chunks[pos] = alloc( size );
        var cc;
        for (i in 0...array.length) {
            var slotsUsed = 0;
            for (i2 in 0...array.length) {
                chunks[Math.floor((0.0 + array.length) / size)][Math.floor(array.length % size)] = array[i];
            }
        }
        return chunks;
        */
    }

/* === Platform-Generic Methods === */

    public static function empty<T>(a: Array<T>):Bool {
        return a == null || a.length == 0;
    }

    public static function nullEmpty<T>(a: Array<T>):Null<Array<T>> {
        return empty( a ) ? null : a;
    }

    public static function before<T>(a:Array<T>, v:T, safety=true, forced=true):Array<T> {
        if (safety && a == null)
            throw new pm.Error('pm.Arrays.before\'s "a" argument must be nonnull');
        var idxv = a.indexOf( v );
        if (idxv == -1) {
            if ( forced ) {
                return a.copy();
            }
            throw IOError.Custom(new Error('NotFound'));
        }

        return a.slice(0, idxv);
    }

    public static function after<T>(a:Array<T>, v:T, safety=true, forced=true):Array<T> {
        if (safety && a == null)
            throw new pm.Error('pm.Arrays.before\'s "a" argument must be nonnull');
        var idxv = a.indexOf( v );
        if (idxv == -1) {
            if ( forced ) {
                return a.copy();
            }
            throw IOError.Custom(new Error('NotFound'));
        }

        return a.slice(idxv + 1);
    }

    public static function mapi<T, TOut>(a:Array<T>, f:T -> Int -> TOut):Array<TOut> {
        var out:Array<TOut> = alloc( a.length );
        for (i in 0...a.length) {
            out[i] = f(a[i], i);
        }
        return out;
    }

    public static function isort<T>(a:Array<T>, f:T->T->Int):Array<T> {
        haxe.ds.ArraySort.sort(a, f);
        return a;
    }

    public static function mapreduce<A, B, Agg>(array:Array<A>, mapFn:A -> B, reduceFn:Agg -> B -> Agg, init:Agg, right:Bool=false):Agg {
        var red = right ? reduceRight : reduce;
        return red(array.map(mapFn), reduceFn, init);
    }

    public static function mapfilter<T, TOut>(a:Array<T>, test:T->Bool, map:T->TOut):Array<TOut> {
        return reduce(a, function(out:Array<TOut>, item) {
            if (test(item))
                out.push(map(item));
            return out;
        }, new Array<TOut>());
    }

    public static function sorted<T>(a:Array<T>, f:T->T->Int):Array<T> {
        return isort(a.copy(), f);
    }

    public static function find<T>(a:Array<T>, fn:T -> Bool):Null<T> {
        for (x in a)
            if (fn( x ))
                return x;
        return null;
    }

    public static function take<T>(a:Array<T>, n:Int):Array<T> {
        return a.slice(0, n);
    }

    public static function takeLast<T>(a:Array<T>, n:Int):Array<T> {
        return a.slice(a.length - n);
    }

    public static function withAppend<T>(a:Array<T>, v:T):Array<T> {
        return a.concat([v]);
    }

    public static function withPrepend<T>(a:Array<T>, v:T):Array<T> {
        return [v].concat( a  );
    }

    public static function zip<A, B, C>(a:Array<A>, b:Array<B>, fn:A -> B -> C):Array<C> {
        if (a.length == b.length) {
            return [for (i in 0...a.length) fn(a[i], b[i])];
        }
        throw new Error('invalid');
    }
}

class Array2s {
    public static function rotate<T>(a : Array<Array<T>>) : Array<Array<T>> {
        var result:Array<Array<T>> = Arrays.alloc( a.length );
        for (i in 0...a[0].length) {
            var row:Array<T> = Arrays.alloc( a.length );
            result[i] = row;

            for (j in 0...a.length) {
                row[j] = a[j][i];
            }
        }
        return result;
    }

    public static function get<T>(a:Array<Array<T>>, x:Int, y:Int, safety=true):Null<T> {
        if (x >= 0 && x < a.length)
            if (a[x] != null && y >= 0 && y < a[x].length)
                return a[x][y];
        if ( safety )
            throw IOError.OutsideBounds;
        return null;
    }

    public static function flatten<T>(a: Array<Array<T>>):Array<T> {
        var res = [];
        for (x in a)
            res = res.concat( x );
        return res;
    }
}

class Array3s {
    public static inline function flatten<T>(a: Array<Array<Array<T>>>):Array<T> {
        return Array2s.flatten(Array2s.flatten( a ));
    }

    public static function get<T>(a:Array<Array<Array<T>>>, x:Int, y:Int, z:Int, safety=true):Null<T> {
        if (x >= 0 && x < a.length)
            if (a[x] != null && y >= 0 && y < a[x].length)
                if (a[x][y] != null && z >= 0 && z < a[x][y].length)
                    return a[x][y][z];
        if ( safety )
            throw IOError.OutsideBounds;
        return null;
    }
}
