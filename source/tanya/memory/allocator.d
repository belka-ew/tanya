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

/**
 * Abstract class implementing a basic allocator.
 */
interface Allocator
{
	/**
	 * Returns: Alignment offered.
	 */
	@property uint alignment() const shared pure nothrow @safe @nogc;

	/**
	 * Allocates $(D_PARAM size) bytes of memory.
	 *
	 * Params:
	 * 	size = Amount of memory to allocate.
	 *
	 * Returns: Pointer to the new allocated memory.
	 */
	void[] allocate(in size_t size) shared nothrow @nogc;

	/**
	 * Deallocates a memory block.
	 *
	 * Params:
	 * 	p = A pointer to the memory block to be freed.
	 *
	 * Returns: Whether the deallocation was successful.
	 */
	bool deallocate(void[] p) shared nothrow @nogc;

	/**
	 * Increases or decreases the size of a memory block.
	 *
	 * Params:
	 * 	p    = A pointer to the memory block.
	 * 	size = Size of the reallocated block.
	 *
	 * Returns: Pointer to the allocated memory.
	 */
	bool reallocate(ref void[] p, in size_t size) shared nothrow @nogc;

	/**
	 * Reallocates a memory block in place if possible or returns
	 * $(D_KEYWORD false). This function cannot be used to allocate or
	 * deallocate memory, so if $(D_PARAM p) is $(D_KEYWORD null) or
	 * $(D_PARAM size) is `0`, it should return $(D_KEYWORD false).
	 *
	 * Params:
	 * 	p    = A pointer to the memory block.
	 * 	size = Size of the reallocated block.
	 *
	 * Returns: $(D_KEYWORD true) if successful, $(D_KEYWORD false) otherwise.
	 */
	bool reallocateInPlace(ref void[] p, in size_t size) shared nothrow @nogc;
}

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
	 * 	allocator = The allocator should be used.
	 */
	this(shared Allocator allocator)
	in
	{
		assert(allocator !is null);
	}
	body
	{
		this.allocator_ = allocator;
	}

	/**
	 * This property checks if the allocator was set in the constructor
	 * and sets it to the default one, if not.
	 *
	 * Returns: Used allocator.
	 *
	 * Postcondition: $(D_INLINECODE allocator_ !is null)
	 */
	protected @property shared(Allocator) allocator() nothrow @safe @nogc
	out (allocator)
	{
		assert(allocator !is null);
	}
	body
	{
		if (allocator_ is null)
		{
			allocator_ = defaultAllocator;
		}
		return allocator_;
	}

	/// Ditto.
	@property shared(Allocator) allocator() const nothrow @trusted @nogc
	out (allocator)
	{
		assert(allocator !is null);
	}
	body
	{
		if (allocator_ is null)
		{
			return defaultAllocator;
		}
		return cast(shared Allocator) allocator_;
	}
}
