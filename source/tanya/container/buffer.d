/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * Copyright: Eugene Wissner 2016.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 */  
module tanya.container.buffer;

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
 */
class ReadBuffer
{
    /// Internal buffer.
    protected ubyte[] buffer_;

    /// Filled buffer length.
    protected size_t length_;

    /// Start of available data.
    protected size_t start;

    /// Last position returned with $(D_KEYWORD []).
    protected size_t ring;

    /// Available space.
    protected immutable size_t minAvailable;

    /// Size by which the buffer will grow.
    protected immutable size_t blockSize;

	/// Allocator.
	protected shared Allocator allocator;

    @nogc invariant
    {
        assert(length_ <= buffer_.length);
        assert(blockSize > 0);
        assert(minAvailable > 0);
		assert(allocator !is null);
    }

    /**
     * Creates a new read buffer.
     *
     * Params:
     * 	size         = Initial buffer size and the size by which the buffer
     * 	               will grow.
     * 	minAvailable = minimal size should be always  available to fill.
     * 	               So it will reallocate if $(D_INLINECODE 
     * 	               $(D_PSYMBOL free) < $(D_PARAM minAvailable)).
	 * 	allocator    = Allocator.
     */
    this(size_t size = 8192,
         size_t minAvailable = 1024,
	     shared Allocator allocator = defaultAllocator) @nogc
    {
        this.minAvailable = minAvailable;
        this.blockSize = size;
		this.allocator = allocator;
        allocator.resizeArray!ubyte(buffer_, size);
    }

    /**
     * Deallocates the internal buffer.
     */
    ~this() @nogc
    {
        allocator.dispose(buffer_);
    }

    ///
    unittest
    {
        auto b = defaultAllocator.make!ReadBuffer;
        assert(b.capacity == 8192);
        assert(b.length == 0);

        defaultAllocator.dispose(b);
    }

    /**
     * Returns: The size of the internal buffer.
     */
    @property size_t capacity() const @nogc @safe pure nothrow
    {
        return buffer_.length;
    }

    /**
     * Returns: Data size.
     */
    @property size_t length() const @nogc @safe pure nothrow
    {
        return length_ - start;
    }

    /**
     * Clears the buffer.
     *
     * Returns: $(D_KEYWORD this).
     */
    ReadBuffer clear() pure nothrow @safe @nogc
    {
        start = length_ = ring;
        return this;
    }

    /**
     * Returns: Available space.
     */
    @property size_t free() const pure nothrow @safe @nogc
    {
        return length > ring ? capacity - length : capacity - ring;
    }

    ///
    unittest
    {
        auto b = defaultAllocator.make!ReadBuffer;
        size_t numberRead;

        // Fills the buffer with values 0..10
        assert(b.free == b.blockSize);

        numberRead = fillBuffer(b[], b.free, 0, 10);
        b += numberRead;
        assert(b.free == b.blockSize - numberRead);
        b.clear();
        assert(b.free == b.blockSize);

        defaultAllocator.dispose(b);
    }

    /**
     * Appends some data to the buffer.
     *
     * Params:
     *     length = Number of the bytes read.
     *
     * Returns: $(D_KEYWORD this).
     */
    ReadBuffer opOpAssign(string op)(size_t length) @nogc
        if (op == "+")
    {
        length_ += length;
        ring = start;
        return this;
    }

    ///
    unittest
    {
        auto b = defaultAllocator.make!ReadBuffer;
        size_t numberRead;
        ubyte[] result;

        // Fills the buffer with values 0..10
        numberRead = fillBuffer(b[], b.free, 0, 10);
        b += numberRead;

        result = b[0..$];
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

        defaultAllocator.dispose(b);
    }

    /**
     * Returns: Length of available data.
     */
    @property size_t opDollar() const pure nothrow @safe @nogc
    {
        return length;
    }

    /**
     * Params:
     *     start = Start position.
     *     end   = End position.
     *
     * Returns: Array between $(D_PARAM start) and $(D_PARAM end).
     */
    @property ubyte[] opSlice(size_t start, size_t end) pure nothrow @safe @nogc
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
    ubyte[] opIndex() @nogc
    {
        if (start > 0)
        {
            auto ret = buffer_[0..start];
            ring = 0;
            return ret;
        }
        else
        {
            if (capacity - length < minAvailable)
            {
                allocator.resizeArray!ubyte(buffer_, capacity + blockSize);
            }
            ring = length_;
            return buffer_[length_..$];
        }
    }

    ///
    unittest
    {
        auto b = defaultAllocator.make!ReadBuffer;
        size_t numberRead;
        ubyte[] result;

        // Fills the buffer with values 0..10
        numberRead = fillBuffer(b[], b.free, 0, 10);
        b += numberRead;

        assert(b.length == 10);
        result = b[0..$];
        assert(result[0] == 0);
        assert(result[9] == 9);
        b.clear();
        assert(b.length == 0);

        defaultAllocator.dispose(b);
    }
}

/**
 * Circular, self-expanding buffer with overflow support. Can be used with
 * functions returning returning the number of the transferred bytes.
 *
 * The buffer is optimized for situations where you read all the data from it
 * at once (without writing to it occasionally). It can become ineffective if
 * you permanently keep some data in the buffer and alternate writing and
 * reading, because it may allocate and move elements.
 */
class WriteBuffer
{
    /// Internal buffer.
    protected ubyte[] buffer_;

    /// Buffer start position.
    protected size_t start;

    /// Buffer ring area size. After this position begins buffer overflow area.
    protected size_t ring;

    /// Size by which the buffer will grow.
    protected immutable size_t blockSize;

    /// The position of the free area in the buffer.
    protected size_t position;

	/// Allocator.
	protected shared Allocator allocator;

    @nogc invariant
    {
        assert(blockSize > 0);
        // position can refer to an element outside the buffer if the buffer is full.
        assert(position <= buffer_.length);
		assert(allocator !is null);
    }

    /**
     * Params:
     *  size      = Initial buffer size and the size by which the buffer will
     * 	            grow.
	 * 	allocator = Allocator.
     */
    this(size_t size = 8192, shared Allocator allocator = defaultAllocator)
	@nogc
    {
		this.allocator = allocator;
        blockSize = size;
        ring = size - 1;
        allocator.resizeArray!ubyte(buffer_, size);
    }

    /**
     * Deallocates the internal buffer.
     */
    ~this() @nogc
    {
        allocator.dispose(buffer_);
    }

    /**
     * Returns: The size of the internal buffer.
     */
    @property size_t capacity() const @nogc @safe pure nothrow
    {
        return buffer_.length;
    }

    /**
     * Note that $(D_PSYMBOL length) doesn't return the real length of the data,
     * but only the array length that will be returned with $(D_PSYMBOL buffer)
     * next time. Be sure to call $(D_PSYMBOL buffer) and set $(D_KEYWORD +=)
     * until $(D_PSYMBOL length) returns 0.
     *
     * Returns: Data size.
     */
    @property size_t length() const @nogc @safe pure nothrow
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

    /**
    * Returns: Length of available data.
    */
    @property size_t opDollar() const pure nothrow @safe @nogc
    {
        return length;
    }

    ///
    unittest
    {
        auto b = defaultAllocator.make!WriteBuffer(4);
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

        defaultAllocator.dispose(b);
    }

    /**
     * Returns: Available space.
     */
    @property size_t free() const @nogc @safe pure nothrow
    {
        return capacity - length;
    }

    /**
     * Appends data to the buffer.
     *
     * Params:
     *     buffer = Buffer chunk got with $(D_PSYMBOL buffer).
     */
    WriteBuffer opOpAssign(string op)(ubyte[] buffer) @nogc
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
            buffer_[position..end] = buffer[0..start];
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
            buffer_[position..end] = buffer[start..areaEnd];
            position = end == this.start ? ring + 1 : end - position;
            start = areaEnd;
        }

        // And if we still haven't found any place, save the rest in the overflow area
        if (start < buffer.length)
        {
            end = position + buffer.length - start;
            if (end > capacity)
            {
                auto newSize = end / blockSize * blockSize + blockSize;

                allocator.resizeArray!ubyte(buffer_, newSize);
            }
            buffer_[position..end] = buffer[start..$];
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
        auto b = defaultAllocator.make!WriteBuffer(4);
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

        defaultAllocator.dispose(b);

        b = make!WriteBuffer(defaultAllocator, 2);

        b ~= buf;
        assert(b.start == 0);
        assert(b.capacity == 4);
        assert(b.ring == 3);
        assert(b.position == 3);

        defaultAllocator.dispose(b);
    }

    /**
     * Sets how many bytes were written. It will shrink the buffer
     * appropriately. Always set this property after calling
     * $(D_PSYMBOL buffer).
     *
     * Params:
     *     length = Length of the written data.
     *
     * Returns: $(D_KEYWORD this).
     */
    @property WriteBuffer opOpAssign(string op)(size_t length) pure nothrow @safe @nogc
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

            if (overflow > length) {
                buffer_[start.. start + length] = buffer_[afterRing.. afterRing + length];
                buffer_[afterRing.. afterRing + length] = buffer_[afterRing + length ..position];
                position -= length;
            }
            else if (overflow == length)
            {
                buffer_[start.. start + overflow] = buffer_[afterRing..position];
                position -= overflow;
            }
            else
            {
                buffer_[start.. start + overflow] = buffer_[afterRing..position];
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
        auto b = defaultAllocator.make!WriteBuffer;
        ubyte[6] buf = [23, 23, 255, 128, 127, 9];

        b ~= buf;
        assert(b.length == 6);
        b += 2;
        assert(b.length == 4);
        b += 4;
        assert(b.length == 0);

        defaultAllocator.dispose(b);
    }

    /**
     * Returns a chunk with data.
     *
     * After calling it, set $(D_KEYWORD +=) to the length could be
     * written.
     *
     * $(D_PSYMBOL buffer) may return only part of the data. You may need
     * to call it (and set $(D_KEYWORD +=) several times until
     * $(D_PSYMBOL length) is 0. If all the data can be written,
     * maximally 3 calls are required.
     *
     * Returns: A chunk of data buffer.
     */
    @property ubyte[] opSlice(size_t start, size_t end) pure nothrow @safe @nogc
    {
        immutable internStart = this.start + start;

        if (position > ring || position < start) // Buffer overflowed
        {
            return buffer_[this.start.. ring + 1 - length + end];
        }
        else
        {
            return buffer_[this.start.. this.start + end];
        }
    }

    ///
    unittest
    {
        auto b = defaultAllocator.make!WriteBuffer(6);
        ubyte[6] buf = [23, 23, 255, 128, 127, 9];

        b ~= buf;
        assert(b[0..$] == buf[0..6]);
        b += 2;

        assert(b[0..$] == buf[2..6]);

        b ~= buf;
        assert(b[0..$] == buf[2..6]);
        b += b.length;

        assert(b[0..$] == buf[0..6]);
        b += b.length;

        defaultAllocator.dispose(b);
    }

    /**
     * After calling it, set $(D_KEYWORD +=) to the length could be
     * written.
     *
     * $(D_PSYMBOL buffer) may return only part of the data. You may need
     * to call it (and set $(D_KEYWORD +=) several times until
     * $(D_PSYMBOL length) is 0. If all the data can be written,
     * maximally 3 calls are required.
     *
     * Returns: A chunk of data buffer.
     */
    @property ubyte[] opIndex() pure nothrow @safe @nogc
    {
        return opSlice(0, length);
    }
}
