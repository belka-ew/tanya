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
 * This interface should be similar to $(D_PSYMBOL
 * std.experimental.allocator.IAllocator), but usable in
 * $(D_KEYWORD @nogc)-code.
 */
interface Allocator
{
@nogc:
	/**
	 * Allocates $(D_PARAM s) bytes of memory.
	 *
	 * Params:
	 * 	s = Amount of memory to allocate.
	 *
	 * Returns: The pointer to the new allocated memory.
	 */
    void[] allocate(size_t s) @safe;

    /**
	 * Deallocates a memory block.
	 *
	 * Params:
	 * 	p = A pointer to the memory block to be freed.
	 *
	 * Returns: Whether the deallocation was successful.
	 */
    bool deallocate(void[] p) @safe;

	/**
	 * Increases or decreases the size of a memory block.
	 *
	 * Params:
	 * 	p    = A pointer to the memory block.
	 * 	size = Size of the reallocated block.
	 *
	 * Returns: Whether the reallocation was successful.
	 */
	bool reallocate(ref void[] p, size_t s) @safe;

	/**
     * Static allocator instance and initializer.
	 *
	 * Returns: An $(D_PSYMBOL Allocator) instance.
	 */
	static @property Allocator instance() @safe;
}
