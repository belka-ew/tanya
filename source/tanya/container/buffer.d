/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * Copyright: Eugene Wissner 2016.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:belka@caraus.de, Eugene Wissner)
 */  
module tanya.container.buffer;

import tanya.memory;

@nogc:

version (unittest)
{
	private int fillBuffer(void* buffer,
	                       in size_t size,
	                       int start = 0,
	                       int end = 10)
	in
	{
		assert(start < end);
	}
	body
	{
		ubyte[] buf = cast(ubyte[]) buffer[0..size];
		auto numberRead = end - start;

		for (ubyte i; i < numberRead; ++i)
		{
			buf[i] = cast(ubyte) (start + i);
		}
		return numberRead;
	}
}

/**
 * Interface for implemeting input/output buffers.
 */
interface Buffer
{
@nogc:
	/**
	 * Returns: The size of the internal buffer.
	 */
	@property size_t capacity() const @safe pure nothrow;

	/**
	 * Returns: Data size.
	 */
	@property size_t length() const @safe pure nothrow;

	/**
	 * Returns: Available space.
	 */
	@property size_t free() const @safe pure nothrow;

	/**
	 * Appends some data to the buffer.
	 *
	 * Params:
	 * 	buffer = Buffer chunk got with $(D_PSYMBOL buffer).
	 */
	Buffer opOpAssign(string op)(void[] buffer)
		if (op == "~");
}

/**
 * Buffer that can be used with C functions accepting void pointer and
 * returning the number of the read bytes.
 */
class ReadBuffer : Buffer
{
@nogc:
	/// Internal buffer.
	protected ubyte[] _buffer;

	/// Filled buffer length.
	protected size_t _length;

	/// Available space.
	protected immutable size_t minAvailable;

	/// Size by which the buffer will grow.
	protected immutable size_t blockSize;

	private Allocator allocator;

	invariant
	{
		assert(_length <= _buffer.length);
		assert(blockSize > 0);
		assert(minAvailable > 0);
	}

	/**
	 * Params:
	 *  size         = Initial buffer size and the size by which the buffer
	 * 	               will grow.
	 * 	minAvailable = minimal size should be always  available to fill.
	 * 	               So it will reallocate if $(D_INLINECODE 
	 * 	               $(D_PSYMBOL free) < $(D_PARAM minAvailable)
	 * 	               ).
	 */
	this(size_t size = 8192,
	     size_t minAvailable = 1024,
	     Allocator allocator = defaultAllocator)
	{
		this.allocator = allocator;
		this.minAvailable = minAvailable;
		this.blockSize = size;
		resizeArray!ubyte(this.allocator, _buffer, size);
	}

	/**
	 * Deallocates the internal buffer.
	 */
	~this()
	{
		finalize(allocator, _buffer);
	}

	///
	unittest
	{
		auto b = make!ReadBuffer(defaultAllocator);
		assert(b.capacity == 8192);
		assert(b.length == 0);

		finalize(defaultAllocator, b);
	}

	/**
	 * Returns: The size of the internal buffer.
	 */
	@property size_t capacity() const @safe pure nothrow
	{
		return _buffer.length;
	}

	/**
	 * Returns: Data size.
	 */
	@property size_t length() const @safe pure nothrow
	{
		return _length;
	}

	/**
	 * Returns: Available space.
	 */
	@property size_t free() const @safe pure nothrow
	{
		return capacity - length;
	}

	///
	unittest
	{
		auto b = make!ReadBuffer(defaultAllocator);
		size_t numberRead;
		void* buf;

		// Fills the buffer with values 0..10
		assert(b.free == b.blockSize);
		buf =  b.buffer;
		numberRead = fillBuffer(buf, b.free, 0, 10);
		b ~= buf[0..numberRead];
		assert(b.free == b.blockSize - numberRead);
		b[];
		assert(b.free == b.blockSize);

		finalize(defaultAllocator, b);
	}

	/**
	 * Returns a pointer to a chunk of the internal buffer. You can pass it to
	 * a function that requires such a buffer.
	 *
	 * Set the buffer again after reading something into it. Append
	 * $(D_KEYWORD ~=) a slice from the beginning of the buffer you got and
	 * till the number of the read bytes. The data will be appended to the
	 * existing buffer.
	 *
	 * Returns: A chunk of available buffer.
	 */
	@property void* buffer()
	{
		if (capacity - length < minAvailable)
		{
			resizeArray!ubyte(this.allocator, _buffer, capacity + blockSize);
		}
		return _buffer[_length..$].ptr;
	}

	/**
	 * Appends some data to the buffer. Use only the buffer you got
	 * with $(D_PSYMBOL buffer)!
	 *
	 * Params:
	 * 	buffer = Buffer chunk got with $(D_PSYMBOL buffer).
	 */
	ReadBuffer opOpAssign(string op)(void[] buffer)
		if (op == "~")
	{
		_length += buffer.length;
		return this;
	}

	///
	unittest
	{
		auto b = make!ReadBuffer(defaultAllocator);
		size_t numberRead;
		void* buf;
		ubyte[] result;

		// Fills the buffer with values 0..10
		buf =  b.buffer;
		numberRead = fillBuffer(buf, b.free, 0, 10);
		b ~= buf[0..numberRead];

		result = b[];
		assert(result[0] == 0);
		assert(result[1] == 1);
		assert(result[9] == 9);

		// It shouldn't overwrite, but append another 5 bytes to the buffer
		buf =  b.buffer;
		numberRead = fillBuffer(buf, b.free, 0, 10);
		b ~= buf[0..numberRead];

		buf =  b.buffer;
		numberRead = fillBuffer(buf, b.free, 20, 25);
		b ~= buf[0..numberRead];

		result = b[];
		assert(result[0] == 0);
		assert(result[1] == 1);
		assert(result[9] == 9);
		assert(result[10] == 20);
		assert(result[14] == 24);

		finalize(defaultAllocator, b);
	}

	/**
	 * Returns the buffer. The buffer is cleared after that. So you can get it
	 * only one time.
	 *
	 * Returns: The buffer as array.
	 */
	@property ubyte[] opIndex()
	{
		auto ret = _buffer[0.._length];
		_length = 0;
		return ret;
	}

	///
	unittest
	{
		auto b = make!ReadBuffer(defaultAllocator);
		size_t numberRead;
		void* buf;
		ubyte[] result;

		// Fills the buffer with values 0..10
		buf =  b.buffer;
		numberRead = fillBuffer(buf, b.free, 0, 10);
		b ~= buf[0..numberRead];

		assert(b.length == 10);
		result = b[];
		assert(result[0] == 0);
		assert(result[9] == 9);
		assert(b.length == 0);

		finalize(defaultAllocator, b);
	}
}

/**
 * Circular, self-expanding buffer that can be used with C functions accepting
 * void pointer and returning the number of the read bytes.
 *
 * The buffer is optimized for situations where you read all the data from it
 * at once (without writing to it occasionally). It can become ineffective if
 * you permanently keep some data in the buffer and alternate writing and
 * reading, because it may allocate and move elements.
 */
class WriteBuffer : Buffer
{
@nogc:
	/// Internal buffer.
	protected ubyte[] _buffer;

	/// Buffer start position.
	protected size_t start;

	/// Buffer ring area size. After this position begins buffer overflow area.
	protected size_t ring;

	/// Size by which the buffer will grow.
	protected immutable size_t blockSize;

	/// The position of the free area in the buffer.
	protected size_t position;

	private Allocator allocator;

	invariant
	{
		assert(blockSize > 0);
		// position can refer to an element outside the buffer if the buffer is full.
		assert(position <= _buffer.length);
	}

	/**
	 * Params:
	 *  size = Initial buffer size and the size by which the buffer
	 * 	       will grow.
	 */
	this(size_t size = 8192,
	     Allocator allocator = defaultAllocator)
	{
		this.allocator = allocator;
		blockSize = size;
		ring = size - 1;
		resizeArray!ubyte(this.allocator, _buffer, size);
	}

	/**
	 * Deallocates the internal buffer.
	 */
	~this()
	{
		finalize(allocator, _buffer);
	}

	/**
	 * Returns: The size of the internal buffer.
	 */
	@property size_t capacity() const @safe pure nothrow
	{
		return _buffer.length;
	}

	/**
	 * Note that $(D_PSYMBOL length) doesn't return the real length of the data,
	 * but only the array length that will be returned with $(D_PSYMBOL buffer)
	 * next time. Be sure to call $(D_PSYMBOL buffer) and set $(D_PSYMBOL written)
	 * until $(D_PSYMBOL length) returns 0.
	 *
	 * Returns: Data size.
	 */
	@property size_t length() const @safe pure nothrow
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

	///
	unittest
	{
		auto b = make!WriteBuffer(defaultAllocator, 4);
		ubyte[3] buf = [48, 23, 255];

		b ~= buf;
		assert(b.length == 3);
		b.written = 2;
		assert(b.length == 1);

		b ~= buf;
		assert(b.length == 2);
		b.written = 2;
		assert(b.length == 2);

		b ~= buf;
		assert(b.length == 5);
		b.written = b.length;
		assert(b.length == 0);

		finalize(defaultAllocator, b);
	}

	/**
	 * Returns: Available space.
	 */
	@property size_t free() const @safe pure nothrow
	{
		return capacity - length;
	}

	/**
	 * Appends data to the buffer.
	 *
	 * Params:
	 * 	buffer = Buffer chunk got with $(D_PSYMBOL buffer).
	 */
	WriteBuffer opOpAssign(string op)(ubyte[] buffer)
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
			_buffer[position..end] = buffer[0..start];
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
			_buffer[position..end] = buffer[start..areaEnd];
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

				resizeArray!ubyte(this.allocator, _buffer, newSize);
			}
			_buffer[position..end] = buffer[start..$];
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
		auto b = make!WriteBuffer(defaultAllocator, 4);
		ubyte[3] buf = [48, 23, 255];

		b ~= buf;
		assert(b.capacity == 4);
		assert(b._buffer[0] == 48 && b._buffer[1] == 23 && b._buffer[2] == 255);

		b.written = 2;
		b ~= buf;
		assert(b.capacity == 4);
		assert(b._buffer[0] == 23 && b._buffer[1] == 255
		    && b._buffer[2] == 255 && b._buffer[3] == 48);

		b.written = 2;
		b ~= buf;
		assert(b.capacity == 8);
		assert(b._buffer[0] == 23 && b._buffer[1] == 255
		    && b._buffer[2] == 48 && b._buffer[3] == 23 && b._buffer[4] == 255);

		finalize(defaultAllocator, b);

		b = make!WriteBuffer(defaultAllocator, 2);

		b ~= buf;
		assert(b.start == 0);
		assert(b.capacity == 4);
		assert(b.ring == 3);
		assert(b.position == 3);

		finalize(defaultAllocator, b);
	}

	/**
	 * Sets how many bytes were written. It will shrink the buffer
	 * appropriately. Always set this property after calling
	 * $(D_PSYMBOL buffer).
	 *
	 * Params:
	 * 	length = Length of the written data.
	 */
	@property void written(size_t length) @safe pure nothrow
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
			return;
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
                _buffer[start.. start + length] = _buffer[afterRing.. afterRing + length];
                _buffer[afterRing.. afterRing + length] = _buffer[afterRing + length ..position];
                position -= length;
            }
            else if (overflow == length)
            {
                _buffer[start.. start + overflow] = _buffer[afterRing..position];
                position -= overflow;
            }
            else
            {
                _buffer[start.. start + overflow] = _buffer[afterRing..position];
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
	}

	///
	unittest
	{
		auto b = make!WriteBuffer(defaultAllocator);
		ubyte[6] buf = [23, 23, 255, 128, 127, 9];

		b ~= buf;
		assert(b.length == 6);
		b.written = 2;
		assert(b.length == 4);
		b.written = 4;
		assert(b.length == 0);

		finalize(defaultAllocator, b);
	}

	/**
	 * Returns a pointer to a buffer chunk with data. You can pass it to
	 * a function that requires such a buffer.
	 *
	 * After calling it, set $(D_PSYMBOL written) to the length could be
	 * written.
	 *
	 * $(D_PSYMBOL buffer) may return only part of the data. You may need
	 * to call it (and set $(D_PSYMBOL written) several times until
	 * $(D_PSYMBOL length) is 0. If all the data can be written,
	 * maximally 3 calls are required.
	 *
	 * Returns: A chunk of data buffer.
	 */
	@property void* buffer() @safe pure nothrow
	{
		if (position > ring || position < start) // Buffer overflowed
		{
			return _buffer[start.. ring + 1].ptr;
		}
		else
		{
			return _buffer[start..position].ptr;
		}
	}

	///
	unittest
	{
		auto b = make!WriteBuffer(defaultAllocator, 6);
		ubyte[6] buf = [23, 23, 255, 128, 127, 9];
		void* returnedBuf;

		b ~= buf;
		returnedBuf = b.buffer;
		assert(returnedBuf[0..b.length] == buf[0..6]);
		b.written = 2;

		returnedBuf = b.buffer;
		assert(returnedBuf[0..b.length] == buf[2..6]);

		b ~= buf;
		returnedBuf = b.buffer;
		assert(returnedBuf[0..b.length] == buf[2..6]);
		b.written = b.length;

		returnedBuf = b.buffer;
		assert(returnedBuf[0..b.length] == buf[0..6]);
		b.written = b.length;

		finalize(defaultAllocator, b);
	}
}
