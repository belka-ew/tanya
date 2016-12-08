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

import core.exception;
import std.algorithm.mutation;
public import std.experimental.allocator : make, makeArray, expandArray,
                                           stateSize, shrinkArray;
import std.traits;
public import tanya.memory.allocator;
public import tanya.memory.types;

private extern (C) void _d_monitordelete(Object h, bool det) @nogc;

shared Allocator allocator;

shared static this() nothrow @safe @nogc
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

	if (!allocator.reallocate(buf, length * T.sizeof))
	{
		return false;
	}
	// Casting from void[] is unsafe, but we know we cast to the original type
	array = () @trusted { return cast(T[]) buf; }();
	if (oldLength < length)
	{
		array[oldLength .. $].uninitializedFill(init);
	}
	return true;
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

private void deStruct(T)(ref T s)
	if (is(S == struct))
{
	static if (__traits(hasMember, T, "__xdtor")
	      &&   __traits(isSame, T, __traits(parent, s.__xdtor)))
	{
		s.__xdtor();
	}
	auto buf = (cast(ubyte*) &s)[0 .. T.sizeof];
	auto init = cast(ubyte[])typeid(T).initializer();
	if (init.ptr is null) // null ptr means initialize to 0s
	{
		buf[] = 0;
	}
	else
	{
		buf[] = init[];
	}
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
void dispose(T)(shared Allocator allocator, T* p)
{
    static if (hasElaborateDestructor!T)
    {
		deStruct(*p);
    }
    allocator.deallocate((cast(void*) p)[0 .. T.sizeof]);
}

/// Ditto.
void dispose(T)(shared Allocator allocator, T p)
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

	auto ppv = cast(void**) ptr;
	if (!*ppv)
	{
		return;
	}

	auto pc = cast(ClassInfo*) *ppv;
	try
	{
		auto c = *pc;
		do
		{
			if (c.destructor) // call destructor
			{
				(cast(void function (Object)) c.destructor)(cast(Object) ptr);
			}
		}
		while ((c = c.base) !is null);

		if (ppv[1]) // if monitor is not null
		{
			_d_monitordelete(cast(Object) ptr, true);
		}
		auto w = (*pc).initializer;
		ptr[0 .. w.length] = w[];
	}
	catch (Exception e)
	{
		onFinalizeError(*pc, e);
	}
	finally
	{
		*ppv = null;
	}
	allocator.deallocate(support);
}

/// Ditto.
void dispose(T)(shared Allocator allocator, T[] array)
{
    static if (hasElaborateDestructor!(typeof(array[0])))
    {
        foreach (ref e; array)
        {
            deStruct(e);
        }
    }
    allocator.deallocate(array);
}
