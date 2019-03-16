/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * Dynamic memory management.
 *
 * Copyright: Eugene Wissner 2016-2019.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 * Source: $(LINK2 https://github.com/caraus-ecms/tanya/blob/master/source/tanya/memory/package.d,
 *                 tanya/memory/package.d)
 */
module tanya.memory;

import tanya.conv;
public import tanya.memory.allocator;
public import tanya.memory.lifecycle;
import tanya.meta.trait;

/**
 * The mixin generates common methods for classes and structs using
 * allocators. It provides a protected member, constructor and a read-only property,
 * that checks if an allocator was already set and sets it to the default
 * one, if not (useful for structs which don't have a default constructor).
 */
mixin template DefaultAllocator()
{
    /// Allocator.
    protected shared Allocator allocator_;

    /**
     * Params:
     *  allocator = The allocator should be used.
     *
     * Precondition: $(D_INLINECODE allocator_ !is null)
     */
    this(shared Allocator allocator) @nogc nothrow pure @safe
    in
    {
        assert(allocator !is null);
    }
    do
    {
        this.allocator_ = allocator;
    }

    /**
     * This property checks if the allocator was set in the constructor
     * and sets it to the default one, if not.
     *
     * Returns: Used allocator.
     *
     * Postcondition: $(D_INLINECODE allocator !is null)
     */
    @property shared(Allocator) allocator() @nogc nothrow pure @safe
    out (allocator)
    {
        assert(allocator !is null);
    }
    do
    {
        if (allocator_ is null)
        {
            allocator_ = defaultAllocator;
        }
        return allocator_;
    }

    /// ditto
    @property shared(Allocator) allocator() const @nogc nothrow pure @trusted
    out (allocator)
    {
        assert(allocator !is null);
    }
    do
    {
        if (allocator_ is null)
        {
            return defaultAllocator;
        }
        return cast(shared Allocator) allocator_;
    }
}

shared Allocator allocator;

private shared(Allocator) getAllocatorInstance() @nogc nothrow
{
    if (allocator is null)
    {
        version (TanyaNative)
        {
            import tanya.memory.mmappool;
            defaultAllocator = MmapPool.instance;
        }
        else
        {
            import tanya.memory.mallocator;
            defaultAllocator = Mallocator.instance;
        }
    }
    return allocator;
}

/**
 * Returns: Default allocator.
 *
 * Postcondition: $(D_INLINECODE allocator !is null).
 */
@property shared(Allocator) defaultAllocator() @nogc nothrow pure @trusted
out (allocator)
{
    assert(allocator !is null);
}
do
{
    return (cast(GetPureInstance!Allocator) &getAllocatorInstance)();
}

/**
 * Sets the default allocator.
 *
 * Params:
 *  allocator = $(D_PSYMBOL Allocator) instance.
 *
 * Precondition: $(D_INLINECODE allocator !is null).
 */
@property void defaultAllocator(shared(Allocator) allocator) @nogc nothrow @safe
in
{
    assert(allocator !is null);
}
do
{
    .allocator = allocator;
}

/**
 * Returns the size in bytes of the state that needs to be allocated to hold an
 * object of type $(D_PARAM T).
 *
 * There is a difference between the `.sizeof`-property and
 * $(D_PSYMBOL stateSize) if $(D_PARAM T) is a class or an interface.
 * `T.sizeof` is constant on the given architecture then and is the same as
 * `size_t.sizeof` and `ptrdiff_t.sizeof`. This is because classes and
 * interfaces are reference types and `.sizeof` returns the size of the
 * reference which is the same as the size of a pointer. $(D_PSYMBOL stateSize)
 * returns the size of the instance itself.
 *
 * The size of a dynamic array is `size_t.sizeof * 2` since a dynamic array
 * stores its length and a data pointer. The size of the static arrays is
 * calculated differently since they are value types. It is the array length
 * multiplied by the element size.
 *
 * `stateSize!void` is `1` since $(D_KEYWORD void) is mostly used as a synonym
 * for $(D_KEYWORD byte)/$(D_KEYWORD ubyte) in `void*`.
 *
 * Params:
 *  T = Object type.
 *
 * Returns: Size of an instance of type $(D_PARAM T).
 */
template stateSize(T)
{
    static if (isPolymorphicType!T)
    {
        enum size_t stateSize = __traits(classInstanceSize, T);
    }
    else
    {
        enum size_t stateSize = T.sizeof;
    }
}

///
@nogc nothrow pure @safe unittest
{
    static assert(stateSize!int == 4);
    static assert(stateSize!bool == 1);
    static assert(stateSize!(int[]) == (size_t.sizeof * 2));
    static assert(stateSize!(short[3]) == 6);

    static struct Empty
    {
    }
    static assert(stateSize!Empty == 1);
    static assert(stateSize!void == 1);
}

/**
 * Params:
 *  size      = Raw size.
 *  alignment = Alignment.
 *
 * Returns: Aligned size.
 */
size_t alignedSize(const size_t size, const size_t alignment = 8)
pure nothrow @safe @nogc
{
    return (size - 1) / alignment * alignment + alignment;
}
