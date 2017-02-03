/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * Copyright: Eugene Wissner 2016-2017.
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
