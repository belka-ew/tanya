/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * Copyright: Eugene Wissner 2016.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:belka@caraus.de, Eugene Wissner)
 */  
module tanya.math.mp;

import std.algorithm.iteration;
import std.algorithm.searching;
import std.algorithm.mutation;
import std.math;
import std.range;
import std.traits;
import tanya.memory;

struct Integer
{
    private RefCounted!(ubyte[]) rep;
	private bool sign;
	private shared Allocator allocator;

	invariant
	{
		assert(rep.length || !sign, "0 should be positive.");
	}

	/**
	 * Creates a multiple precision integer.
	 *
	 * Params:
	 * 	T         = Value type.
	 * 	value     = Initial value.
	 *	allocator = Allocator.
	 */
	this(T)(in T value, shared Allocator allocator = defaultAllocator)
		if (isIntegral!T)
	in
	{
		assert(allocator !is null);
	}
	body
	{
		this(allocator);

		T absolute = value;
		immutable size = calculateSizeFromInt(absolute);
		allocator.resizeArray(rep, size);
		assignInt(absolute);
	}

	private unittest
	{
		{
			auto h = Integer(79);
			assert(h.length == 1);
			assert(h.rep[0] == 79);
		}
		{
			auto h = Integer(-2);
			assert(h.length == 1);
			assert(h.rep[0] == 2);
			assert(h.sign);
		}
	}

	/// Ditto.
	this(in Integer value, shared Allocator allocator = defaultAllocator)
	in
	{
		assert(allocator !is null);
	}
	body
	{
		this(allocator);

		allocator.resizeArray(rep, value.length);
		value.rep.get.copy(rep.get);
		sign = value.sign;
	}

	/// Ditto.
	this(shared Allocator allocator)
	{
		this.allocator = allocator;
		rep = RefCounted!(ubyte[])(allocator);
	}

	/*
	 * Figures out the minimum amount of space this value will take
	 * up in bytes. Set the sign.
	 */
	private ubyte calculateSizeFromInt(T)(ref T value)
	pure nothrow @safe @nogc
	in
	{
		static assert(isIntegral!T);
	}
	body
	{
		ubyte size = ulong.sizeof;

		static if (isSigned!T)
		{
			sign = value < 0 ? true : false;
			value = abs(value);
		}
		else
		{
			sign = false;
		}
		for (ulong mask = 0xff00000000000000; mask >= 0xff; mask >>= 8)
		{
			if (value & mask)
			{
				break;
			}
			--size;
		}
		return size;
	}
	
	/*
	 * Work backward through the int, masking off each byte
	 * (up to the first 0 byte) and copy it into the internal
	 * representation in big-endian format.
	 */
	private void assignInt(in ulong value)
	pure nothrow @safe @nogc
	{
		uint mask = 0xff, shift;

		for (auto i = length; i; --i)
		{
			rep[i - 1] = cast(ubyte) ((value & mask) >> shift);
			mask <<= 8;
			shift += 8;
		}
	}

	/**
	 * Assigns a new value.
	 *
	 * Params:
	 * 	T     = Value type.
	 * 	value = Value.
	 *
	 * Returns: $(D_KEYWORD this).
	 */
	ref Integer opAssign(T)(in T value)
		if (isIntegral!T)
	{
		T absolute = value;
		immutable size = calculateSizeFromInt(absolute);

		checkAllocator();
		allocator.resizeArray(rep.get, size);
		assignInt(absolute);

		return this;
	}

	/// Ditto.
	ref Integer opAssign(in Integer value)
	{
		checkAllocator();

		allocator.resizeArray(rep, value.length);
		value.rep.get.copy(rep.get);

		sign = value.sign;

		return this;
	}

	private unittest
	{
		auto h = Integer(1019);
		assert(h.length == 2);
		assert(h.rep[0] == 0b00000011 && h.rep[1] == 0b11111011);

		h = 3337;
		assert(h.length == 2);
		assert(h.rep[0] == 0b00001101 && h.rep[1] == 0b00001001);

		h = 688;
		assert(h.length == 2);
		assert(h.rep[0] == 0b00000010 && h.rep[1] == 0b10110000);

		h = 0;
		assert(h.length == 0);
	}

	/**
	 * Returns: Integer size.
	 */
	@property size_t length() const pure nothrow @safe @nogc
	{
		return rep.get.length;
	}

	/**
	 * Params:
	 * 	h = The second integer.
	 *
	 * Returns: Whether the two integers are equal.
	 */
    bool opEquals(in Integer h) const
    {
        return rep == h.rep;
    }

	private unittest
	{
		auto h1 = Integer(1019);

		assert(h1 == Integer(1019));
		assert(h1 != Integer(109));
	}

    /**
	 * Params:
	 * 	h = The second integer.
     *
     * Returns: A positive number if $(D_INLINECODE this > h), a negative
     *          number if $(D_INLINECODE this > h), `0` otherwise.
     */
    int opCmp(in Integer h) const
    {
        if (length > h.length)
        {
            return 1;
        }
        if (length < h.length)
        {
            return -1;
        }
        // Otherwise, keep searching through the representational integers
        // until one is bigger than another - once we've found one, it's
        // safe to stop, since the lower order bytes can't affect the
        // comparison
        for (size_t i, j; i < length && j < h.length; ++i, ++j)
        {
            if (rep[i] < h.rep[j])
            {
                return -1;
            }
            else if (rep[i] > h.rep[j])
            {
                return 1;
            }
        }
        // if we got all the way to the end without a comparison, the
        // two are equal
        return 0;
    }

    private unittest
    {
		auto h1 = Integer(1019);
		auto h2 = Integer(1019);
		assert(h1 == h2);

		h2 = 3337;
		assert(h1 < h2);

		h2 = 688;
		assert(h1 > h2);
    }

	private void add(in ref RefCounted!(ubyte[]) h)
	{
		uint sum;
		uint carry = 0;

		// Adding h2 to h1. If h2 is > h1 to begin with, resize h1

		if (h.length > length)
		{
			auto tmp = allocator.makeArray!ubyte(h.length);
			tmp[h.length - length .. $] = rep[0 .. length];
			rep = tmp;
		}

		auto i = length;
		auto j = h.length;

		do
		{
			--i;
			if (j)
			{
				--j;
				sum = rep[i] + h[j] + carry;
			}
			else
			{
				sum = rep[i] + carry;
			}
			carry = sum > 0xff;
			rep[i] = cast(ubyte) sum;
		}
		while (i);

		if (carry)
		{
			// Still overflowed; allocate more space
			auto tmp = allocator.makeArray!ubyte(length + 1);
			tmp[1..$] = rep[0..length];
			tmp[0] = 0x01;
			rep = tmp;
		}

	}

	private void subtract(in ref RefCounted!(ubyte[]) h)
	{
		auto i = rep.length;
		auto j = h.length;
		uint borrow = 0;

		do
		{
			int difference;
			--i;

			if (j)
			{
				--j;
				difference = rep[i] - h[j] - borrow;
			}
			else
			{
				difference = rep[i] - borrow;
			}
			borrow = difference < 0;
			rep[i] = cast(ubyte) difference;
		}
		while (i);

		if (borrow && i && rep[i - 1])
		{
			--rep[i - 1];
		}
		// Go through the representation array and see how many of the
		// left-most bytes are unused. Remove them and resize the array.
		immutable offset = rep.get.countUntil!((const ref a) => a != 0);
		if (offset > 0)
		{
			ubyte[] tmp = allocator.makeArray!ubyte(rep.length - offset);
			rep[offset .. $].copy(tmp);
			rep = tmp;
		}
		else if (offset == -1)
		{
			allocator.resizeArray(rep, 0);
		}
	}

	/**
	 * Assignment operators with another $(D_PSYMBOL Integer).
	 *
	 * Params:
	 * 	op = Operation.
	 * 	h  = The second integer.
	 *
	 * Returns: $(D_KEYWORD this).
	 */
	ref Integer opOpAssign(string op)(in Integer h)
		if ((op == "+") || (op == "-"))
	{
		checkAllocator();
		static if (op == "+")
		{
			if (h.sign == sign)
			{
				add(h.rep);
			}
			else
			{
				if (this >= h)
				{
					subtract(h.rep);
				}
				else
				{
					auto tmp = Integer(h);
					tmp.subtract(rep);
					rep = tmp.rep;
					sign = length == 0 ? false : h.sign;
				}
			}
		}
		else
		{
			if (h.sign == sign)
			{
				if (this >= h)
				{
					subtract(h.rep);
				}
				else
				{
					auto tmp = Integer(h);
					tmp.subtract(rep);
					rep = tmp.rep;
					sign = length == 0 ? false : !sign;
				}
			}
			else
			{
				subtract(h.rep);
			}
		}
		return this;
	}

	private unittest
	{
		auto h1 = Integer(1019);
		
		auto h2 = Integer(3337);
		h1 += h2;
		assert(h1.rep == [0x11, 0x04]);

		h2 = 2_147_483_647;
		h1 += h2;
		assert(h1.rep == [0x80, 0x00, 0x11, 0x03]);

		h1 += h2;
		assert(h1.rep == [0x01, 0x00, 0x00, 0x11, 0x02]);

		h1 = 3;
		h2 = 4;
		h1 -= h2;
		assert(h1.rep == [0x01]);
		assert(h1.sign);
	}

	private unittest
	{
		auto h1 = Integer(4294967295);
		auto h2 = Integer(4294967295);
		h1 += h2;

		h2 = 2147483647;
		h1 -= h2;
		assert(h1.rep == [0x01, 0x7f, 0xff, 0xff, 0xff]);

		h2 = 4294967294;
		h1 -= h2;
		assert(h1.rep == [0x80, 0x00, 0x00, 0x01]);

		h2 = h1;
		h1 -= h2;
		assert(h1.length == 0);
	}

	/// Ditto.
	ref Integer opOpAssign(string op)(in size_t n)
		if (op == "<<")
	{
		ubyte carry;
		auto i = rep.length;
		size_t j;
		immutable bit = n % 8;
		immutable delta = 8 - bit;

		checkAllocator();
		if (cast(ubyte) (rep[0] >> delta))
		{
			allocator.resizeArray(rep, i + n / 8 + 1);
			j = i + 1;
		}
		else
		{
			allocator.resizeArray(rep, i + n / 8);
			j = i;
		}
		do
		{
			--i, --j;
			immutable oldCarry = carry;
			carry = rep[i] >> delta;
			rep[j] = cast(ubyte) ((rep[i] << bit) | oldCarry);
		}
		while (i);
		if (carry)
		{
			rep[0] = carry;
		}
		return this;
	}

	private unittest
	{
		auto h1 = Integer(4294967295);
		h1 <<= 1;
		assert(h1.rep == [0x01, 0xff, 0xff, 0xff, 0xfe]);
	}

	/// Ditto.
	ref Integer opOpAssign(string op)(in size_t n)
		if (op == ">>")
	{
		immutable step = n / 8;

		checkAllocator();
		if (step >= rep.length)
		{
			allocator.resizeArray(rep, 0);
			return this;
		}

		size_t i, j;
		ubyte carry;
		immutable bit = n % 8;
		immutable delta = 8 - bit;

		carry = cast(ubyte) (rep[0] << delta);
		rep[0] = (rep[0] >> bit);
		if (rep[0])
		{
			++j;
		}
		for (i = 1; i < rep.length; ++i)
		{
			immutable oldCarry = carry;
			carry = cast(ubyte) (rep[i] << delta);
			rep[j] = (rep[i] >> bit | oldCarry);
			++j;
		}
		allocator.resizeArray(rep, rep.length - n / 8 - (i == j ? 0 : 1));

		return this;
	}

	private unittest
	{
		auto h1 = Integer(4294967294);
		h1 >>= 10;
		assert(h1.rep == [0x3f, 0xff, 0xff]);

		h1 = 27336704;
		h1 >>= 1;
		assert(h1.rep == [0xd0, 0x90, 0x00]);

		h1 = 4294967294;
		h1 >>= 20;
		assert(h1.rep == [0x0f, 0xff]);

		h1 >>= 0;
		assert(h1.rep == [0x0f, 0xff]);

		h1 >>= 20;
		assert(h1.length == 0);

		h1 >>= 2;
		assert(h1.length == 0);

		h1 = 1431655765;
		h1 >>= 16;
		assert(h1.rep == [0x55, 0x55]);

		h1 >>= 16;
		assert(h1.length == 0);
	}

	/// Ditto.
	ref Integer opOpAssign(string op)(in Integer h)
		if (op == "*")
	{
		auto i = h.rep.length;
		auto temp = Integer(this, allocator);
		immutable sign = sign == h.sign ? false : true;

		opAssign(0);
		do
		{
			--i;
			for (ubyte mask = 0x01; mask; mask <<= 1)
			{
				if (mask & h.rep[i])
				{
					opOpAssign!"+"(temp);
				}
				temp <<= 1;
			}
		}
		while (i);
		this.sign = sign;

		return this;
	}

	private unittest
	{
		auto h1 = Integer(123);
		auto h2 = Integer(456);
		h1 *= h2;
		assert(h1.rep == [0xdb, 0x18]); // 56088
	}

	/// Ditto.
	ref Integer opOpAssign(string op)(in Integer h)
		if ((op == "/") || (op == "%"))
	in
	{
		assert(h.length > 0, "Division by zero.");
	}
	body
	{
		checkAllocator();

		auto divisor = Integer(h, allocator);
		size_t bitSize;

		// First, left-shift divisor until it's >= than the dividend
		for (; opCmp(divisor) > 0; ++bitSize)
		{
			divisor <<= 1;
		}
		static if (op == "/")
		{
			auto quotient = allocator.makeArray!ubyte(bitSize / 8 + 1);
		}

		// "bitPosition" keeps track of which bit, of the quotient,
		// is being set or cleared on the current operation.
		auto bitPosition = 8 - (bitSize % 8) - 1;
		do
		{
			if (opCmp(divisor) >= 0)
			{
				opOpAssign!"-"(divisor);
				static if (op == "/")
				{
					quotient[bitPosition / 8] |= (0x80 >> (bitPosition % 8));
				}
			}
			if (bitSize)
			{
				divisor >>= 1;
			}
			else
			{
				break;
			}
			++bitPosition, --bitSize;
		}
		while (true);

		static if (op == "/")
		{
			rep = quotient;
			sign = sign == h.sign ? false : true;
		}
		return this;
	}

	private unittest
	{
		auto h1 = Integer(18);
		auto h2 = Integer(4);
		h1 %= h2;
		assert(h1.rep == [0x02]);

		h1 = 8;
		h1 %= h2;
		assert(h1.length == 0);

		h1 = 7;
		h1 %= h2;
		assert(h1.rep == [0x03]);

		h1 = 56088;
		h2 = 456;
		h1 /= h2;
		assert(h1.rep == [0x7b]);
	}

	/// Ditto.
	ref Integer opOpAssign(string op)(in Integer exp)
		if (op == "^^")
	{
		auto i = exp.rep.length;
		auto tmp1 = Integer(this, allocator);
		auto tmp2 = Integer(allocator);

		opAssign(1);

		do
		{
			--i;
			for (ubyte mask = 0x01; mask; mask <<= 1)
			{
				if (exp.rep[i] & mask)
				{
					opOpAssign!"*"(tmp1);
				}
				// Square tmp1
				tmp2 = tmp1;
				tmp1 *= tmp2;
			}
		}
		while (i);

		return this;
	}

	private unittest
	{
		auto h1 = Integer(2);
		auto h2 = Integer(4);

		h1 ^^= h2;
		assert(h1.rep == [0x10]);

		h1 = Integer(2342);
		h1 ^^= h2;
		assert(h1.rep == [0x1b, 0x5c, 0xab, 0x9c, 0x31, 0x10]);
	}

	/**
	 * Unary operators.
	 *
	 * Params:
	 * 	op = Operation.
	 *
	 * Returns: New $(D_PSYMBOL Integer).
	 */
	Integer opUnary(string op)()
		if ((op == "+") || (op == "-") || (op == "~"))
	{
		auto h = Integer(this, allocator);
		static if (op == "-")
		{
			h.sign = !h.sign;
		}
		else static if (op == "~")
		{
			h.rep.get.each!((ref a) => a = ~a);
		}
		return h;
	}

	private unittest
	{
		auto h1 = Integer(79);
		Integer h2;

		h2 = +h1;
		assert(h2.length == 1);
		assert(h2.rep[0] == 79);
		assert(!h2.sign);
		assert(h2 !is h1);

		h2 = -h1;
		assert(h2.length == 1);
		assert(h2.rep[0] == 79);
		assert(h2.sign);

		h1 = -h2;
		assert(h2.length == 1);
		assert(h2.rep[0] == 79);
		assert(h2.sign);
		assert(h2 !is h1);

		h1 = -h2;
		assert(h1.length == 1);
		assert(h1.rep[0] == 79);
		assert(!h1.sign);

		h2 = ~h1;
		assert(h2.rep[0] == ~cast(ubyte) 79);
	}

	private void decrement()
	{
		immutable size = rep.get.retro.countUntil!((const ref a) => a != 0);
		if (rep[0] == 1)
		{
			allocator.resizeArray(rep, rep.length - 1);
			rep[0 .. $] = typeof(rep[0]).max;
		}
		else
		{
			--rep[$ - size - 1];
			rep[$ - size .. $] = typeof(rep[0]).max;
		}
	}

	private void increment()
	{
		auto size = rep
				   .get
				   .retro
				   .countUntil!((const ref a) => a != typeof(rep[0]).max);
		if (size == -1)
		{
			size = length;
			allocator.resizeArray(rep.get, rep.length + 1);
			rep[0] = 1;
		}
		else
		{
			++rep[$ - size - 1];
		}
		rep[$ - size .. $] = 0;
	}

	/**
	 * Increment/decrement.
	 *
	 * Params:
	 * 	op = Operation.
	 *
	 * Returns: $(D_KEYWORD this).
	 */
	ref Integer opUnary(string op)()
		if ((op == "++") || (op == "--"))
	{
		checkAllocator();

		static if (op == "++")
		{
			if (sign)
			{
				decrement();
				if (length == 0)
				{
					sign = false;
				}
			}
			else
			{
				increment();
			}
		}
		else if (sign)
		{
			increment();
		}
		else
		{
			decrement();
		}
		return this;
	}

	private unittest
	{
		Integer h;

		++h;
		assert(h.rep == [0x01]);
		assert(h.length == 1);

		--h;
		assert(h.length == 0);

		h = 511;
		++h;
		assert(h.rep == [0x02, 0x00]);

		--h;
		assert(h.rep == [0x01, 0xff]);

		h = 79;
		++h;
		assert(h.rep == [0x50]);

		--h;
		assert(h.rep == [0x4f]);

		h = 65535;
		++h;
		assert(h.rep == [0x01, 0x00, 0x00]);

		--h;
		assert(h.rep == [0xff, 0xff]);

		h = -2;
		++h;
		assert(h.rep == [0x01]);
	}

	private void checkAllocator() nothrow @safe @nogc
	{
		if (allocator is null)
		{
			allocator = defaultAllocator;
		}
	}

	/**
	 * Casting.
	 *
	 * Params:
	 * 	T = Target type.
	 *
	 * Returns: $(D_KEYWORD false) if the $(D_PSYMBOL Integer) is 0,
	 *          $(D_KEYWORD true) otherwise.
	 */
	T opCast(T : bool)() const pure nothrow @safe @nogc
	{
		return length == 0 ? false : true;
	}

	/**
	 * Casting to integer types.
	 *
	 * Params:
	 * 	T = Target type.
	 *
	 * Returns: Signed integer.
	 */
	T opCast(T : long)() const// pure nothrow @safe @nogc
	{
		ulong ret;
		for (size_t i = length, j; i > 0 && j <= 32; --i, j += 8)
		{
			ret |= cast(long) (rep[i - 1]) << j;
		}
		return sign ? -ret : ret;
	}

	private unittest
	{
		auto h = Integer(79);
		assert(cast(long) h == 79);

		h = -79;
		assert(cast(long) h == -79);

		h = 4294967295;
		assert(cast(long) h == 4294967295);

		h = -4294967295;
		assert(cast(long) h == -4294967295);
	}
}
