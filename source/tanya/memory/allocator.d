/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * Copyright: Eugene Wissner 2016.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 */
module tanya.memory.allocator;

import std.algorithm.mutation;
import std.experimental.allocator;
import std.typecons;

/**
 * Abstract class implementing a basic allocator.
 */
abstract class Allocator : IAllocator
{
    /**
     * Not supported.
     *
     * Returns: $(D_KEYWORD false).
     */
    bool deallocateAll() const @nogc @safe pure nothrow
    {
        return false;
    }

    /**
     * Not supported.
     *
     * Returns $(D_PSYMBOL Ternary.unknown).
     */
    Ternary empty() const @nogc @safe pure nothrow
    {
        return Ternary.unknown;
    }

    /**
     * Not supported.
     *
     * Params:
     *     b = Memory block.
     * 
     * Returns: $(D_PSYMBOL Ternary.unknown).
     */
    Ternary owns(void[] b) const @nogc @safe pure nothrow
    {
        return Ternary.unknown;
    }

    /**
     * Not supported.
     *
     * Params:
     *     p      = Pointer to a memory block.
     *     result = Full block allocated.
     *
     * Returns: $(D_PSYMBOL Ternary.unknown).
     */
    Ternary resolveInternalPointer(void* p, ref void[] result)
    const @nogc @safe pure nothrow
    {
        return Ternary.unknown;
    }

    /**
     * Params:
     *     size = Amount of memory to allocate.
     *
     * Returns: The good allocation size that guarantees zero internal
     *          fragmentation.
     */
    size_t goodAllocSize(size_t s)
    {
        auto rem = s % alignment;
        return rem ? s + alignment - rem : s;
    }

    /**
     * Not supported.
     * 
     * Returns: $(D_KEYWORD null).
     *
     */
    void[] allocateAll() const @nogc @safe pure nothrow
    {
        return null;
    }

    /**
     * Not supported.
     * 
     * Params:
     *     b = Block to be expanded.
     *     s = New size.
     *
     * Returns: $(D_KEYWORD false).
     */
    bool expand(ref void[] b, size_t s) const @nogc @safe pure nothrow
    {
        return false;
    }

    /**
     * Not supported.
     *
     * Params:
     *     n = Amount of memory to allocate.
     *     a = Alignment.
     *
     * Returns: $(D_KEYWORD null).
     */
    void[] alignedAllocate(size_t n, uint a) const @nogc @safe pure nothrow
    {
        return null;
    }

    /**
     * Not supported.
     *
     * Params:
     *     n = Amount of memory to allocate.
     *     a = Alignment.
     *
     * Returns: $(D_KEYWORD false).
     */
    bool alignedReallocate(ref void[] b, size_t size, uint alignment)
    const @nogc @safe pure nothrow
    {
        return false;
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
bool resizeArray(T)(IAllocator allocator,
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

    theAllocator.resizeArray(p, 20);
    assert(p.length == 20);

    theAllocator.resizeArray(p, 30);
    assert(p.length == 30);

    theAllocator.resizeArray(p, 10);
    assert(p.length == 10);

    theAllocator.resizeArray(p, 0);
    assert(p is null);
}

/**
 * Mixin to get around the impossibility to define a default constructor for
 * structs. It can be used for the structs that don't disable the default
 * constructor and don't wan't to force passing the allocator each time to
 * the constructor.
 *
 * It defines the private property `allocator`, a constructor that accepts only
 * an allocator instance and the method `checkAllocator` that checks if an
 * allocator is set and sets it to ` $(D_PSYMBOL theAllocator) if not.
 *
 * `checkAllocator` should be used at beginning of functions that
 * allocate/free memory.
 */
mixin template StructAllocator()
{
	private IAllocator allocator;

	this(IAllocator allocator) pure nothrow @safe @nogc
	in
	{
		assert(allocator !is null);
	}
	body
	{
		this.allocator = allocator;
	}

	pragma(inline, true)
	private void checkAllocator() nothrow @safe @nogc
	{
		if (allocator is null)
		{
			allocator = theAllocator;
		}
	}
}
