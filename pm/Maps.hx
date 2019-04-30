package pm;

import haxe.Constraints.IMap;
import pm.Pair;

using pm.Iterators;
using pm.Functions;

class Maps {
    @:generic
    public static function clone<K, V>(m: IMap<K, V>, ck:K->K, cv:V->V):IMap<K, V> {
        return [for (k=>v in m) ck(k)=>cv(v)];
    }

    @:generic
    public static function map<K1, V1, K2, V2>(m: IMap<K1, V1>, pred:Pair<K1, V1>->Pair<K2, V2>):IMap<K2, V2> {
        return [for (k=>v in m) {
            var p = pred(new Pair(k, v));
            p.left => p.right;
        }];
    }
}
