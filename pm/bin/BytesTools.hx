package pm.bin;

import haxe.io.Bytes as Bin;

class BytesTools {
    public static function concat(a:Bin, b:Bin):Bin {
        var sum = Bin.alloc(a.length + b.length);
        sum.blit(0, a, a.length, 0);
        sum.blit(a.length, b, b.length, 0);
        return sum;
    }
}
