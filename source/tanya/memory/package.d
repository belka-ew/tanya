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

public import std.experimental.allocator : make, makeArray;
import std.traits;
public import tanya.memory.allocator;
public import tanya.memory.types;

// From druntime
private extern (C) void _d_monitordelete(Object h, bool det) nothrow @nogc;

shared Allocator allocator;

shared static this() nothrow @trusted @nogc
{
	import tanya.memory.mmappool;
	allocator = MmapPool.instance;
}

@property ref shared(Allocator) defaultAllocator() nothrow @safe @nogc
{
	return allocator;
}

@property void defaultAllocator(shared(Allocator) allocator) nothrow @safe @nogc
{
	.allocator = allocator;
}

/**
 * Returns the size in bytes of the state that needs to be allocated to hold an
 * object of type $(D_PARAM T).
 *
 * Params:
 * 	T = Object type.
 */
template stateSize(T)
{
	static if (is(T == class) || is(T == interface))
	{
		enum stateSize = __traits(classInstanceSize, T);
	}
	else
	{
		enum stateSize = T.sizeof;
	}
}

/**
 * Params:
 * 	T         = Element type of the array being created.
 * 	allocator = The allocator used for getting memory.
 * 	array     = A reference to the array being changed.
 * 	length    = New array length.
 * 	init      = The value to fill the new part of the array with if it becomes
 * 	            larger.
 *
 * Returns: $(D_KEYWORD true) upon success, $(D_KEYWORD false) if memory could
 *          not be reallocated. In the latter
 */
bool resizeArray(T)(shared Allocator allocator,
                    ref T[] array,
                    in size_t length,
                    T init = T.init)
{
	void[] buf = array;
	immutable oldLength = array.length;

	auto result = () @trusted {
		if (!allocator.reallocate(buf, length * T.sizeof))
		{
			return false;
		}
		// Casting from void[] is unsafe, but we know we cast to the original type.
		array = cast(T[]) buf;
		return true;
	}();
	if (result && oldLength < length)
	{
		array[oldLength .. $] = init;
	}
	return result;
}

///
unittest
{
	int[] p;

	defaultAllocator.resizeArray(p, 20);
	assert(p.length == 20);

	defaultAllocator.resizeArray(p, 30);
	assert(p.length == 30);

	defaultAllocator.resizeArray(p, 10);
	assert(p.length == 10);

	defaultAllocator.resizeArray(p, 0);
	assert(p is null);
}

/**
 * Destroys and deallocates $(D_PARAM p) of type $(D_PARAM T).
 * It is assumed the respective entities had been allocated with the same
 * allocator.
 *
 * Params:
 * 	T         = Type of $(D_PARAM p).
 * 	allocator = Allocator the $(D_PARAM p) was allocated with.
 * 	p         = Object or array to be destroyed.
 */
void dispose(T)(shared Allocator allocator, auto ref T* p)
{
	static if (hasElaborateDestructor!T)
	{
		destroy(*p);
	}
	() @trusted { allocator.deallocate((cast(void*) p)[0 .. T.sizeof]); }();
	p = null;
}

/// Ditto.
void dispose(T)(shared Allocator allocator, auto ref T p)
	if (is(T == class) || is(T == interface))
{
	if (p is null)
	{
		return;
	}
	static if (is(T == interface))
	{
		version(Windows)
		{
			import core.sys.windows.unknwn : IUnknown;
			static assert(!is(T: IUnknown), "COM interfaces can't be destroyed in "
										 ~ __PRETTY_FUNCTION__);
		}
		auto ob = cast(Object) p;
	}
	else
	{
		alias ob = p;
	}
	auto ptr = cast(void *) ob;

	auto support = ptr[0 .. typeid(ob).initializer.length];
	scope (success)
	{
		() @trusted { allocator.deallocate(support); }();
		p = null;
	}

	auto ppv = cast(void**) ptr;
	if (!*ppv)
	{
		return;
	}
	auto pc = cast(ClassInfo*) *ppv;
	scope (exit)
	{
		*ppv = null;
	}

	auto c = *pc;
	do
	{
		// Assume the destructor is @nogc. Leave it nothrow since the destructor
		// shouldn't throw and if it does, it is an error anyway.
		if (c.destructor)
		{
			(cast(void function (Object) nothrow @safe @nogc) c.destructor)(ob);
		}
	}
	while ((c = c.base) !is null);

	if (ppv[1]) // if monitor is not null
	{
		_d_monitordelete(cast(Object) ptr, true);
	}
}

/// Ditto.
void dispose(T)(shared Allocator allocator, auto ref T[] array)
{
	static if (hasElaborateDestructor!(typeof(array[0])))
	{
	foreach (ref e; array)
	{
	    destroy(e);
	}
	}
	() @trusted { allocator.deallocate(array); }();
	array = null;
}
