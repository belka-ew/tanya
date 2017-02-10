/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * Copyright: Eugene Wissner 2016-2017.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 */  
module tanya.container.string;

import core.exception;
import core.stdc.string;
import tanya.memory;

/**
 * UTF-8 string.
 */
struct String
{
	private char[] data;
	private size_t length_;

	invariant
	{
		assert(length_ <= data.length);
	}

	/// Ditto.
	this(const(char)[] str, shared Allocator allocator = defaultAllocator)
	nothrow @trusted @nogc
	{
		this(allocator);

		data = cast(char[]) allocator.allocate(str.length);
		if (str.length > 0 && data is null)
		{
				onOutOfMemoryErrorNoGC();
		}
		memcpy(data.ptr, str.ptr, str.length);
	}

	/// Ditto.
	this(const(wchar)[] str, shared Allocator allocator = defaultAllocator)
	nothrow @trusted @nogc
	{
		this(allocator);

	}

	/// Ditto.
	this(const(dchar)[] str, shared Allocator allocator = defaultAllocator)
	nothrow @trusted @nogc
	{
		this(allocator);

	}

	/// Ditto.
	this(shared Allocator allocator) pure nothrow @safe @nogc
	in
	{
		assert(allocator !is null);
	}
	body
	{
		allocator_ = allocator;
	}

	~this() nothrow @trusted @nogc
	{
		allocator.deallocate(data);
	}

	mixin DefaultAllocator;
}
