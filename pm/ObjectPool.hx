package pm;

import pm.Assert.assert;

using pm.Arrays;


/**
	A lightweight object pool
**/
#if generic
@:generic
#end
class ObjectPool<T> {
	/**
		The growth rate of the pool.
	**/
	public var growthRate:GrowthRate = GrowthRate.MILD;
	
	/**
		The current number of pooled objects.
	**/
	public var size(default, null):Int = 0;
	
	/**
		The maximum allowed number of pooled objects.
	**/
	public var maxSize(default, null):Int;
	
	private var mPool: Array<T>;
	private var mFactory: Void->T;
	private var mDispose: T->Void;
	private var mCapacity:Int = 16;
	
	public function new(factory:Void->T, ?dispose:T->Void, maxNumObjects:Int = -1) {
		mFactory = factory;
		mDispose = dispose == null ? function(x:T) {} : dispose;
		maxSize = maxNumObjects;
		mPool = Arrays.alloc( mCapacity );
	}
	
	/**
		Fills the pool in advance with `numObjects` objects.
	**/
	public function preallocate(numObjects:Int) {
		assert(size == 0);
		
		size = mCapacity = numObjects;
		mPool.nullify();
		mPool = Arrays.alloc( size );
		for (i in 0...numObjects) {
		    mPool[i](mFactory());
	}
	
	/**
		Destroys this object by explicitly nullifying all objects for GC'ing used resources.
		Improves GC efficiency/performance (optional).
	**/
	public function free() {
		for (i in 0...mCapacity) 
		    mDispose(mPool[i]);
		Arrays.nullify( mPool );
		mPool = null;
		mFactory = null;
		mDispose = null;
	}
	
	/**
		Gets an object from the pool; the method either creates a new object if the pool is empty (no object has been returned yet) or returns an existing object from the pool.
		To minimize object allocation, return objects back to the pool as soon as their life cycle ends.
	**/
	public inline function get():T {
		return size > 0 ? mPool[--size] : mFactory();
	}
	
	/**
		Puts `obj` into the pool, incrementing `this.size`.
		
		Discards `obj` if the pool is full by passing it to the dispose function (`this.size` == `this.maxSize`).
	**/
	public inline function put(obj: T) {
		if (size == maxSize) {
			mDispose( obj );
        }
		else {
			if (size == mCapacity) {
			    resize();
            }
			mPool[size++] = obj;
		}
	}
	
	public function iterator():Iterator<T> {
		var i = 0;
		var s = size;
		var d = mPool;
		return {
			hasNext: () -> i < s,
			next: () -> d[i++]
		};
	}
	
	function resize() {
		var newCapacity = growthRate.compute( mCapacity );
		var t = Arrays.alloc( newCapacity );
		mCapacity = newCapacity;
		mPool.blit(0, t, 0, size);
		mPool = t;
	}
}
