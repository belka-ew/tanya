/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * Copyright: Eugene Wissner 2016.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 */  
module tanya.memory.ullocator;

import tanya.memory.allocator;

@nogc:

version (Posix):

import core.sys.posix.sys.mman;
import core.sys.posix.unistd;

/**
 * Allocator for Posix systems with mmap/munmap support.
 *
 * This allocator allocates memory in regions (multiple of 4 KB for example).
 * Each region is then splitted in blocks. So it doesn't request the memory
 * from the operating system on each call, but only if there are no large
 * enought free blocks in the available regions.
 * Deallocation works in the same way. Deallocation doesn't immediately
 * gives the memory back to the operating system, but marks the appropriate
 * block as free and only if all blocks in the region are free, the complet
 * region is deallocated.
 *
 * ----------------------------------------------------------------------------
 * |      |     |         |     |            ||      |     |                  |
 * |      |prev <-----------    |            ||      |     |                  |
 * |  R   |  B  |         |  B  |            ||   R  |  B  |                  |
 * |  E   |  L  |         |  L  |           next  E  |  L  |                  |
 * |  G   |  O  |  DATA   |  O  |   FREE    --->  G  |  O  |       DATA       |
 * |  I   |  C  |         |  C  |           <---  I  |  C  |                  |
 * |  O   |  K  |         |  K  |           prev  O  |  K  |                  |
 * |  N   |    -----------> next|            ||   N  |     |                  |
 * |      |     |         |     |            ||      |     |                  |
 * --------------------------------------------------- ------------------------
 */
class Ullocator : Allocator
{
@nogc:
	@disable this();

	shared static this() @safe nothrow
	{
		pageSize = sysconf(_SC_PAGE_SIZE);
	}

	/**
	 * Allocates $(D_PARAM size) bytes of memory.
	 *
	 * Params:
	 * 	size = Amount of memory to allocate.
	 *
	 * Returns: The pointer to the new allocated memory.
	 */
    void[] allocate(size_t size) @trusted nothrow
    {
		immutable dataSize = addAlignment(size);

		void* data = findBlock(dataSize);
		if (data is null)
		{
			data = initializeRegion(dataSize);
		}

		return data is null ? null : data[0..size];
    }

	///
	unittest
	{
		auto p = Ullocator.instance.allocate(20);

		assert(p);

		Ullocator.instance.deallocate(p);
	}

	/**
	 * Search for a block large enough to keep $(D_PARAM size) and split it
	 * into two blocks if the block is too large.
	 *
	 * Params:
	 * 	size = Minimum size the block should have.
	 *
	 * Returns: Data the block points to or $(D_KEYWORD null).
	 */
	private void* findBlock(size_t size) nothrow
	{
		Block block1;
		RegionLoop: for (auto r = head; r !is null; r = r.next)
		{
			block1 = cast(Block) (cast(void*) r + regionEntrySize);
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
		else if (block1.size >= size + alignment + blockEntrySize)
		{ // Split the block if needed
			Block block2 = cast(Block) (cast(void*) block1 + blockEntrySize + size);
			block2.prev = block1;
			if (block1.next is null)
			{
				block2.next = null;
			}
			else
			{
				block2.next = block1.next.next;
			}
			block1.next = block2;

			block1.free = false;
			block2.free = true;

			block2.size = block1.size - blockEntrySize - size;
			block1.size = size;

			block2.region = block1.region;
			++block1.region.blocks;
		}
		else
		{
			block1.free = false;
			++block1.region.blocks;
		}
		return cast(void*) block1 + blockEntrySize;
	}

    /**
	 * Deallocates a memory block.
	 *
	 * Params:
	 * 	p = A pointer to the memory block to be freed.
	 *
	 * Returns: Whether the deallocation was successful.
	 */
    bool deallocate(void[] p) @trusted nothrow
    {
		if (p is null)
		{
			return true;
		}

		Block block = cast(Block) (p.ptr - blockEntrySize);
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
			return munmap(block.region, block.region.size) == 0;
		}
		else
		{
			block.free = true;
			--block.region.blocks;
			return true;
		}
    }

	///
	unittest
	{
		auto p = Ullocator.instance.allocate(20);

		assert(Ullocator.instance.deallocate(p));
	}

	/**
	 * Increases or decreases the size of a memory block.
	 *
	 * Params:
	 * 	p    = A pointer to the memory block.
	 * 	size = Size of the reallocated block.
	 *
	 * Returns: Whether the reallocation was successful.
	 */
	bool reallocate(ref void[] p, size_t size) @trusted nothrow
	{
		if (size == p.length)
		{
			return true;
		}

		auto reallocP = allocate(size);
		if (reallocP is null)
		{
			return false;
		}

		if (p !is null)
		{
			if (size > p.length)
			{
				reallocP[0..p.length] = p[0..$];
			}
			else
			{
				reallocP[0..size] = p[0..size];
			}
			deallocate(p);
		}
		p = reallocP;

		return true;
	}

	///
	unittest
	{
		void[] p;
		Ullocator.instance.reallocate(p, 10 * int.sizeof);
		(cast(int[]) p)[7] = 123;

		assert(p.length == 40);

		Ullocator.instance.reallocate(p, 8 * int.sizeof);

		assert(p.length == 32);
		assert((cast(int[]) p)[7] == 123);

		Ullocator.instance.reallocate(p, 20 * int.sizeof);
		(cast(int[]) p)[15] = 8;

		assert(p.length == 80);
		assert((cast(int[]) p)[15] == 8);
		assert((cast(int[]) p)[7] == 123);

		Ullocator.instance.reallocate(p, 8 * int.sizeof);

		assert(p.length == 32);
		assert((cast(int[]) p)[7] == 123);

		Ullocator.instance.deallocate(p);
	}

	/**
     * Static allocator instance and initializer.
	 *
	 * Returns: The global $(D_PSYMBOL Allocator) instance.
	 */
	static @property Ullocator instance() @trusted nothrow
	{
		if (instance_ is null)
		{
			immutable instanceSize = addAlignment(__traits(classInstanceSize, Ullocator));

			Region head; // Will become soon our region list head
			void* data = initializeRegion(instanceSize, head);

			if (data is null)
			{
				return null;
			}
			data[0..instanceSize] = typeid(Ullocator).initializer[];
			instance_ = cast(Ullocator) data;
			instance_.head = head;
		}
		return instance_;
	}

	///
	unittest
	{
		assert(instance is instance);
	}

	/**
	 * Initializes a region for one element.
	 *
	 * Params:
	 * 	size = Aligned size of the first data block in the region.
	 *  head = Region list head.
	 *
	 * Returns: A pointer to the data.
	 */
	pragma(inline)
	private static void* initializeRegion(size_t size,
	                                      ref Region head) nothrow
	{
		immutable regionSize = calculateRegionSize(size);
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
		void* memoryPointer = p + regionEntrySize;
		Block block1 = cast(Block) memoryPointer;
		block1.size = size;
		block1.free = false;

		// It is what we want to return
		void* data = memoryPointer + blockEntrySize;

		// Free block after data
		memoryPointer = data + size;
		Block block2 = cast(Block) memoryPointer;
		block1.prev = block2.next = null;
		block1.next = block2;
		block2.prev = block1;
		block2.size = regionSize - size - regionEntrySize - blockEntrySize * 2;
		block2.free = true;
		block1.region = block2.region = region;

		return data;
	}

	/// Ditto.
	private void* initializeRegion(size_t size) nothrow
	{
		return initializeRegion(size, head);
	}

	/**
	 * Params:
	 * 	x = Space to be aligned.
	 *
	 * Returns: Aligned size of $(D_PARAM x).
	 */
	pragma(inline)
	private static immutable(size_t) addAlignment(size_t x) @safe pure nothrow
	out (result)
	{
		assert(result > 0);
	}
	body
	{
		return (x - 1) / alignment * alignment + alignment;
	}

	/**
	 * Params:
	 * 	x = Required space.
	 *
	 * Returns: Minimum region size (a multiple of $(D_PSYMBOL pageSize)).
	 */
	pragma(inline)
	private static immutable(size_t) calculateRegionSize(size_t x)
	@safe pure nothrow
	out (result)
	{
		assert(result > 0);
	}
	body
	{
		x += regionEntrySize + blockEntrySize * 2;
		return x / pageSize * pageSize + pageSize;
	}

	enum alignment = 8;

	private static Ullocator instance_;

	private shared static immutable long pageSize;

	private struct RegionEntry
	{
		Region prev;
		Region next;
		uint blocks;
		ulong size;
	}
	private alias Region = RegionEntry*;
	private enum regionEntrySize = 32;

	private Region head;

	private struct BlockEntry
	{
		Block prev;
		Block next;
		bool free;
		ulong size;
		Region region;
	}
	private alias Block = BlockEntry*;
	private enum blockEntrySize = 40;
}
