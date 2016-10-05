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

import std.experimental.allocator;
import std.traits;

version (unittest)
{
    import tanya.memory : defaultAllocator;
}

/**
 * Allocator interface.
 */
interface Allocator
{
    /**
     * Allocates $(D_PARAM size) bytes of memory.
     *
     * Params:
     *     size = Amount of memory to allocate.
     *
     * Returns: The pointer to the new allocated memory.
     */
    void[] allocate(size_t size) shared;

    /**
     * Deallocates a memory block.
     *
     * Params:
     *     p = A pointer to the memory block to be freed.
     *
     * Returns: Whether the deallocation was successful.
     */
    bool deallocate(void[] p) shared;

    /**
     * Increases or decreases the size of a memory block.
     *
     * Params:
     *     p    = A pointer to the memory block.
     *     size = Size of the reallocated block.
     *
     * Returns: Whether the reallocation was successful.
     */
    bool reallocate(ref void[] p, size_t size) shared;

    /**
     * Returns: The alignment offered.
     */
    @property immutable(uint) alignment() shared const @safe pure nothrow;
}

/**
 * Params:
 *     T         = Element type of the array being created.
 *     allocator = The allocator used for getting memory.
 *     array     = A reference to the array being changed.
 *     length    = New array length.
 *
 * Returns: $(D_KEYWORD true) upon success, $(D_KEYWORD false) if memory could
 *          not be reallocated. In the latter
 */
bool resizeArray(T)(shared Allocator allocator,
                    ref T[] array,
                    in size_t length)
{
    void[] buf = array;

    if (!allocator.reallocate(buf, length * T.sizeof))
    {
        return false;
    }
    array = cast(T[]) buf;

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

enum bool isFinalizable(T) = is(T == class) || is(T == interface)
                           || hasElaborateDestructor!T || isDynamicArray!T;
