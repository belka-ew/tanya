/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * Copyright: Eugene Wissner 2016.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 */  
module tanya.memory;

public import tanya.memory.allocator;
public import std.experimental.allocator : make, makeArray, expandArray, shrinkArray, IAllocator;
import core.atomic;
import core.stdc.stdlib;
import std.traits;

version (Windows)
{
	import core.sys.windows.windows;
}
else version (Posix)
{
	public import tanya.memory.mmappool;
	import core.sys.posix.pthread;
}

version (Windows)
{
	package alias Mutex = CRITICAL_SECTION;
	package alias destroyMutex = DeleteCriticalSection;
}
else version (Posix)
{
	package alias Mutex = pthread_mutex_t;
    package void destroyMutex(pthread_mutex_t* mtx)
    {
        pthread_mutex_destroy(mtx) && assert(0);
	}
}

@property void defaultAllocator(shared Allocator allocator) @safe nothrow
{
	_defaultAllocator = allocator;
}

@property shared(Allocator) defaultAllocator() @safe nothrow
{
	return _defaultAllocator;
}

static this() @safe nothrow
{
	defaultAllocator = MmapPool.instance;
}

package struct Monitor
{
	Object.Monitor impl; // for user-level monitors
	void delegate(Object) @nogc[] devt; // for internal monitors
	size_t refs; // reference count
	version (Posix)
	{
		Mutex mtx;
	}
}

package @property ref shared(Monitor*) monitor(Object h) pure nothrow
{
    return *cast(shared Monitor**)&h.__monitor;
}

/**
 * Destroys and then deallocates (using $(D_PARAM allocator)) the class
 * object referred to by a $(D_KEYWORD class) or $(D_KEYWORD interface)
 * reference. It is assumed the respective entities had been allocated with
 * the same allocator.
 *
 * Params:
 * 	A         = The type of the allocator used for the ojbect allocation.
 * 	T         = The type of the object that should be destroyed.
 * 	allocator = The allocator used for the object allocation.
 * 	p         = The object should be destroyed.
 */
void finalize(A, T)(auto ref A allocator, ref T p)
	if (is(T == class) || is(T == interface))
{
	static if (is(T == interface))
	{
		auto ob = cast(Object) p;
	}
	else
	{
		alias ob = p;
	}
	auto pp = cast(void*) ob;
	auto ppv = cast(void**) pp;
	if (!pp || !*ppv)
	{
		return;
	}
	auto support = (cast(void*) ob)[0 .. typeid(ob).initializer.length];
	auto pc = cast(ClassInfo*) *ppv;
	auto c = *pc;
	do
	{
		if (c.destructor)
		{
			(cast(void function(Object)) c.destructor)(ob);
		}
	} while ((c = c.base) !is null);

	// Take care of monitors for synchronized blocks
	if (ppv[1])
	{
		shared(Monitor)* m = atomicLoad!(MemoryOrder.acq)(ob.monitor);
		if (m !is null)
		{
			auto mc = cast(Monitor*) m;
			if (!atomicOp!("-=")(m.refs, cast(size_t) 1))
			{
				foreach (v; mc.devt)
				{
					if (v)
					{
						v(ob);
					}
				}
				if (mc.devt.ptr)
				{
					free(mc.devt.ptr);
				}
				destroyMutex(&mc.mtx);
				free(mc);
				atomicStore!(MemoryOrder.rel)(ob.monitor, null);
			}
		}
	}
	*ppv = null;

	allocator.deallocate(support);
	p = null;
}

/// Ditto.
void finalize(A, T)(auto ref A allocator, ref T *p)
	if (is(T == struct))
{
    if (p is null)
	{
		return;
	}
	static if (hasElaborateDestructor!T)
	{
		*p.__xdtor();
	}
	allocator.deallocate((cast(void*)p)[0 .. T.sizeof]);
	p = null;
}

/// Ditto.
void finalize(A, T)(auto ref A allocator, ref T[] p)
{
	static if (hasElaborateDestructor!T)
	{
		foreach (ref e; p)
		{
			finalize(allocator, e);
		}
	}
	allocator.deallocate(p);
	p = null;
}

bool resizeArray(T, A)(auto ref A allocator, ref T[] array, in size_t length)
@trusted
{
	if (length == array.length)
	{
		return true;
	}
	if (array is null && length > 0)
	{
		array = makeArray!T(allocator, length);
		return array !is null;
	}
	if (length == 0)
	{
		finalize(allocator, array);
		return true;
	}
	void[] buf = array;
	if (!allocator.reallocate(buf, length * T.sizeof))
	{
		return false;
	}
	array = cast(T[]) buf;
	return true;
}

enum bool isFinalizable(T) = is(T == class) || is(T == interface)
                          || hasElaborateDestructor!T || isDynamicArray!T;

private shared Allocator _defaultAllocator;
