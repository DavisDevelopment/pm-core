package pm.math.bigint;

using pm.Strings;

class Decimals {
  public static var divisionExtraScale = 4;

  public static inline function fromInt(value : Int) : DecimalImpl {
    return new DecimalImpl(Bigs.fromInt(value), 0);
  }

  // TODO needs better implementation
  public static function fromFloat(value : Float) : DecimalImpl {
    if(!Math.isFinite(value))
      throw 'Value is not a finite Float: $value';
    return parse('$value');
  }

  public static function parse(value : String) : DecimalImpl {
    value = value.toLowerCase();
    var pose = value.indexOf("e");
    if (pose > 0) {
      var isNeg = false,
          f = value.substring(0, pose),
          e = value.substring(pose + 1);
      if (e.substring(0, 1) == "-") {
        isNeg = true;
        e = e.substring(1);
      }
      var p = Bigs.parseBase(e, 10),
          m = Small.ten.pow(p);
      if ( isNeg ) {
        return parse(f).divideWithScale(pm.Decimal.fromBigInt( m ), Std.parseInt( e ));
      }
      else {
        return parse( f ).multiply(pm.Decimal.fromBigInt( m ));
      }
    }

    var pdec:Int = value.indexOf(".");
    if (pdec < 0) {
      return new DecimalImpl(BigInt.fromString( value ), 0);
    }

    var i = value.substring(0, pdec) + value.substring(pdec + 1);
    return new DecimalImpl(Bigs.parseBase(i, 10), value.length - pdec - 1);
  }
}
