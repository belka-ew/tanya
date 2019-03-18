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
 * Source: $(LINK2 https://github.com/caraus-ecms/tanya/blob/master/middle/tanya/memory/package.d,
 *                 tanya/memory/package.d)
 */
module tanya.memory;

public import tanya.memory.allocator;
public import tanya.memory.lifetime;
import tanya.meta.trait;
deprecated("Use tanya.meta.trait.stateSize instead")
public import tanya.meta.trait : stateSize;

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
    in (allocator !is null)
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
    out (allocator; allocator !is null)
    {
        if (allocator_ is null)
        {
            allocator_ = defaultAllocator;
        }
        return allocator_;
    }

    /// ditto
    @property shared(Allocator) allocator() const @nogc nothrow pure @trusted
    out (allocator; allocator !is null)
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
out (allocator; allocator !is null)
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
in (allocator !is null)
{
    .allocator = allocator;
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
