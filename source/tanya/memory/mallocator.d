/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * Allocator based on $(D_PSYMBOL malloc), $(D_PSYMBOL realloc) and $(D_PSYMBOL free).
 *
 * Copyright: Eugene Wissner 2017-2018.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 * Source: $(LINK2 https://github.com/caraus-ecms/tanya/blob/master/source/tanya/memory/mallocator.d,
 *                 tanya/memory/mallocator.d)
 */
module tanya.memory.mallocator;

version (TanyaNative)
{
}
else:

import core.stdc.stdlib;
import tanya.memory.allocator;

/**
 * Wrapper for $(D_PSYMBOL malloc)/$(D_PSYMBOL realloc)/$(D_PSYMBOL free) from
 * the C standard library.
 */
final class Mallocator : Allocator
{
    private alias MallocType = extern (C) void* function(size_t)
                               @nogc nothrow pure @system;
    private alias FreeType = extern (C) void function(void*)
                             @nogc nothrow pure @system;
    private alias ReallocType = extern (C) void* function(void*, size_t)
                                @nogc nothrow pure @system;

    /**
     * Allocates $(D_PARAM size) bytes of memory.
     *
     * Params:
     *  size = Amount of memory to allocate.
     *
     * Returns: The pointer to the new allocated memory.
     */
    void[] allocate(size_t size) @nogc nothrow pure shared @system
    {
        if (size == 0)
        {
            return null;
        }
        auto p = (cast(MallocType) &malloc)(size + psize);

        return p is null ? null : p[psize .. psize + size];
    }

    ///
    @nogc nothrow pure @system unittest
    {
        auto p = Mallocator.instance.allocate(20);
        assert(p.length == 20);
        Mallocator.instance.deallocate(p);

        p = Mallocator.instance.allocate(0);
        assert(p.length == 0);
    }

    /**
     * Deallocates a memory block.
     *
     * Params:
     *  p = A pointer to the memory block to be freed.
     *
     * Returns: Whether the deallocation was successful.
     */
    bool deallocate(void[] p) @nogc nothrow pure shared @system
    {
        if (p !is null)
        {
            (cast(FreeType) &free)(p.ptr - psize);
        }
        return true;
    }

    ///
    @nogc nothrow pure @system unittest
    {
        void[] p;
        assert(Mallocator.instance.deallocate(p));

        p = Mallocator.instance.allocate(10);
        assert(Mallocator.instance.deallocate(p));
    }

    /**
     * Reallocating in place isn't supported.
     *
     * Params:
     *  p    = A pointer to the memory block.
     *  size = Size of the reallocated block.
     *
     * Returns: $(D_KEYWORD false).
     */
    bool reallocateInPlace(ref void[] p, size_t size)
    @nogc nothrow pure shared @system
    {
        cast(void) size;
        return false;
    }

    ///
    @nogc nothrow pure @system unittest
    {
        void[] p;
        assert(!Mallocator.instance.reallocateInPlace(p, 8));
    }

    /**
     * Increases or decreases the size of a memory block.
     *
     * Params:
     *  p    = A pointer to the memory block.
     *  size = Size of the reallocated block.
     *
     * Returns: Whether the reallocation was successful.
     */
    bool reallocate(ref void[] p, size_t size)
    @nogc nothrow pure shared @system
    {
        if (size == 0)
        {
            if (deallocate(p))
            {
                p = null;
                return true;
            }
        }
        else if (p is null)
        {
            p = allocate(size);
            return p is null ? false : true;
        }
        else
        {
            auto r = (cast(ReallocType) &realloc)(p.ptr - psize, size + psize);

            if (r !is null)
            {
                p = r[psize .. psize + size];
                return true;
            }
        }
        return false;
    }

    ///
    @nogc nothrow pure @system unittest
    {
        void[] p;

        assert(Mallocator.instance.reallocate(p, 20));
        assert(p.length == 20);

        assert(Mallocator.instance.reallocate(p, 30));
        assert(p.length == 30);

        assert(Mallocator.instance.reallocate(p, 10));
        assert(p.length == 10);

        assert(Mallocator.instance.reallocate(p, 0));
        assert(p is null);
    }

    // Fails with false
    @nogc nothrow pure @system unittest
    {
        void[] p = Mallocator.instance.allocate(20);
        void[] oldP = p;
        assert(!Mallocator.instance.reallocate(p, size_t.max - Mallocator.psize * 2));
        assert(oldP is p);
        Mallocator.instance.deallocate(p);
    }

    /**
     * Returns: The alignment offered.
     */
    @property uint alignment() const @nogc nothrow pure @safe shared
    {
        return (void*).alignof;
    }

    private nothrow @nogc unittest
    {
        assert(Mallocator.instance.alignment == (void*).alignof);
    }

    static private shared(Mallocator) instantiate() @nogc nothrow @system
    {
        if (instance_ is null)
        {
            const size = __traits(classInstanceSize, Mallocator) + psize;
            void* p = malloc(size);

            if (p !is null)
            {
                p[psize .. size] = typeid(Mallocator).initializer[];
                instance_ = cast(shared Mallocator) p[psize .. size].ptr;
            }
        }
        return instance_;
    }

    /**
     * Static allocator instance and initializer.
     *
     * Returns: The global $(D_PSYMBOL Allocator) instance.
     */
    static @property shared(Mallocator) instance() @nogc nothrow pure @system
    {
        return (cast(GetPureInstance!Mallocator) &instantiate)();
    }

    ///
    @nogc nothrow pure @system unittest
    {
        assert(instance is instance);
    }

    private enum ushort psize = 8;

    private shared static Mallocator instance_;
}
