/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * Copyright: Eugene Wissner 2016.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 */
module tanya.memory.mmappool;

import tanya.memory.allocator;
import core.atomic;
import core.stdc.string;

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
final class MmapPool : Allocator
{
	/**
	 * Allocates $(D_PARAM size) bytes of memory.
	 *
	 * Params:
	 * 	size = Amount of memory to allocate.
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

		return data is null ? null : data[0..size];
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
	 * 	size = Minimum size the block should have (aligned).
	 *
	 * Returns: Data the block points to or $(D_KEYWORD null).
	 */
	private void* findBlock(in ref size_t size) shared nothrow @nogc
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
			block2.next = block1.next;
			block2.free = true;
			block2.size = block1.size - blockEntrySize - size;
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
	bool deallocate(void[] p) shared nothrow @nogc
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
			block.size = block.size + blockEntrySize + block.next.size;
			if (block.next.next !is null)
			{
				block.next.next.prev = block;
			}
			block.next = block.next.next;
		}
		if (block.prev !is null && block.prev.free)
		{
			block.prev.size = block.prev.size + blockEntrySize + block.size;
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
	 * Increases or decreases the size of a memory block.
	 *
	 * Params:
	 * 	p    = A pointer to the memory block.
	 * 	size = Size of the reallocated block.
	 *
	 * Returns: Whether the reallocation was successful.
	 */
	bool reallocate(ref void[] p, in size_t size) shared nothrow @nogc
	{
		void[] reallocP;

		if (size == p.length)
		{
			return true;
		}
		else if (size > 0)
		{
			reallocP = allocate(size);
			if (reallocP is null)
			{
				return false;
			}
		}

		if (p !is null)
		{
			if (size > p.length)
			{
				reallocP[0..p.length] = p[0..$];
			}
			else if (size > 0)
			{
				reallocP[0..size] = p[0..size];
			}
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
					atomicOp!"*="(pageSize, 65536 / pageSize);
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

	/**
	 * Initializes a region for one element.
	 *
	 * Params:
	 * 	size = Aligned size of the first data block in the region.
	 * 	head = Region list head.
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
	private void* initializeRegion(size_t size) shared nothrow @nogc
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

	/**
	 * Params:
	 * 	x = Required space.
	 *
	 * Returns: Minimum region size (a multiple of $(D_PSYMBOL pageSize)).
	 */
	pragma(inline)
	private static immutable(size_t) calculateRegionSize(size_t x)
	nothrow @safe @nogc
	out (result)
	{
		assert(result > 0);
	}
	body
	{
		x += regionEntrySize + blockEntrySize * 2;
		return x / pageSize * pageSize + pageSize;
	}

	@property uint alignment() shared const pure nothrow @safe @nogc
	{
		return alignment_;
	}
	private enum alignment_ = 8;

	private static shared MmapPool instance_;

	private shared static size_t pageSize;

	private shared struct RegionEntry
	{
		Region prev;
		Region next;
		uint blocks;
		size_t size;
	}
	private alias Region = shared RegionEntry*;
	private enum regionEntrySize = 32;

	private shared Region head;

	private shared struct BlockEntry
	{
		Block prev;
		Block next;
		bool free;
		size_t size;
		Region region;
	}
	private alias Block = shared BlockEntry*;
	private enum blockEntrySize = 40;
}
