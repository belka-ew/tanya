/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * Copyright: Eugene Wissner 2017.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 */
module tanya.memory.mallocator;

import core.stdc.stdlib;
import tanya.memory.allocator;

/**
 * Wrapper for malloc/realloc/free from the C standard library.
 */
final class Mallocator : Allocator
{
    /**
     * Allocates $(D_PARAM size) bytes of memory.
     *
     * Params:
     *  size = Amount of memory to allocate.
     *
     * Returns: The pointer to the new allocated memory.
     */
    void[] allocate(const size_t size) shared nothrow @nogc
    {
        if (size == 0)
        {
            return null;
        }
        auto p = malloc(size + psize);

        return p is null ? null : p[psize .. psize + size];
    }

    ///
    @nogc nothrow unittest
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
    bool deallocate(void[] p) shared nothrow @nogc
    {
        if (p !is null)
        {
            free(p.ptr - psize);
        }
        return true;
    }

    ///
    @nogc nothrow unittest
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
    bool reallocateInPlace(ref void[] p, const size_t size) shared nothrow @nogc
    {
        return false;
    }

    ///
    @nogc nothrow unittest
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
    bool reallocate(ref void[] p, const size_t size) shared nothrow @nogc
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
            auto r = realloc(p.ptr - psize, size + psize);

            if (r !is null)
            {
                p = r[psize .. psize + size];
                return true;
            }
        }
        return false;
    }

    ///
    @nogc nothrow unittest
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

    // Fails with false.
    private @nogc nothrow unittest
    {
        void[] p;
        assert(!Mallocator.instance.reallocate(p, size_t.max - Mallocator.psize * 2));
    }

    /**
     * Returns: The alignment offered.
     */
    @property uint alignment() shared const pure nothrow @safe @nogc
    {
        return (void*).alignof;
    }

    private nothrow @nogc unittest
    {
        assert(Mallocator.instance.alignment == (void*).alignof);
    }

    /**
     * Static allocator instance and initializer.
     *
     * Returns: The global $(D_PSYMBOL Allocator) instance.
     */
    static @property ref shared(Mallocator) instance() @nogc nothrow
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

    ///
    @nogc nothrow unittest
    {
        assert(instance is instance);
    }

    private enum ushort psize = 8;

    private shared static Mallocator instance_;
}
