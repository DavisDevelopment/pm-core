package pm.math.types;

import pm.Numbers;

abstract ClampedUInt8 (UInt) to UInt {
    // public static inline var Infinity:ClampedUInt8 = (Std.int(Math.POSITIVE_INFINITY) : UInt);

    @:from public static function ofUInt(i: UInt):ClampedUInt8 {
        pm.Assert.assert(Numbers.inRange((i : Int), 0, 255), haxe.io.Error.Overflow);
        return (cast i : ClampedUInt8);
        // return Ints.clamp(@:privateAccess i.toInt(), 0, 255);
    }

	@:op(A + B) private static inline function add(a:ClampedUInt8, b:ClampedUInt8):ClampedUInt8 {
		return a.toInt() + b.toInt();
	}

	@:op(A / B) private static inline function div(a:ClampedUInt8, b:ClampedUInt8):Float {
		return a.toFloat() / b.toFloat();
	}

	@:op(A * B) private static inline function mul(a:ClampedUInt8, b:ClampedUInt8):ClampedUInt8 {
		return a.toInt() * b.toInt();
	}

	@:op(A - B) private static inline function sub(a:ClampedUInt8, b:ClampedUInt8):ClampedUInt8 {
		return a.toInt() - b.toInt();
	}

	@:op(A > B) private static #if !js inline #end function gt(a:ClampedUInt8, b:ClampedUInt8):Bool {
		var aNeg = a.toInt() < 0;
		var bNeg = b.toInt() < 0;
		return
			if( aNeg != bNeg ) aNeg;
			else a.toInt() > b.toInt();
	}

	@:op(A >= B) private static #if !js inline #end function gte(a:ClampedUInt8, b:ClampedUInt8):Bool {
		var aNeg = a.toInt() < 0;
		var bNeg = b.toInt() < 0;
		return
			if( aNeg != bNeg ) aNeg;
			else a.toInt() >= b.toInt();
	}

	@:op(A < B) private static inline function lt(a:ClampedUInt8, b:ClampedUInt8):Bool {
		return gt(b, a);
	}

	@:op(A <= B) private static inline function lte(a:ClampedUInt8, b:ClampedUInt8):Bool {
		return gte(b, a);
	}

	@:op(A & B) private static inline function and(a:ClampedUInt8, b:ClampedUInt8):ClampedUInt8 {
		return a.toInt() & b.toInt();
	}

	@:op(A | B) private static inline function or(a:ClampedUInt8, b:ClampedUInt8):ClampedUInt8 {
		return a.toInt() | b.toInt();
	}

	@:op(A ^ B) private static inline function xor(a:ClampedUInt8, b:ClampedUInt8):ClampedUInt8 {
		return a.toInt() ^ b.toInt();
	}

	@:op(A << B) private static inline function shl(a:ClampedUInt8, b:Int):ClampedUInt8 {
		return a.toInt() << b;
	}

	@:op(A >> B) private static inline function shr(a:ClampedUInt8, b:Int):ClampedUInt8 {
		return a.toInt() >>> b;
	}

	@:op(A >>> B) private static inline function ushr(a:ClampedUInt8, b:Int):ClampedUInt8 {
		return a.toInt() >>> b;
	}

	@:op(A % B) private static inline function mod(a:ClampedUInt8, b:ClampedUInt8):ClampedUInt8 {
		return Std.int( a.toFloat() % b.toFloat() );
	}

	@:commutative @:op(A + B) private static inline function addWithFloat(a:ClampedUInt8, b:Float):Float {
		return a.toFloat() + b;
	}

	@:commutative @:op(A * B) private static inline function mulWithFloat(a:ClampedUInt8, b:Float):Float {
		return a.toFloat() * b;
	}

	@:op(A / B) private static inline function divFloat(a:ClampedUInt8, b:Float):Float {
		return a.toFloat() / b;
	}

	@:op(A / B) private static inline function floatDiv(a:Float, b:ClampedUInt8):Float {
		return a / b.toFloat();
	}

	@:op(A - B) private static inline function subFloat(a:ClampedUInt8, b:Float):Float {
		return a.toFloat() - b;
	}

	@:op(A - B) private static inline function floatSub(a:Float, b:ClampedUInt8):Float {
		return a - b.toFloat();
	}

	@:op(A > B) private static inline function gtFloat(a:ClampedUInt8, b:Float):Bool {
		return a.toFloat() > b;
	}

	@:commutative @:op(A == B) private static inline function equalsInt<T:Int>(a:ClampedUInt8, b:T):Bool {
		return a.toInt() == b;
	}

	@:commutative @:op(A != B) private static inline function notEqualsInt<T:Int>(a:ClampedUInt8, b:T):Bool {
		return a.toInt() != b;
	}

	@:commutative @:op(A == B) private static inline function equalsFloat<T:Float>(a:ClampedUInt8, b:T):Bool {
		return a.toFloat() == b;
	}

	@:commutative @:op(A != B) private static inline function notEqualsFloat<T:Float>(a:ClampedUInt8, b:T):Bool {
		return a.toFloat() != b;
	}

	@:op(A >= B) private static inline function gteFloat(a:ClampedUInt8, b:Float):Bool {
		return a.toFloat() >= b;
	}


	@:op(A > B) private static inline function floatGt(a:Float, b:ClampedUInt8):Bool {
		return a > b.toFloat();
	}

	@:op(A >= B) private static inline function floatGte(a:Float, b:ClampedUInt8):Bool {
		return a >= b.toFloat();
	}

	@:op(A < B) private static inline function ltFloat(a:ClampedUInt8, b:Float):Bool {
		return a.toFloat() < b;
	}

	@:op(A <= B) private static inline function lteFloat(a:ClampedUInt8, b:Float):Bool {
		return a.toFloat() <= b;
	}

	@:op(A < B) private static inline function floatLt(a:Float, b:ClampedUInt8):Bool {
		return a < b.toFloat();
	}

	@:op(A <= B) private static inline function floatLte(a:Float, b:ClampedUInt8):Bool {
		return a <= b.toFloat();
	}

	@:op(A % B) private static inline function modFloat(a:ClampedUInt8, b:Float):Float {
		return a.toFloat() % b;
	}

	@:op(A % B) private static inline function floatMod(a:Float, b:ClampedUInt8):Float {
		return a % b.toFloat();
	}

	@:op(~A) private inline function negBits():ClampedUInt8 {
		return ~this;
	}

	@:op(++A) private inline function prefixIncrement():ClampedUInt8 {
		return ++this;
	}

	@:op(A++) private inline function postfixIncrement():ClampedUInt8 {
		return this++;
	}

	@:op(--A) private inline function prefixDecrement():ClampedUInt8 {
		return --this;
	}

	@:op(A--) private inline function postfixDecrement():ClampedUInt8 {
		return this--;
	}

	// TODO: radix is just defined to deal with doc_gen issues
	private inline function toString(?radix:Int):String {
		return Std.string(toFloat());
	}

	private inline function toInt():Int {
		return this;
	}

    private inline function toClampedUInt8():ClampedUInt8 {
        return this;
    }

	@:to private #if (!js || analyzer) inline #end function toFloat():Float {
		var int = toInt();
		if (int < 0) {
			return 4294967296.0 + int;
		}
		else {
			// + 0.0 here to make sure we promote to Float on some platforms
			// In particular, PHP was having issues when comparing to Int in the == op.
			return int + 0.0;
		}
	}
}