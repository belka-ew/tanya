/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * This module contains buffers designed for C-style input/output APIs.
 *
 * Copyright: Eugene Wissner 2016-2020.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 * Source: $(LINK2 https://github.com/caraus-ecms/tanya/blob/master/source/tanya/container/buffer.d,
 *                 tanya/container/buffer.d)
 */
module tanya.container.buffer;

import tanya.memory.allocator;
import tanya.meta.trait;

version (unittest)
{
    private int fillBuffer(ubyte[] buffer,
                           int start = 0,
                           int end = 10) @nogc pure nothrow
    in (start < end)
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
    private size_t minAvailable = 1024;

    /// Size by which the buffer will grow.
    private size_t blockSize = 8192;

    invariant (this.length_ <= this.buffer_.length);
    invariant (this.blockSize > 0);
    invariant (this.minAvailable > 0);

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
    this(size_t size,
         size_t minAvailable = 1024,
         shared Allocator allocator = defaultAllocator) @trusted
    {
        this(allocator);
        this.minAvailable = minAvailable;
        this.blockSize = size;
        this.buffer_ = cast(T[]) allocator_.allocate(size * T.sizeof);
    }

    /// ditto
    this(shared Allocator allocator)
    in (allocator_ is null)
    {
        allocator_ = allocator;
    }

    /**
     * Deallocates the internal buffer.
     */
    ~this() @trusted
    {
        allocator.deallocate(this.buffer_);
    }

    ///
    @nogc nothrow pure @safe unittest
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
        return this.buffer_.length;
    }

    /**
     * Returns: Data size.
     */
    @property size_t length() const
    {
        return this.length_ - start;
    }

    /// ditto
    alias opDollar = length;

    /**
     * Clears the buffer.
     *
     * Returns: $(D_KEYWORD this).
     */
    void clear()
    {
        start = this.length_ = ring;
    }

    /**
     * Returns: Available space.
     */
    @property size_t free() const
    {
        return length > ring ? capacity - length : capacity - ring;
    }

    ///
    @nogc nothrow pure @system unittest
    {
        ReadBuffer!ubyte b;
        size_t numberRead;

        assert(b.free == 0);

        // Fills the buffer with values 0..10
        numberRead = fillBuffer(b[], 0, 10);
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
    ref ReadBuffer opOpAssign(string op)(size_t length)
    if (op == "+")
    {
        this.length_ += length;
        ring = start;
        return this;
    }

    ///
    @nogc nothrow pure @system unittest
    {
        ReadBuffer!ubyte b;
        size_t numberRead;
        ubyte[] result;

        // Fills the buffer with values 0..10
        numberRead = fillBuffer(b[], 0, 10);
        b += numberRead;

        result = b[0 .. $];
        assert(result[0] == 0);
        assert(result[1] == 1);
        assert(result[9] == 9);
        b.clear();

        // It shouldn't overwrite, but append another 5 bytes to the buffer
        numberRead = fillBuffer(b[], 0, 10);
        b += numberRead;

        numberRead = fillBuffer(b[], 20, 25);
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
    T[] opSlice(size_t start, size_t end)
    {
        return this.buffer_[this.start + start .. this.start + end];
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
            auto ret = this.buffer_[0 .. start];
            ring = 0;
            return ret;
        }
        else
        {
            if (capacity - length < this.minAvailable)
            {
                void[] buf = this.buffer_;
                const cap = capacity;
                () @trusted {
                    allocator.reallocate(buf,
                                         (cap + this.blockSize) * T.sizeof);
                    this.buffer_ = cast(T[]) buf;
                }();
            }
            ring = this.length_;
            return this.buffer_[this.length_ .. $];
        }
    }

    ///
    @nogc nothrow pure @system unittest
    {
        ReadBuffer!ubyte b;
        size_t numberRead;
        ubyte[] result;

        // Fills the buffer with values 0..10
        numberRead = fillBuffer(b[], 0, 10);
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
    private const size_t blockSize;

    /// The position of the free area in the buffer.
    private size_t position;

    invariant (this.blockSize > 0);
    // Position can refer to an element outside the buffer if the buffer is full.
    invariant (this.position <= this.buffer_.length);

    /**
     * Params:
     *  size      = Initial buffer size and the size by which the buffer will
     *              grow.
     *  allocator = Allocator.
     *
     * Precondition: $(D_INLINECODE size > 0 && allocator !is null)
     */
    this(size_t size, shared Allocator allocator = defaultAllocator) @trusted
    in (size > 0)
    in (allocator !is null)
    {
        this.blockSize = size;
        ring = size - 1;
        allocator_ = allocator;
        this.buffer_ = cast(T[]) allocator_.allocate(size * T.sizeof);
    }

    @disable this();

    /**
     * Deallocates the internal buffer.
     */
    ~this()
    {
        allocator.deallocate(this.buffer_);
    }

    /**
     * Returns: The size of the internal buffer.
     */
    @property size_t capacity() const
    {
        return this.buffer_.length;
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
        if (this.position > ring || this.position < start) // Buffer overflowed
        {
            return ring - start + 1;
        }
        else
        {
            return this.position - start;
        }
    }

    /// ditto
    alias opDollar = length;

    ///
    @nogc nothrow pure @system unittest
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
    ref WriteBuffer opOpAssign(string op)(const T[] buffer)
    if (op == "~")
    {
        size_t end, start;

        if (this.position >= this.start && this.position <= ring)
        {
            auto afterRing = ring + 1;

            end = this.position + buffer.length;
            if (end > afterRing)
            {
                end = afterRing;
            }
            start = end - this.position;
            this.buffer_[this.position .. end] = buffer[0 .. start];
            if (end == afterRing)
            {
                this.position = this.start == 0 ? afterRing : 0;
            }
            else
            {
                this.position = end;
            }
        }

        // Check if we have some free space at the beginning
        if (start < buffer.length && this.position < this.start)
        {
            end = this.position + buffer.length - start;
            if (end > this.start)
            {
                end = this.start;
            }
            auto areaEnd = end - this.position + start;
            this.buffer_[this.position .. end] = buffer[start .. areaEnd];
            this.position = end == this.start ? ring + 1 : end - this.position;
            start = areaEnd;
        }

        // And if we still haven't found any place, save the rest in the overflow area
        if (start < buffer.length)
        {
            end = this.position + buffer.length - start;
            if (end > capacity)
            {
                const newSize = end / this.blockSize * this.blockSize
                              + this.blockSize;
                () @trusted {
                    void[] buf = this.buffer_;
                    allocator.reallocate(buf, newSize * T.sizeof);
                    this.buffer_ = cast(T[]) buf;
                }();
            }
            this.buffer_[this.position .. end] = buffer[start .. $];
            this.position = end;
            if (this.start == 0)
            {
                ring = capacity - 1;
            }
        }

        return this;
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
    ref WriteBuffer opOpAssign(string op)(size_t length)
    if (op == "+")
    in (length <= this.length)
    {
        auto afterRing = ring + 1;
        auto oldStart = start;

        if (length <= 0)
        {
            return this;
        }
        else if (this.position <= afterRing)
        {
            start += length;
            if (start > 0 && this.position == afterRing)
            {
                this.position = oldStart;
            }
        }
        else
        {
            auto overflow = this.position - afterRing;

            if (overflow > length)
            {
                const afterLength = afterRing + length;
                this.buffer_[start .. start + length] = this.buffer_[afterRing .. afterLength];
                this.buffer_[afterRing .. afterLength] = this.buffer_[afterLength .. this.position];
                this.position -= length;
            }
            else if (overflow == length)
            {
                this.buffer_[start .. start + overflow] = this.buffer_[afterRing .. this.position];
                this.position -= overflow;
            }
            else
            {
                this.buffer_[start .. start + overflow] = this.buffer_[afterRing .. this.position];
                this.position = overflow;
            }
            start += length;

            if (start == this.position)
            {
                if (this.position != afterRing)
                {
                    this.position = 0;
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
    @nogc nothrow pure @system unittest
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
    T[] opSlice(size_t start, size_t end)
    {
        if (this.position > ring || this.position < start) // Buffer overflowed
        {
            return this.buffer_[this.start .. ring + 1 - length + end];
        }
        else
        {
            return this.buffer_[this.start .. this.start + end];
        }
    }

    ///
    @nogc nothrow pure @system unittest
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

@nogc nothrow pure @system unittest
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

@nogc nothrow pure @system unittest
{
    auto b = WriteBuffer!ubyte(2);
    ubyte[3] buf = [48, 23, 255];

    b ~= buf;
    assert(b.start == 0);
    assert(b.capacity == 4);
    assert(b.ring == 3);
    assert(b.position == 3);
}
