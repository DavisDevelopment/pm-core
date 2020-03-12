package pm;

import haxe.PosInfos;
import haxe.ds.Option;

using pm.Iterators;
using pm.Functions;

@:listRepr
@:using(pm.ImmutableList.Il)
enum ListRepr<T> {
	Tl;
	Hd( v : T, tl : ListRepr<T> );
}

/**
	Immutable list
**/
@:forward
@:forwardStatics(Tl, Hd)
@:using(pm.ImmutableList.Il)
abstract ImmutableList<T>(ListRepr<T>) from ListRepr<T> to ListRepr<T> {
	@:op(a & b)
	static inline function prepend<T>(v:T, a:ImmutableList<T>):ImmutableList<T> {
		return Hd(v,a);
	}

	@:op(a == b)
	public function equals(other: ImmutableList<T>):Bool {
		return Type.enumEq(this, other);
	}

	// @:op(a & b)
	// inline public function append(value:T):ImmutableList
	// @:op(a&b)
	// static inline function append<T>(l:ImmutableList<T>, v:T):ImmutableList<T> return l.append([v]);
	@:op(a & b)
	public static inline function concat<T>(a:ImmutableList<T>, b:ImmutableList<T>):ImmutableList<T>
		return a.append(b);

	@:arrayAccess
	public inline function at(n: Int):T {
		return Il.nth(this, n);
	}

	public static inline function init<T>(size:Int, createItem:Int->T) {
		return inline Il.init(size, createItem);
	}

	public static inline function alloc<T>(size:Int, x:T) {
		return inline Il.make(size, x);
	}

	public function iterator():Iterator<T> {
		return new ILItr<T>( this );
	}

	public function reverse():ImmutableList<T> {
		return Il.rev(this);
	}

	public inline function join(sep: String):String {
		return Il.join(sep, this);
	}

	public function sort(fn:T -> T -> Int):ImmutableList<T> {
		return Il.sort(fn, this);
	}

	public function iter(f:T -> Void):Void {
		return Il.iter(f, this);
	}

	static function _flatten<T>(l:ImmutableList<ImmutableList<T>>) {
		var res:ImmutableList<T> = Tl;
		for (x in l) {
			res = res & x;
		}
		return res;
	}

	public inline function find(fn: T -> Bool):T return Il.find(fn, this);
	public inline function findMap<B>(f: T->Option<B>) return Il.find_map(f, this);
	public inline function filterMap<B>(f: T->Option<B>) return Il.filter_map(f, this);
	public inline function map<O>(f: T -> O):ImmutableList<O> return Il.map(f, this);
	public function flatMap<O>(f:T -> ImmutableList<O>):ImmutableList<O> {
		var res:ImmutableList<O> = Tl;
		for (x in iterator())
			res = ImmutableList.concat(res, f(x));
		return res;
	}
	public inline function reduceRight<Agg>(f:Agg->T->Agg, agg:Agg):Agg {
		return inline Il.fold_right(
			f.flipArguments(),
			this,
			agg
		);
	}

	public inline function reduce<Agg>(fn:Agg -> T -> Agg, agg:Agg):Agg {
		return inline Il.fold_left(fn, agg, this);
	}

	public function has(x:T, ?eq:T->T->Bool):Bool {
		return Il.exists(eq == null ? (item -> x == item) : (item -> eq(x, item)), this);
	}
	
	@:to 
	public inline function toArray():Array<T> {
		var a = [];
		var t = this;
		while( true ) {
			switch( t ) {
			case Tl: break;
			case Hd(v,tl): t = tl; a.push(v);
			}
		}
		return a;
	}

	@:from
	static inline function fromRepr<T>(l: ListRepr<T>):ImmutableList<T> {
		return (l : ImmutableList<T>);
	}

	@:from 
	public static inline function fromArray<T>(a: Array<T>):ImmutableList<T> {
		var l = Tl;
		var i = a.length - 1;
		while( i >= 0 )
			l = Hd(a[i--],l);
		return l;
	}

	@:from
	public static function fromIterator<T>(it: Iterator<T>):ImmutableList<T> {
		var l:ImmutableList<T> = Tl;
		while (it.hasNext())
			l = Hd(it.next(), l);
		return l.rev();
	}

	@:from
	static function fromIterable<T>(it: Iterable<T>):ImmutableList<T> return it.iterator();
		
	@:to
	public inline function toString():String {
		var a = toArray();
		return Std.string(a);
	}

	public var length(get, never):Int;
	private inline function get_length():Int return Il.length(this);
}

class ILItr<T> {
  var state: ImmutableList<T>;
  public inline function new(init) {
    state = init;
  }
  public inline function hasNext() return #if (eval||macro) false #else (state : ListRepr<T>).match(Hd(_, _)) #end;
  public function next():T {
    switch state {
      case Hd(v, next):
      	state = next;
      	return v;
	
      case Tl:
      	throw 'wut';
    }
	return null;
  }
}

class Il {
	public static function hd<T> (l:ImmutableList<T>, ?pos:PosInfos):T {
		return switch (l) {
			case Tl: throw new pm.Error("Il.hd", pos);
			case Hd(v, _): v;
		}
	}

	public static function append<T> (a : ImmutableList<T>, b : ImmutableList<T> ) : ImmutableList<T> {
		return switch (a) {
			case Tl: b;
			case Hd(v, tl):
				// ([v] : Array<T>) & append(tl, b);
				Hd(v, append(tl, b));
		}
	}

	public static function concat<T>(l:ImmutableList<ImmutableList<T>>) : ImmutableList<T> {
		return switch (l) {
			case Tl: Tl;
			case Hd(v, tl): append(v, concat(tl));
		}
	}

	public static function length<T> (l:ImmutableList<T>) : Int {
		return switch (l) {
			case Tl: 0;
			case Hd(_, tl): 1 + length(tl);
		}
	}

	public static function tl<T> (l:ImmutableList<T>) : ImmutableList<T> {
		return switch (l) {
			case Tl: throw new pm.Error("Il.tl");
			case Hd(_, tl): tl;
		}
	}

	public static function nth<T> (l:ImmutableList<T>, n:Int) : T {
		if (n < 0) { throw new pm.Error("Il.nth"); }
		var list = l;
		while (true) {
			switch (list) {
				case Hd(v, _) if (n == 0): return v;
				case Hd(_, tl): list = tl; n--;
				case Tl: throw new pm.Error("Il.nth");
			}
		}
	}

	public static inline function init<T> (length:Int, f:Int->T): ImmutableList<T> {
		if (length < 0) { throw new pm.Error("Il.init"); }
		var arr = [for (i in 0...length) f(i)];
		return arr;
	}

	public static function make<T> (count:Int, x:T) : ImmutableList<T> {
		return (count <= 0) ? Tl : Hd(x, make(count-1, x));
	}

	public static function join<T> (sep:String, l:ImmutableList<T>) : String {
		var buf = new StringBuf();
		function loop (l:ImmutableList<T>) {
		 	switch (l) {
				case Tl: return;
				case Hd(v, Tl):
					buf.add(v);
				case Hd(v, tl):
					buf.add(v);
					buf.add(sep);
					loop(tl);
			}
		}
		loop(l);
		return buf.toString();
	}

	public static function sort<T> (f:T->T->Int, l:ImmutableList<T>) : ImmutableList<T> {
		var _tmp:Array<T> = l;
		_tmp.sort(f);
		return _tmp;
	}

	public static function iter<T>(f:T->Void, l:ImmutableList<T>) {
		switch (l) {
			case Tl:
			case Hd(v, tl):
				f(v);
				iter(f, tl);
		}
	}

	public static function iter2<A,B> (f:A->B->Void, l1:ImmutableList<A>, l2:ImmutableList<B>) : Void {
		if (length(l1) != length(l2)) { throw new pm.Error("Il.iter2"); }
		switch [l1, l2] {
			case [Tl, Tl]:
			case [Hd(v1, tl1), Hd(v2, tl2)]:
				f(v1, v2);
				iter2(f, tl1, tl2);
			case _: throw new pm.Error("Il.iter2");
		}
	}

	public static function for_all<T> (f:T->Bool, l:ImmutableList<T>) : Bool {
		return switch (l) {
			case Tl: true;
			case Hd(v, tl): f(v) && for_all(f, tl);
		}
	}
	public static function for_all2<A,B> (f:A->B->Bool, l1:ImmutableList<A>, l2:ImmutableList<B>) : Bool {
		if (length(l1) != length(l2)) { throw new pm.Error("Il.forall2"); }
		return switch [l1, l2] {
			case [Tl, Tl]: true;
			case [Hd(v1, tl1), Hd(v2, tl2)]:
				if (f(v1, v2)) {
					for_all2(f, tl1, tl2);
				}
				else {
					false;
				}
			case _: throw new pm.Error("Il.forall2");
		}
	}

	public static inline function map<A, B> (fn:A -> B, l:ImmutableList<A>) : ImmutableList<B> {
		return switch (l) {
			case Tl: Tl;
			case Hd(v, tl):
				return Hd(fn(v), map(fn, tl));
		}
	}
	public static inline function mapi<A, B> (f:Int->A->B, l:ImmutableList<A>, ?index:Int=0) : ImmutableList<B> {
		return switch (l) {
			case Tl: Tl;
			case Hd(v, tl):
				return Hd(f(index, v), mapi(f, tl, index+1));
		}
	}

	public static function rev_map<A, B> (f:A->B, l:ImmutableList<A>) : ImmutableList<B> {
		var res = Tl;
		var curr = l;
		while (true) {
			switch (curr) {
				case Tl: break;
				case Hd(v, tl):
					curr = tl;
					res = Hd(f(v), res);
			}
		}
		return res;
	}

	public static function map2<A,B,C> (f:A->B->C, l1:ImmutableList<A>, l2:ImmutableList<B>) : ImmutableList<C> {
		if (length(l1) != length(l2)) { throw new pm.Error("Il.map2"); }
		return switch ({f:l1, s:l2}) {
			case {f:Tl, s:Tl}: Tl;
			case {f:Hd(v1, tl1), s:Hd(v2, tl2)}:
				Hd(f(v1, v2), map2(f, tl1, tl2));
			case _: throw new pm.Error("Il.map2");
		}
	}

	public static function filter<T> (f:T->Bool, l:ImmutableList<T>) : ImmutableList<T> {
		return switch (l) {
			case Tl: Tl;
			case Hd(v, tl):
				(f(v)) ? v & filter(f, tl) : filter(f, tl);
		}
	}

	public static function find_map<A,B> (f:A->Option<B>, l:ImmutableList<A>): B {
		return switch (l) {
			case Tl: throw notFound();
			case Hd(v, tl):
				switch (f(v)) {
					case None: find_map(f, tl);
					case Some(b): b;
				}
		}
	}
	public static function filter_map<A,B> (f:A->Option<B>, l:ImmutableList<A>): ImmutableList<B> {
		return switch (l) {
			case Tl: Tl;
			case Hd(v, tl):
				switch (f(v)) {
					case None: filter_map(f, tl);
					case Some(b): Hd(b, filter_map(f, tl));
				}
		}
	}

	public static function mem<T> (a:T, l:ImmutableList<T>) : Bool {
		return switch (l) {
			case Tl: false;
			case Hd(v, tl): a == v || mem(a, tl);
		}
	}

	// Same as Il.mem, but uses physical equality instead of structural equality to compare list elements.
	public static function memq<T> (a:T, l:ImmutableList<T>) : Bool {
		return switch (l) {
			case Tl: false;
			case Hd(v, tl): (a == v) || mem(a, tl);
		}
	}

	public static function fold_left<A, B>(f:A->B->A, a:A, l:ImmutableList<B>) : A {
		return switch (l) {
			case Tl: a;
			case Hd(v, tl):
				fold_left(f, f(a, v), tl);
		}
	}

	public static function fold_right<A, B>(f:A->B->B, l:ImmutableList<A>, b:B) : B {
		return switch (l) {
			case Tl: b;
			case Hd(v, tl):
				f(v, fold_right(f, tl, b));
		}
	}

	public static function fold_left2<A, B, C>(f:A->B->C->A, a:A, l1:ImmutableList<B>, l2:ImmutableList<C>) : A {
		if (length(l1) != length(l2)) { throw new pm.Error("Il.fold_left2"); }
		return switch [l1, l2] {
			case [Tl, Tl]: a;
			case [Hd(v1, tl1), Hd(v2, tl2)]:
				fold_left2(f, f(a, v1, v2), tl1, tl2);
			case _: throw new pm.Error("Il.fold_left2");
		}
	}

	public static function exists<T> (f:T->Bool, l:ImmutableList<T>) : Bool {
		return switch (l) {
			case Tl: false;
			case Hd(v, tl): f(v) || exists(f, tl);
		}
	}

	public static function find<T> (f:T->Bool, l:ImmutableList<T>) : T {
		return switch (l) {
			case Tl: throw notFound();
			case Hd(v, tl): f(v) ? v : find(f, tl);
		}
	}

	public static function assoc<A, B> (a:A, b:ImmutableList<{fst:A, snd:B}>) : B {
		return switch (b) {
			case Tl: throw notFound();
			case Hd(v, tl):
				(a == v.fst) ? v.snd : assoc(a, tl);
		}
	}

	public static function assq<A, B> (a:A, b:ImmutableList<{fst:A, snd:B}>) : B {
		return switch (b) {
			case Tl: throw notFound();
			case Hd(v, tl):
				(a == v.fst) ? v.snd : assq(a, tl);
		}
	}

	static function notFound(?what:Dynamic, ?pos:PosInfos) {
		return new pm.Error.ValueError(what, 'Not Found', pos);
	}

	/**
	 * creates reversed `ImmutableList` from `a`
	 * @param a 
	 * @return ImmutableList<T>
	 */
	public static function rev<T>(a: ImmutableList<T>):ImmutableList<T> {
		var res = Tl;
		var l = a;
		while (true) {
			switch (l) {
				case Tl:
					break;
				case Hd(v, tl):
					l = tl;
					res = Hd(v, res);
			}
		}
		return res;
	}
}