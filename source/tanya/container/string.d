/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * UTF-8 string.
 *
 * Copyright: Eugene Wissner 2017.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 */  
module tanya.container.string;

import core.checkedint;
import core.exception;
import core.stdc.string;
import std.algorithm.comparison;
import tanya.memory;

/**
 * UTF-8 string.
 */
struct String
{
    private size_t length_;
    private char* data;
    private size_t capacity_;

    invariant
    {
        assert(length_ <= capacity_);
    }

    /**
     * Params:
     *  str       = Initial string.
     *  allocator = Allocator.
     */
    this(const(char)[] str, shared Allocator allocator = defaultAllocator)
    nothrow @trusted @nogc
    {
        this(allocator);
        reserve(str.length);
        length_ = str.length;
        memcpy(data, str.ptr, length_);
    }

    /// Ditto.
    this(const(wchar)[] str, shared Allocator allocator = defaultAllocator)
    nothrow @trusted @nogc
    {
        this(allocator);

        bool overflow;
        auto size = mulu(str.length, 4, overflow);
        assert(!overflow);

        reserve(size);

        auto s = data;
        auto sourceLength = str.length;
        for (auto c = str.ptr; sourceLength != 0; ++c, --sourceLength)
        {
            if (*c < 0x80)
            {
                *s++ = *c & 0x7f;
                length_ += 1;
            }
            else if (*c < 0x800)
            {
                *s++ = 0xc0 | (*c >> 6) & 0xff;
                *s++ = 0x80 | (*c & 0x3f);
                length_ += 2;
            }
            else if (*c < 0xd800 || *c - 0xe000 < 0x2000)
            {
                *s++ = 0xe0 | (*c >> 12) & 0xff;
                *s++ = 0x80 | ((*c >> 6) & 0x3f);
                *s++ = 0x80 | (*c & 0x3f);
                length_ += 3;
            }
            else if ((*c - 0xd800) < 2048 && sourceLength > 0 && *(c + 1) - 0xdc00 < 0x400)
            { // Surrogate pair
                dchar d = (*c - 0xd800) | ((*c++ - 0xdc00) >> 10);

                *s++ = 0xf0 | (d >> 18);
                *s++ = 0x80 | ((d >> 12) & 0x3f);
                *s++ = 0x80 | ((d >> 6) & 0x3f);
                *s++ = 0x80 | (d & 0x3f);
                --sourceLength;
                length_ += 4;
            }
        }
    }

    ///
    @safe @nogc unittest
    {
        auto s = String("\u10437"w);
        assert("\u10437" == s.get());
    }

    /// Ditto.
    this(const(dchar)[] str, shared Allocator allocator = defaultAllocator)
    nothrow @trusted @nogc
    {
        this(allocator);

        bool overflow;
        auto size = mulu(str.length, 4, overflow);
        assert(!overflow);

        reserve(size);

        auto s = data;
        foreach (c; str)
        {
            if (c < 0x80)
            {
                *s++ = c & 0x7f;
                length_ += 1;
            }
            else if (c < 0x800)
            {
                *s++ = 0xc0 | (c >> 6) & 0xff;
                *s++ = 0x80 | (c & 0x3f);
                length_ += 2;
            }
            else if (c < 0xd800 || c - 0xe000 < 0x2000)
            {
                *s++ = 0xe0 | (c >> 12) & 0xff;
                *s++ = 0x80 | ((c >> 6) & 0x3f);
                *s++ = 0x80 | (c & 0x3f);
                length_ += 3;
            }
            else if (c - 0x10000 < 0x100000)
            {
                *s++ = 0xf0 | (c >> 18);
                *s++ = 0x80 | ((c >> 12) & 0x3f);
                *s++ = 0x80 | ((c >> 6) & 0x3f);
                *s++ = 0x80 | (c & 0x3f);
                length_ += 4;
            }
        }
    }

    ///
    @nogc @safe unittest
    {
        auto s = String("Отказаться от вина - в этом страшная вина."d);
        assert("Отказаться от вина - в этом страшная вина." == s.get());
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

    /**
     * Destroys the string.
     */
    ~this() nothrow @trusted @nogc
    {
        allocator.deallocate(data[0 .. capacity_]);
    }

    /**
     * Reserves $(D_PARAM size) bytes for the string.
     *
     * If $(D_PARAM size) is less than or equal to the $(D_PSYMBOL capacity), the
     * function call does not cause a reallocation and the string capacity is not
     * affected.
     *
     * Params:
     *  size = Desired size in bytes.
     */
    void reserve(in size_t size) nothrow @trusted @nogc
    {
        if (capacity_ >= size)
        {
            return;
        }

        void[] buf = data[0 .. capacity_];
        if (!allocator.reallocate(buf, size))
        {
            onOutOfMemoryErrorNoGC();
        }
        data = cast(char*) buf;
        capacity_ = size;
    }

    ///
    @nogc @safe unittest
    {
        String s;
        assert(s.capacity == 0);

        s.reserve(3);
        assert(s.capacity == 3);

        s.reserve(3);
        assert(s.capacity == 3);

        s.reserve(1);
        assert(s.capacity == 3);
    }

    /**
     * Requests the string to reduce its capacity to fit the $(D_PARAM size).
     *
     * The request is non-binding. The string won't become smaller than the
     * string byte length.
     *
     * Params:
     *  size = Desired size.
     */
    void shrink(in size_t size) nothrow @trusted @nogc
    {
        if (capacity_ <= size)
        {
            return;
        }

        immutable n = max(length_, size);
        void[] buf = data[0 .. capacity_];
        if (allocator.reallocate(buf, size))
        {
            capacity_ = n;
            data = cast(char*) buf;
        }
    }

    ///
    @nogc @safe unittest
    {
        auto s = String("Die Alten lasen laut.");
        assert(s.capacity == 21);

        s.reserve(30);
        s.shrink(25);
        assert(s.capacity == 25);

        s.shrink(18);
        assert(s.capacity == 21);
    }

    /**
     * Returns: String capacity in bytes.
     */
    @property size_t capacity() const pure nothrow @safe @nogc
    {
        return capacity_;
    }

    ///
    @nogc @safe unittest
    {
        auto s = String("In allem Schreiben ist Schamlosigkeit.");
        assert(s.capacity == 38);
    }

	/**
	 * Returns an array used internally by the string.
	 * The length of the returned array may be smaller than the size of the
     * reserved memory for the string.
	 *
	 * Returns: The array representing the string.
	 */
    inout(char[]) get() inout pure nothrow @trusted @nogc
    {
        return data[0 .. length_];
    }

    mixin DefaultAllocator;
}
