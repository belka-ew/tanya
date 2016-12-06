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

import std.algorithm.mutation;
public import std.experimental.allocator;
public import tanya.memory.allocator;
public import tanya.memory.types;

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
	array = cast(T[]) buf;
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
