/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/*
 * Native allocator.
 *
 * Copyright: Eugene Wissner 2016-2020.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 * Source: $(LINK2 https://github.com/caraus-ecms/tanya/blob/master/middle/tanya/memory/mmappool.d,
 *                 tanya/memory/mmappool.d)
 */
module tanya.memory.mmappool;

import core.sys.linux.sys.mman;
import tanya.memory.allocator;
import tanya.memory.op;
import tanya.os.error;

version (Windows)
{
    import core.sys.windows.basetsd : SIZE_T;
    import core.sys.windows.windef : BOOL, DWORD;
    import core.sys.windows.winnt : MEM_COMMIT, MEM_RELEASE, PAGE_READWRITE, PVOID;

    extern (Windows)
    private PVOID VirtualAlloc(PVOID, SIZE_T, DWORD, DWORD)
    @nogc nothrow pure @system;

    extern (Windows)
    private BOOL VirtualFree(shared PVOID, SIZE_T, DWORD)
    @nogc nothrow pure @system;
}
else
{
    extern(C) pragma(mangle, "mmap")
    private void* mapMemory(void *addr, size_t length, int prot, int flags, int fd, off_t offset)
    @nogc nothrow pure @system;

    extern(C) pragma(mangle, "munmap")
    private bool unmapMemory(shared void* addr, size_t length)
    @nogc nothrow pure @system;
}

/*
 * This allocator allocates memory in regions (multiple of 64 KB for example).
 * Each region is then splitted in blocks. So it doesn't request the memory
 * from the operating system on each call, but only if there are no large
 * enough free blocks in the available regions.
 * Deallocation works in the same way. Deallocation doesn't immediately
 * gives the memory back to the operating system, but marks the appropriate
 * block as free and only if all blocks in the region are free, the complete
 * region is deallocated.
 *
 * <pre>
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
 * </pre>
 */
final class MmapPool : Allocator
{
    version (none)
    {
        @nogc nothrow pure @system invariant
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
    }

    /*
     * Allocates $(D_PARAM size) bytes of memory.
     *
     * Params:
     *  size = Amount of memory to allocate.
     *
     * Returns: Pointer to the new allocated memory.
     */
    void[] allocate(size_t size) @nogc nothrow pure shared @system
    {
        if (size == 0)
        {
            return null;
        }
        const dataSize = addAlignment(size);
        if (dataSize < size)
        {
            return null;
        }

        void* data = findBlock(dataSize);
        if (data is null)
        {
            data = initializeRegion(dataSize);
        }

        return data is null ? null : data[0 .. size];
    }

    /*
     * Search for a block large enough to keep $(D_PARAM size) and split it
     * into two blocks if the block is too large.
     *
     * Params:
     *  size = Minimum size the block should have (aligned).
     *
     * Returns: Data the block points to or $(D_KEYWORD null).
     */
    private void* findBlock(const ref size_t size)
    @nogc nothrow pure shared @system
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
    private void mergeNext(Block block) const @nogc nothrow pure @safe shared
    {
        block.size = block.size + BlockEntry.sizeof + block.next.size;
        if (block.next.next !is null)
        {
            block.next.next.prev = block;
        }
        block.next = block.next.next;
    }

    /*
     * Deallocates a memory block.
     *
     * Params:
     *  p = A pointer to the memory block to be freed.
     *
     * Returns: Whether the deallocation was successful.
     */
    bool deallocate(void[] p) @nogc nothrow pure shared @system
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
            version (Windows)
                return VirtualFree(block.region, 0, MEM_RELEASE) != 0;
            else
                return unmapMemory(block.region, block.region.size) == 0;
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

    /*
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
    bool reallocateInPlace(ref void[] p, size_t size)
    @nogc nothrow pure shared @system
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
            // Enough space in the current block.
            p = p.ptr[0 .. size];
            return true;
        }
        const dataSize = addAlignment(size);
        const pAlignment = addAlignment(p.length);
        assert(pAlignment >= p.length, "Invalid memory chunk length");
        const delta = dataSize - pAlignment;

        if (block1.next is null
         || !block1.next.free
         || dataSize < size
         || block1.next.size + BlockEntry.sizeof < delta)
        {
            /* - It is the last block in the region
             * - The next block isn't free
             * - The next block is too small
             * - Requested size is too large
             */
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
            copyBackward((cast(void*) block1.next)[0 .. BlockEntry.sizeof],
                         (cast(void*) block2)[0 .. BlockEntry.sizeof]);
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

    /*
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
            copy(p[0 .. p.length < size ? p.length : size], reallocP);
            deallocate(p);
        }
        p = reallocP;

        return true;
    }

    static private shared(MmapPool) instantiate() @nogc nothrow @system
    {
        if (instance_ is null)
        {
            const instanceSize = addAlignment(__traits(classInstanceSize,
                                              MmapPool));

            Region head; // Will become soon our region list head
            void* data = initializeRegion(instanceSize, head);
            if (data !is null)
            {
                copy(typeid(MmapPool).initializer, data[0 .. instanceSize]);
                instance_ = cast(shared MmapPool) data;
                instance_.head = head;
            }
        }
        return instance_;
    }

    /*
     * Static allocator instance and initializer.
     *
     * Returns: Global $(D_PSYMBOL MmapPool) instance.
     */
    static @property shared(MmapPool) instance() @nogc nothrow pure @system
    {
        return (cast(GetPureInstance!MmapPool) &instantiate)();
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
    private static void* initializeRegion(const size_t size, ref Region head)
    @nogc nothrow pure @system
    {
        const regionSize = calculateRegionSize(size);
        if (regionSize < size)
        {
            return null;
        }
        version (Windows)
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
        else
        {
            void* p = mapMemory(null,
                    regionSize,
                    PROT_READ | PROT_WRITE,
                    MAP_PRIVATE | MAP_ANONYMOUS,
                    -1,
                    0);
            if (cast(ptrdiff_t) p == -1)
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

    private void* initializeRegion(const size_t size)
    @nogc nothrow pure shared @system
    {
        return initializeRegion(size, this.head);
    }

    /*
     * Params:
     *  x = Space to be aligned.
     *
     * Returns: Aligned size of $(D_PARAM x).
     */
    private static size_t addAlignment(const size_t x) @nogc nothrow pure @safe
    {
        return (x - 1) / alignment_ * alignment_ + alignment_;
    }

    /*
     * Params:
     *  x = Required space.
     *
     * Returns: Minimum region size (a multiple of $(D_PSYMBOL pageSize)).
     */
    private static size_t calculateRegionSize(ref const size_t x)
    @nogc nothrow pure @safe
    {
        return (x + RegionEntry.sizeof + BlockEntry.sizeof * 2)
             / pageSize * pageSize + pageSize;
    }

    /*
     * Returns: Alignment offered.
     */
    @property uint alignment() const @nogc nothrow pure @safe shared
    {
        return alignment_;
    }

    private enum uint alignment_ = 8;

    private shared static MmapPool instance_;

    // Page size.
    enum size_t pageSize = 65536;

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

@nogc nothrow pure @system unittest
{
    // allocate() check.
    size_t tooMuchMemory = size_t.max
        - MmapPool.alignment_
        - MmapPool.BlockEntry.sizeof * 2
        - MmapPool.RegionEntry.sizeof
        - MmapPool.pageSize;
    assert(MmapPool.instance.allocate(tooMuchMemory) is null);

    assert(MmapPool.instance.allocate(size_t.max) is null);

    // initializeRegion() check.
    tooMuchMemory = size_t.max - MmapPool.alignment_;
    assert(MmapPool.instance.allocate(tooMuchMemory) is null);
}
