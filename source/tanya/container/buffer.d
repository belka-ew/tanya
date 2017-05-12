/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * Copyright: Eugene Wissner 2016-2017.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 */
module tanya.container.buffer;

import std.traits;
import tanya.memory;

version (unittest)
{
    private int fillBuffer(ubyte[] buffer,
                           in size_t size,
                           int start = 0,
                           int end = 10) @nogc pure nothrow
    in
    {
        assert(start < end);
    }
    body
    {
        auto numberRead = end - start;
        for (ubyte i; i < numberRead; ++i)
        {
            buffer[i] = cast(ubyte) (start + i);
        }
        return numberRead;
    }
}

/**
 * Self-expanding buffer, that can be used with functions returning the number
 * of the read bytes.
 *
 * This buffer supports asynchronous reading. It means you can pass a new chunk
 * to an asynchronous read function during you are working with already
 * available data. But only one asynchronous call at a time is supported. Be
 * sure to call $(D_PSYMBOL ReadBuffer.clear()) before you append the result
 * of the pended asynchronous call.
 *
 * Params:
 *  T = Buffer type.
 */
struct ReadBuffer(T = ubyte)
    if (isScalarType!T)
{
    /// Internal buffer.
    private T[] buffer_;

    /// Filled buffer length.
    private size_t length_;

    /// Start of available data.
    private size_t start;

    /// Last position returned with $(D_KEYWORD []).
    private size_t ring;

    /// Available space.
    private immutable size_t minAvailable = 1024;

    /// Size by which the buffer will grow.
    private immutable size_t blockSize = 8192;

    invariant
    {
        assert(length_ <= buffer_.length);
        assert(blockSize > 0);
        assert(minAvailable > 0);
    }

    /**
     * Creates a new read buffer.
     *
     * Params:
     *  size         = Initial buffer size and the size by which the buffer
     *                 will grow.
     *  minAvailable = minimal size should be always  available to fill.
     *                 So it will reallocate if $(D_INLINECODE
     *                 $(D_PSYMBOL free) < $(D_PARAM minAvailable)).
     *  allocator    = Allocator.
     */
    this(in size_t size,
         in size_t minAvailable = 1024,
         shared Allocator allocator = defaultAllocator) @trusted
    {
        this(allocator);
        this.minAvailable = minAvailable;
        this.blockSize = size;
        buffer_ = cast(T[]) allocator_.allocate(size * T.sizeof);
    }

    /// Ditto.
    this(shared Allocator allocator)
    in
    {
        assert(allocator_ is null);
    }
    body
    {
        allocator_ = allocator;
    }

    /**
     * Deallocates the internal buffer.
     */
    ~this() @trusted
    {
        allocator.deallocate(buffer_);
    }

    ///
    unittest
    {
        ReadBuffer!ubyte b;
        assert(b.capacity == 0);
        assert(b.length == 0);
    }

    /**
     * Returns: The size of the internal buffer.
     */
    @property size_t capacity() const
    {
        return buffer_.length;
    }

    /**
     * Returns: Data size.
     */
    @property size_t length() const
    {
        return length_ - start;
    }

    /// Ditto.
    alias opDollar = length;

    /**
     * Clears the buffer.
     *
     * Returns: $(D_KEYWORD this).
     */
    void clear()
    {
        start = length_ = ring;
    }

    /**
     * Returns: Available space.
     */
    @property size_t free() const
    {
        return length > ring ? capacity - length : capacity - ring;
    }

    ///
    unittest
    {
        ReadBuffer!ubyte b;
        size_t numberRead;

        assert(b.free == 0);

        // Fills the buffer with values 0..10
        numberRead = fillBuffer(b[], b.free, 0, 10);
        b += numberRead;
        assert(b.free == b.blockSize - numberRead);
        b.clear();
        assert(b.free == b.blockSize);
    }

    /**
     * Appends some data to the buffer.
     *
     * Params:
     *  length = Number of the bytes read.
     *
     * Returns: $(D_KEYWORD this).
     */
    ref ReadBuffer opOpAssign(string op)(in size_t length)
        if (op == "+")
    {
        length_ += length;
        ring = start;
        return this;
    }

    ///
    unittest
    {
        ReadBuffer!ubyte b;
        size_t numberRead;
        ubyte[] result;

        // Fills the buffer with values 0..10
        numberRead = fillBuffer(b[], b.free, 0, 10);
        b += numberRead;

        result = b[0 .. $];
        assert(result[0] == 0);
        assert(result[1] == 1);
        assert(result[9] == 9);
        b.clear();

        // It shouldn't overwrite, but append another 5 bytes to the buffer
        numberRead = fillBuffer(b[], b.free, 0, 10);
        b += numberRead;

        numberRead = fillBuffer(b[], b.free, 20, 25);
        b += numberRead;

        result = b[0..$];
        assert(result[0] == 0);
        assert(result[1] == 1);
        assert(result[9] == 9);
        assert(result[10] == 20);
        assert(result[14] == 24);
    }

    /**
     * Params:
     *  start = Start position.
     *  end   = End position.
     *
     * Returns: Array between $(D_PARAM start) and $(D_PARAM end).
     */
    T[] opSlice(in size_t start, in size_t end)
    {
        return buffer_[this.start + start .. this.start + end];
    }

    /**
     * Returns a free chunk of the buffer.
     *
     * Add ($(D_KEYWORD +=)) the number of the read bytes after using it.
     *
     * Returns: A free chunk of the buffer.
     */
    T[] opIndex()
    {
        if (start > 0)
        {
            auto ret = buffer_[0 .. start];
            ring = 0;
            return ret;
        }
        else
        {
            if (capacity - length < minAvailable)
            {
                void[] buf = buffer_;
                immutable cap = capacity;
                () @trusted {
                    allocator.reallocate(buf, (cap + blockSize) * T.sizeof);
                    buffer_ = cast(T[]) buf;
                }();
            }
            ring = length_;
            return buffer_[length_ .. $];
        }
    }

    ///
    unittest
    {
        ReadBuffer!ubyte b;
        size_t numberRead;
        ubyte[] result;

        // Fills the buffer with values 0..10
        numberRead = fillBuffer(b[], b.free, 0, 10);
        b += numberRead;

        assert(b.length == 10);
        result = b[0 .. $];
        assert(result[0] == 0);
        assert(result[9] == 9);
        b.clear();
        assert(b.length == 0);
    }

    mixin DefaultAllocator;
}

private unittest
{
    static assert(is(ReadBuffer!int));
}

/**
 * Circular, self-expanding buffer with overflow support. Can be used with
 * functions returning the number of the transferred bytes.
 *
 * The buffer is optimized for situations where you read all the data from it
 * at once (without writing to it occasionally). It can become ineffective if
 * you permanently keep some data in the buffer and alternate writing and
 * reading, because it may allocate and move elements.
 *
 * Params:
 *  T = Buffer type.
 */
struct WriteBuffer(T = ubyte)
    if (isScalarType!T)
{
    /// Internal buffer.
    private T[] buffer_;

    /// Buffer start position.
    private size_t start;

    /// Buffer ring area size. After this position begins buffer overflow area.
    private size_t ring;

    /// Size by which the buffer will grow.
    private immutable size_t blockSize;

    /// The position of the free area in the buffer.
    private size_t position;

    invariant
    {
        assert(blockSize > 0);
        // Position can refer to an element outside the buffer if the buffer is full.
        assert(position <= buffer_.length);
    }

    /**
     * Params:
     *  size      = Initial buffer size and the size by which the buffer will
     *              grow.
     *  allocator = Allocator.
     *
     * Precondition: $(D_INLINECODE size > 0 && allocator !is null)
     */
    this(in size_t size, shared Allocator allocator = defaultAllocator) @trusted
    in
    {
        assert(size > 0);
        assert(allocator !is null);
    }
    body
    {
        blockSize = size;
        ring = size - 1;
        allocator_ = allocator;
        buffer_ = cast(T[]) allocator_.allocate(size * T.sizeof);
    }

    @disable this();

    /**
     * Deallocates the internal buffer.
     */
    ~this()
    {
        allocator.deallocate(buffer_);
    }

    /**
     * Returns: The size of the internal buffer.
     */
    @property size_t capacity() const
    {
        return buffer_.length;
    }

    /**
     * Note that $(D_PSYMBOL length) doesn't return the real length of the data,
     * but only the array length that will be returned with $(D_PSYMBOL opIndex)
     * next time. Be sure to call $(D_PSYMBOL opIndex) and set $(D_KEYWORD +=)
     * until $(D_PSYMBOL length) returns 0.
     *
     * Returns: Data size.
     */
    @property size_t length() const
    {
        if (position > ring || position < start) // Buffer overflowed
        {
            return ring - start + 1;
        }
        else
        {
            return position - start;
        }
    }

    /// Ditto.
    alias opDollar = length;

    ///
    unittest
    {
        auto b = WriteBuffer!ubyte(4);
        ubyte[3] buf = [48, 23, 255];

        b ~= buf;
        assert(b.length == 3);
        b += 2;
        assert(b.length == 1);

        b ~= buf;
        assert(b.length == 2);
        b += 2;
        assert(b.length == 2);

        b ~= buf;
        assert(b.length == 5);
        b += b.length;
        assert(b.length == 0);
    }

    /**
     * Returns: Available space.
     */
    @property size_t free() const
    {
        return capacity - length;
    }

    /**
     * Appends data to the buffer.
     *
     * Params:
     *  buffer = Buffer chunk got with $(D_PSYMBOL opIndex).
     */
    ref WriteBuffer opOpAssign(string op)(in T[] buffer)
        if (op == "~")
    {
        size_t end, start;

        if (position >= this.start && position <= ring)
        {
            auto afterRing = ring + 1;

            end = position + buffer.length;
            if (end > afterRing)
            {
                end = afterRing;
            }
            start = end - position;
            buffer_[position .. end] = buffer[0 .. start];
            if (end == afterRing)
            {
                position = this.start == 0 ? afterRing : 0;
            }
            else
            {
                position = end;
            }
        }

        // Check if we have some free space at the beginning
        if (start < buffer.length && position < this.start)
        {
            end = position + buffer.length - start;
            if (end > this.start)
            {
                end = this.start;
            }
            auto areaEnd = end - position + start;
            buffer_[position .. end] = buffer[start .. areaEnd];
            position = end == this.start ? ring + 1 : end - position;
            start = areaEnd;
        }

        // And if we still haven't found any place, save the rest in the overflow area
        if (start < buffer.length)
        {
            end = position + buffer.length - start;
            if (end > capacity)
            {
                auto newSize = (end / blockSize * blockSize + blockSize) * T.sizeof;
                () @trusted {
                    void[] buf = buffer_;
                    allocator.reallocate(buf, newSize);
                    buffer_ = cast(T[]) buf;
                }();
            }
            buffer_[position .. end] = buffer[start .. $];
            position = end;
            if (this.start == 0)
            {
                ring = capacity - 1;
            }
        }

        return this;
    }

    ///
    unittest
    {
        auto b = WriteBuffer!ubyte(4);
        ubyte[3] buf = [48, 23, 255];

        b ~= buf;
        assert(b.capacity == 4);
        assert(b.buffer_[0] == 48 && b.buffer_[1] == 23 && b.buffer_[2] == 255);

        b += 2;
        b ~= buf;
        assert(b.capacity == 4);
        assert(b.buffer_[0] == 23 && b.buffer_[1] == 255
            && b.buffer_[2] == 255 && b.buffer_[3] == 48);

        b += 2;
        b ~= buf;
        assert(b.capacity == 8);
        assert(b.buffer_[0] == 23 && b.buffer_[1] == 255
            && b.buffer_[2] == 48 && b.buffer_[3] == 23 && b.buffer_[4] == 255);
    }

    ///
    unittest
    {
        auto b = WriteBuffer!ubyte(2);
        ubyte[3] buf = [48, 23, 255];

        b ~= buf;
        assert(b.start == 0);
        assert(b.capacity == 4);
        assert(b.ring == 3);
        assert(b.position == 3);
    }

    /**
     * Sets how many bytes were written. It will shrink the buffer
     * appropriately. Always call it after $(D_PSYMBOL opIndex).
     *
     * Params:
     *  length = Length of the written data.
     *
     * Returns: $(D_KEYWORD this).
     */
    ref WriteBuffer opOpAssign(string op)(in size_t length)
        if (op == "+")
    in
    {
        assert(length <= this.length);
    }
    body
    {
        auto afterRing = ring + 1;
        auto oldStart = start;

        if (length <= 0)
        {
            return this;
        }
        else if (position <= afterRing)
        {
            start += length;
            if (start > 0 && position == afterRing)
            {
                position = oldStart;
            }
        }
        else
        {
            auto overflow = position - afterRing;

            if (overflow > length)
            {
                immutable afterLength = afterRing + length;
                buffer_[start .. start + length] = buffer_[afterRing .. afterLength];
                buffer_[afterRing .. afterLength] = buffer_[afterLength .. position];
                position -= length;
            }
            else if (overflow == length)
            {
                buffer_[start .. start + overflow] = buffer_[afterRing .. position];
                position -= overflow;
            }
            else
            {
                buffer_[start .. start + overflow] = buffer_[afterRing .. position];
                position = overflow;
            }
            start += length;

            if (start == position)
            {
                if (position != afterRing)
                {
                    position = 0;
                }
                start = 0;
                ring = capacity - 1;
            }
        }
        if (start > ring)
        {
            start = 0;
        }
        return this;
    }

    ///
    unittest
    {
        auto b = WriteBuffer!ubyte(6);
        ubyte[6] buf = [23, 23, 255, 128, 127, 9];

        b ~= buf;
        assert(b.length == 6);
        b += 2;
        assert(b.length == 4);
        b += 4;
        assert(b.length == 0);
    }

    /**
     * Returns a chunk with data.
     *
     * After calling it, set $(D_KEYWORD +=) to the length could be
     * written.
     *
     * $(D_PSYMBOL opIndex) may return only part of the data. You may need
     * to call it and set $(D_KEYWORD +=) several times until
     * $(D_PSYMBOL length) is 0. If all the data can be written,
     * maximally 3 calls are required.
     *
     * Returns: A chunk of data buffer.
     */
    T[] opSlice(in size_t start, in size_t end)
    {
        immutable internStart = this.start + start;

        if (position > ring || position < start) // Buffer overflowed
        {
            return buffer_[this.start .. ring + 1 - length + end];
        }
        else
        {
            return buffer_[this.start .. this.start + end];
        }
    }

    ///
    unittest
    {
        auto b = WriteBuffer!ubyte(6);
        ubyte[6] buf = [23, 23, 255, 128, 127, 9];

        b ~= buf;
        assert(b[0 .. $] == buf[0 .. 6]);
        b += 2;

        assert(b[0 .. $] == buf[2 .. 6]);

        b ~= buf;
        assert(b[0 .. $] == buf[2 .. 6]);
        b += b.length;

        assert(b[0 .. $] == buf[0 .. 6]);
        b += b.length;
    }

    /**
     * After calling it, set $(D_KEYWORD +=) to the length could be
     * written.
     *
     * $(D_PSYMBOL opIndex) may return only part of the data. You may need
     * to call it and set $(D_KEYWORD +=) several times until
     * $(D_PSYMBOL length) is 0. If all the data can be written,
     * maximally 3 calls are required.
     *
     * Returns: A chunk of data buffer.
     */
    T[] opIndex()
    {
        return opSlice(0, length);
    }

    mixin DefaultAllocator;
}

private unittest
{
    static assert(is(typeof(WriteBuffer!int(5))));
}
