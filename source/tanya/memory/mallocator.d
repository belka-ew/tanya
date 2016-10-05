/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * Copyright: Eugene Wissner 2016.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 */  
module tanya.memory.mallocator;

import tanya.memory.allocator;
import core.exception;
import core.stdc.stdlib;
import std.algorithm.comparison;

/**
 * Wrapper for malloc/realloc/free from the C standard library.
 */
class Mallocator : Allocator
{
    /**
     * Allocates $(D_PARAM size) bytes of memory.
     *
     * Params:
     *     size = Amount of memory to allocate.
     *
     * Returns: The pointer to the new allocated memory.
     */
    void[] allocate(size_t size) shared @nogc nothrow
    {
        if (!size)
        {
            return null;
        }
        auto p = malloc(size + psize);

        if (!p)
        {
            onOutOfMemoryError();
        }
        return p[psize.. psize + size];
    }

    ///
    @nogc nothrow unittest
    {
        auto p = Mallocator.instance.allocate(20);

        assert(p.length == 20);

        Mallocator.instance.deallocate(p);
    }

    /**
     * Deallocates a memory block.
     *
     * Params:
     *     p = A pointer to the memory block to be freed.
     *
     * Returns: Whether the deallocation was successful.
     */
    bool deallocate(void[] p) shared @nogc nothrow
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
     * Increases or decreases the size of a memory block.
     *
     * Params:
     *     p    = A pointer to the memory block.
     *     size = Size of the reallocated block.
     *
     * Returns: Whether the reallocation was successful.
     */
    bool reallocate(ref void[] p, size_t size) shared @nogc nothrow
    {
        if (!size)
        {
            deallocate(p);
            p = null;
            return true;
        }
        else if (p is null)
        {
            p = allocate(size);
            return true;
        }
        auto r = realloc(p.ptr - psize, size + psize);

        if (!r)
        {
            onOutOfMemoryError();
        }
        p = r[psize.. psize + size];

        return true;
    }

    ///
    @nogc nothrow unittest
    {
        void[] p;

        Mallocator.instance.reallocate(p, 20);
        assert(p.length == 20);

        Mallocator.instance.reallocate(p, 30);
        assert(p.length == 30);

        Mallocator.instance.reallocate(p, 10);
        assert(p.length == 10);

        Mallocator.instance.reallocate(p, 0);
        assert(p is null);
    }

    /**
     * Returns: The alignment offered.
     */
    @property immutable(uint) alignment() shared const @safe pure nothrow
    {
        return cast(uint) max(double.alignof, real.alignof);
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
            immutable size = __traits(classInstanceSize, Mallocator) + psize;
            void* p = malloc(size);

            if (p is null)
            {
                onOutOfMemoryError();
            }
            p[psize..size] = typeid(Mallocator).initializer[];
            instance_ = cast(shared Mallocator) p[psize..size].ptr;
        }
        return instance_;
    }

    ///
    @nogc nothrow unittest
    {
        assert(instance is instance);
    }

    private enum psize = 8;

    private shared static Mallocator instance_;
}
