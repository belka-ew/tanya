/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * Copyright: Eugene Wissner 2016-2017.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 */
module tanya.memory.mmappool;

import core.stdc.string;
import std.algorithm.comparison;
import tanya.memory.allocator;

version (Posix)
{
    import core.stdc.errno;
    import core.sys.posix.sys.mman;
    import core.sys.posix.unistd;
}
else version (Windows)
{
    import core.sys.windows.winbase;
    import core.sys.windows.windows;
}

/**
 * This allocator allocates memory in regions (multiple of 64 KB for example).
 * Each region is then splitted in blocks. So it doesn't request the memory
 * from the operating system on each call, but only if there are no large
 * enough free blocks in the available regions.
 * Deallocation works in the same way. Deallocation doesn't immediately
 * gives the memory back to the operating system, but marks the appropriate
 * block as free and only if all blocks in the region are free, the complete
 * region is deallocated.
 *
 * ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
 * |      |     |         |     |            ||      |     |                  |
 * |      |prev <-----------    |            ||      |     |                  |
 * |  R   |  B  |         |  B  |            ||   R  |  B  |                  |
 * |  E   |  L  |         |  L  |           next  E  |  L  |                  |
 * |  G   |  O  |  DATA   |  O  |   FREE    --->  G  |  O  |       DATA       |
 * |  I   |  C  |         |  C  |           <---  I  |  C  |                  |
 * |  O   |  K  |         |  K  |           prev  O  |  K  |                  |
 * |  N   |    -----------> next|            ||   N  |     |                  |
 * |      |     |         |     |            ||      |     |                  |
 * ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
 */
final class MmapPool : Allocator
{
    invariant
    {
        for (auto r = &head; *r !is null; r = &((*r).next))
        {
            auto block = cast(Block) (cast(void*) *r + RegionEntry.sizeof);
            do
            {
                assert(block.prev is null || block.prev.next is block);
                assert(block.next is null || block.next.prev is block);
                assert(block.region is *r);
            }
            while ((block = block.next) !is null);
        }
    }

    /**
     * Allocates $(D_PARAM size) bytes of memory.
     *
     * Params:
     *  size = Amount of memory to allocate.
     *
     * Returns: Pointer to the new allocated memory.
     */
    void[] allocate(in size_t size) shared nothrow @nogc
    {
        if (!size)
        {
            return null;
        }
        immutable dataSize = addAlignment(size);

        void* data = findBlock(dataSize);
        if (data is null)
        {
            data = initializeRegion(dataSize);
        }

        return data is null ? null : data[0 .. size];
    }

    ///
    nothrow unittest
    {
        auto p = MmapPool.instance.allocate(20);

        assert(p);

        MmapPool.instance.deallocate(p);
    }

    /**
     * Search for a block large enough to keep $(D_PARAM size) and split it
     * into two blocks if the block is too large.
     *
     * Params:
     *  size = Minimum size the block should have (aligned).
     *
     * Returns: Data the block points to or $(D_KEYWORD null).
     */
    private void* findBlock(in ref size_t size) shared nothrow @nogc
    {
        Block block1;
        RegionLoop: for (auto r = head; r !is null; r = r.next)
        {
            block1 = cast(Block) (cast(void*) r + RegionEntry.sizeof);
            do
            {
                if (block1.free && block1.size >= size)
                {
                    break RegionLoop;
                }
            }
            while ((block1 = block1.next) !is null);
        }
        if (block1 is null)
        {
            return null;
        }
        else if (block1.size >= size + alignment_ + BlockEntry.sizeof)
        { // Split the block if needed
            Block block2 = cast(Block) (cast(void*) block1 + BlockEntry.sizeof + size);
            block2.prev = block1;
            block2.next = block1.next;
            block2.free = true;
            block2.size = block1.size - BlockEntry.sizeof - size;
            block2.region = block1.region;

            if (block1.next !is null)
            {
                block1.next.prev = block2;
            }
            block1.next = block2;
            block1.size = size;
        }
        block1.free = false;
        block1.region.blocks = block1.region.blocks + 1;

        return cast(void*) block1 + BlockEntry.sizeof;
    }

    // Merge block with the next one.
    private void mergeNext(Block block) shared const pure nothrow @safe @nogc
    {
        block.size = block.size + BlockEntry.sizeof + block.next.size;
        if (block.next.next !is null)
        {
            block.next.next.prev = block;
        }
        block.next = block.next.next;
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
        if (p.ptr is null)
        {
            return true;
        }

        Block block = cast(Block) (p.ptr - BlockEntry.sizeof);
        if (block.region.blocks <= 1)
        {
            if (block.region.prev !is null)
            {
                block.region.prev.next = block.region.next;
            }
            else // Replace the list head. It is being deallocated
            {
                head = block.region.next;
            }
            if (block.region.next !is null)
            {
                block.region.next.prev = block.region.prev;
            }
            version (Posix)
            {
                return munmap(cast(void*) block.region, block.region.size) == 0;
            }
            version (Windows)
            {
                return VirtualFree(cast(void*) block.region, 0, MEM_RELEASE) == 0;
            }
        }
        // Merge blocks if neigbours are free.
        if (block.next !is null && block.next.free)
        {
            mergeNext(block);
        }
        if (block.prev !is null && block.prev.free)
        {
            block.prev.size = block.prev.size + BlockEntry.sizeof + block.size;
            if (block.next !is null)
            {
                block.next.prev = block.prev;
            }
            block.prev.next = block.next;
        }
        else
        {
            block.free = true;
        }
        block.region.blocks = block.region.blocks - 1;
        return true;
    }

    ///
    nothrow unittest
    {
        auto p = MmapPool.instance.allocate(20);

        assert(MmapPool.instance.deallocate(p));
    }

    /**
     * Reallocates a memory block in place if possible or returns
     * $(D_KEYWORD false). This function cannot be used to allocate or
     * deallocate memory, so if $(D_PARAM p) is $(D_KEYWORD null) or
     * $(D_PARAM size) is `0`, it should return $(D_KEYWORD false).
     *
     * Params:
     *  p    = A pointer to the memory block.
     *  size = Size of the reallocated block.
     *
     * Returns: $(D_KEYWORD true) if successful, $(D_KEYWORD false) otherwise.
     */
    bool reallocateInPlace(ref void[] p, in size_t size) shared nothrow @nogc
    {
        if (p is null || size == 0)
        {
            return false;
        }
        if (size <= p.length)
        {
            // Leave the block as is.
            p = p.ptr[0 .. size];
            return true;
        }
        Block block1 = cast(Block) (p.ptr - BlockEntry.sizeof);

        if (block1.size >= size)
        {
            // Enough space in the current block. Can happen because of the alignment.
            p = p.ptr[0 .. size];
            return true;
        }
        immutable dataSize = addAlignment(size);
        immutable delta = dataSize - addAlignment(p.length);

        if (block1.next is null
         || !block1.next.free
         || block1.next.size + BlockEntry.sizeof < delta)
        {
            // It is the last block in the region or the next block is too small or not
            // free.
            return false;
        }
        if (block1.next.size >= delta + alignment_)
        {
            // Move size from block2 to block1.
            block1.next.size = block1.next.size - delta;
            block1.size = block1.size + delta;

            auto block2 = cast(Block) (p.ptr + dataSize);
            if (block1.next.next !is null)
            {
                block1.next.next.prev = block2;
            }
            // block1.next and block2 can overlap.
            memmove(cast(void*) block2, cast(void*) block1.next, BlockEntry.sizeof);
            block1.next = block2;
        }
        else
        {
            // The next block has enough space, but is too small for further
            // allocations. Merge it with the current block.
            mergeNext(block1);
        }

        p = p.ptr[0 .. size];
        return true;
    }

    ///
    nothrow unittest
    {
        void[] p;
        assert(!MmapPool.instance.reallocateInPlace(p, 5));
        assert(p is null);

        p = MmapPool.instance.allocate(1);
        auto orig = p.ptr;

        assert(MmapPool.instance.reallocateInPlace(p, 2));
        assert(p.length == 2);
        assert(p.ptr == orig);

        assert(MmapPool.instance.reallocateInPlace(p, 4));
        assert(p.length == 4);
        assert(p.ptr == orig);

        assert(MmapPool.instance.reallocateInPlace(p, 2));
        assert(p.length == 2);
        assert(p.ptr == orig);

        MmapPool.instance.deallocate(p);
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
    bool reallocate(ref void[] p, in size_t size) shared nothrow @nogc
    {
        if (size == 0)
        {
            if (deallocate(p))
            {
                p = null;
                return true;
            }
            return false;
        }
        else if (reallocateInPlace(p, size))
        {
            return true;
        }
        // Can't reallocate in place, allocate a new block,
        // copy and delete the previous one.
        void[] reallocP = allocate(size);
        if (reallocP is null)
        {
            return false;
        }
        if (p !is null)
        {
            memcpy(reallocP.ptr, p.ptr, min(p.length, size));
            deallocate(p);
        }
        p = reallocP;

        return true;
    }

    ///
    nothrow unittest
    {
        void[] p;
        MmapPool.instance.reallocate(p, 10 * int.sizeof);
        (cast(int[]) p)[7] = 123;

        assert(p.length == 40);

        MmapPool.instance.reallocate(p, 8 * int.sizeof);

        assert(p.length == 32);
        assert((cast(int[]) p)[7] == 123);

        MmapPool.instance.reallocate(p, 20 * int.sizeof);
        (cast(int[]) p)[15] = 8;

        assert(p.length == 80);
        assert((cast(int[]) p)[15] == 8);
        assert((cast(int[]) p)[7] == 123);

        MmapPool.instance.reallocate(p, 8 * int.sizeof);

        assert(p.length == 32);
        assert((cast(int[]) p)[7] == 123);

        MmapPool.instance.deallocate(p);
    }

    /**
     * Static allocator instance and initializer.
     *
     * Returns: Global $(D_PSYMBOL MmapPool) instance.
     */
    static @property ref shared(MmapPool) instance() nothrow @nogc
    {
        if (instance_ is null)
        {
            // Get system dependend page size.
            version (Posix)
            {
                pageSize = sysconf(_SC_PAGE_SIZE);
                if (pageSize < 65536)
                {
                    pageSize = pageSize * 65536 / pageSize;
                }
            }
            else version (Windows)
            {
                SYSTEM_INFO si;
                GetSystemInfo(&si);
                pageSize = si.dwPageSize;
            }

            immutable instanceSize = addAlignment(__traits(classInstanceSize, MmapPool));

            Region head; // Will become soon our region list head
            void* data = initializeRegion(instanceSize, head);
            if (data !is null)
            {
                memcpy(data, typeid(MmapPool).initializer.ptr, instanceSize);
                instance_ = cast(shared MmapPool) data;
                instance_.head = head;
            }
        }
        return instance_;
    }

    ///
    nothrow unittest
    {
        assert(instance is instance);
    }

    /*
     * Initializes a region for one element.
     *
     * Params:
     *  size = Aligned size of the first data block in the region.
     *  head = Region list head.
     *
     * Returns: A pointer to the data.
     */
    private static void* initializeRegion(size_t size, ref Region head)
    nothrow @nogc
    {
        immutable regionSize = calculateRegionSize(size);

        version (Posix)
        {
            void* p = mmap(null,
                           regionSize,
                           PROT_READ | PROT_WRITE,
                           MAP_PRIVATE | MAP_ANON,
                           -1,
                           0);
            if (p is MAP_FAILED)
            {
                return null;
            }
        }
        else version (Windows)
        {
            void* p = VirtualAlloc(null,
                                   regionSize,
                                   MEM_COMMIT,
                                   PAGE_READWRITE);
            if (p is null)
            {
                return null;
            }
        }

        Region region = cast(Region) p;
        region.blocks = 1;
        region.size = regionSize;

        // Set the pointer to the head of the region list
        if (head !is null)
        {
            head.prev = region;
        }
        region.next = head;
        region.prev = null;
        head = region;

        // Initialize the data block
        void* memoryPointer = p + RegionEntry.sizeof;
        Block block1 = cast(Block) memoryPointer;
        block1.size = size;
        block1.free = false;

        // It is what we want to return
        void* data = memoryPointer + BlockEntry.sizeof;

        // Free block after data
        memoryPointer = data + size;
        Block block2 = cast(Block) memoryPointer;
        block1.prev = block2.next = null;
        block1.next = block2;
        block2.prev = block1;
        block2.size = regionSize - size - RegionEntry.sizeof - BlockEntry.sizeof * 2;
        block2.free = true;
        block1.region = block2.region = region;

        return data;
    }

    private void* initializeRegion(size_t size) shared nothrow @nogc
    {
        return initializeRegion(size, head);
    }

    /*
     * Params:
     *  x = Space to be aligned.
     *
     * Returns: Aligned size of $(D_PARAM x).
     */
    private static immutable(size_t) addAlignment(size_t x)
    pure nothrow @safe @nogc
    out (result)
    {
        assert(result > 0);
    }
    body
    {
        return (x - 1) / alignment_ * alignment_ + alignment_;
    }

    /*
     * Params:
     *  x = Required space.
     *
     * Returns: Minimum region size (a multiple of $(D_PSYMBOL pageSize)).
     */
    private static immutable(size_t) calculateRegionSize(size_t x)
    nothrow @safe @nogc
    out (result)
    {
        assert(result > 0);
    }
    body
    {
        x += RegionEntry.sizeof + BlockEntry.sizeof * 2;
        return x / pageSize * pageSize + pageSize;
    }

    /**
     * Returns: Alignment offered.
     */
    @property uint alignment() shared const pure nothrow @safe @nogc
    {
        return alignment_;
    }
    private enum alignment_ = 8;

    private shared static MmapPool instance_;
    private shared static size_t pageSize;

    private shared struct RegionEntry
    {
        Region prev;
        Region next;
        uint blocks;
        size_t size;
    }
    private alias Region = shared RegionEntry*;
    private shared Region head;

    private shared struct BlockEntry
    {
        Block prev;
        Block next;
        Region region;
        size_t size;
        bool free;
    }
    private alias Block = shared BlockEntry*;
}

// A lot of allocations/deallocations, but it is the minimum caused a
// segmentation fault because MmapPool reallocateInPlace moves a block wrong.
unittest
{
    auto a = MmapPool.instance.allocate(16);
    auto d = MmapPool.instance.allocate(16);
    auto b = MmapPool.instance.allocate(16);
    auto e = MmapPool.instance.allocate(16);
    auto c = MmapPool.instance.allocate(16);
    auto f = MmapPool.instance.allocate(16);

    MmapPool.instance.deallocate(a);
    MmapPool.instance.deallocate(b);
    MmapPool.instance.deallocate(c);

    a = MmapPool.instance.allocate(50);
    MmapPool.instance.reallocateInPlace(a, 64);
    MmapPool.instance.deallocate(a);

    a = MmapPool.instance.allocate(1);
    auto tmp1 = MmapPool.instance.allocate(1);
    auto h1 = MmapPool.instance.allocate(1);
    auto tmp2 = cast(ubyte[]) MmapPool.instance.allocate(1);

    auto h2 = MmapPool.instance.allocate(2);
    tmp1 = MmapPool.instance.allocate(1);
    MmapPool.instance.deallocate(h2);
    MmapPool.instance.deallocate(h1);

    h2 = MmapPool.instance.allocate(2);
    h1 = MmapPool.instance.allocate(1);
    MmapPool.instance.deallocate(h2);

    auto rep = cast(void[]) tmp2;
    MmapPool.instance.reallocate(rep, tmp1.length);
    tmp2 = cast(ubyte[]) rep;

    MmapPool.instance.reallocate(tmp1, 9);

    rep = cast(void[]) tmp2;
    MmapPool.instance.reallocate(rep, tmp1.length);
    tmp2 = cast(ubyte[]) rep;
    MmapPool.instance.reallocate(tmp1, 17);

    tmp2[$ - 1] = 0;

    MmapPool.instance.deallocate(tmp1);

    b = MmapPool.instance.allocate(16);

    MmapPool.instance.deallocate(h1);
    MmapPool.instance.deallocate(a);
    MmapPool.instance.deallocate(b);
    MmapPool.instance.deallocate(d);
    MmapPool.instance.deallocate(e);
    MmapPool.instance.deallocate(f);
}
