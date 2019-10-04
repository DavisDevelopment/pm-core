package pm.strings;

import haxe.io.Input;
import haxe.io.Output;
import haxe.io.BytesInput;
import haxe.io.BytesOutput;
import 

using pm.Strings;
using pm.Arrays;
using pm.Numbers;

class Format {
    public static function formatMoney(number:Float, decPlaces:Int, decSep:String='.', thouSep:String=','):String {
        decPlaces = isNaN(decPlaces = Math.abs(decPlaces)) ? 2 : decPlaces,
        decSep = typeof decSep === "undefined" ? "." : decSep;
        thouSep = typeof thouSep === "undefined" ? "," : thouSep;
        var sign = number < 0 ? "-" : "";
        var i = String(parseInt(number = Math.abs(Number(number) || 0).toFixed(decPlaces)));
        var j = (j = i.length) > 3 ? j % 3 : 0;

        return sign +
            (j ? i.substr(0, j) + thouSep : "") +
            i.substr(j).replace(/(\decSep{3})(?=\decSep)/g, "$1" + thouSep) +
            (decPlaces ? decSep + Math.abs(number - i).toFixed(decPlaces).slice(2) : "");
    }
}