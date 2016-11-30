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

import std.algorithm.comparison;
import std.algorithm.mutation;
import std.algorithm.searching;

struct Integer
{
    private ubyte[] rep;
	private bool sign;

	this(in uint value)
	{
		opAssign(value);
	}

	///
	unittest
	{
		auto h = Integer(79);
		assert(h.length == 1);
		assert(h.rep[0] == 79);
	}

	this(in Integer value)
	{
		opAssign(value);
	}

	~this()
	{
		destroy(rep);
	}

	Integer opAssign(in uint value)
	{
		uint mask, shift;
		ushort size = 4;

		// Figure out the minimum amount of space this value will take
		// up in bytes (leave at least one byte, though, if the value is 0).
		for (mask = 0xff000000; mask > 0x000000ff; mask >>= 8)
		{
			if (value & mask)
			{
				break;
			}
			--size;
		}
		rep.length = size;

		// Work backward through the int, masking off each byte
		// (up to the first 0 byte) and copy it into the internal
		// representation in big-endian format.
		mask = 0x00000000ff;
		shift = 0;
		for (auto i = size; i; --i)
		{
			rep[i - 1] = cast(ubyte) ((value & mask) >> shift);
			mask <<= 8;
			shift += 8;
		}
		return this;
	}

	Integer opAssign(in Integer value)
	{
		rep.length = value.length;
		value.rep.copy(rep);

		return this;
	}

	///
	unittest
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
		assert(h.length == 1);
		assert(h.rep[0] == 0);
	}

	@property size_t length() const pure nothrow @safe @nogc
	{
		return rep.length;
	}

    bool opEquals(in Integer h)
    {
        return rep == h.rep;
    }

    /**
     * Compare h1 to h2. Return:
     * a positive number if h1 > h2
     * a negative number if h1 < h2
     */
    int opCmp(in Integer h)
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
        int i = 0, j = 0;
        while (i < length && j < h.length)
        {
            if (rep[i] < h.rep[j])
            {
                return -1;
            }
            else if (rep[i] > h.rep[j])
            {
                return 1;
            }
            ++i;
            ++j;
        }
        // if we got all the way to the end without a comparison, the
        // two are equal
        return 0;
    }

    ///
    unittest
    {
		auto h1 = Integer(1019);
		auto h2 = Integer(1019);
		assert(h1 == h2);

		h2 = 3337;
		assert(h1 < h2);

		h2 = 688;
		assert(h1 > h2);
    }

	/**
	 * Add two huges - overwrite h1 with the result.
	 */
	Integer opOpAssign(string op)(Integer h)
		if (op == "+")
	{
		uint sum;
		uint carry = 0;

		// Adding h2 to h1. If h2 is > h1 to begin with, resize h1

		if (h.length > length)
		{
			auto tmp = new ubyte[h.length];
			tmp[h.length - length ..$] = rep[0..length];
			destroy(rep);
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
				sum = rep[i] + h.rep[j] + carry;
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
			ubyte[] tmp = new ubyte[length + 1];
			tmp[1..$] = rep[0..length];
			tmp[0] = 0x01;
			destroy(rep);
			rep = tmp;
		}
		return this;
	}

	///
	unittest
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
	}

	Integer opOpAssign(string op)(Integer h)
		if (op == "-")
	{
		auto i = rep.length;
		auto j = h.rep.length;
		uint borrow = 0;

		do
		{
			int difference;
			--i;

			if (j)
			{
				--j;
				difference = rep[i] - h.rep[j] - borrow;
			}
			else
			{
				difference = rep[i] - borrow;
			}
			borrow = difference < 0;
			rep[i] = cast(ubyte) difference;
		}
		while (i);

		if (borrow && i)
		{
			if (!(rep[i - 1])) // Don't borrow i
			{
				throw new Exception("Error, subtraction result is negative\n");
			}
			--rep[i - 1];
		}
		// Go through the representation array and see how many of the
		// left-most bytes are unused. Remove them and resize the array.
		immutable offset = rep.countUntil!(a => a != 0);
		if (offset > 0)
		{
			ubyte[] tmp = rep;
			rep = new ubyte[rep.length - offset];
			tmp[offset..$].copy(rep);
			destroy(tmp);
		}
		return this;
	}

	///
	unittest
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

	}

	Integer opOpAssign(string op)(in size_t n)
		if (op == "<<")
	{
		ubyte carry;
		auto i = rep.length;
		size_t j;
		immutable bit = n % 8;
		immutable delta = 8 - bit;

		if (cast(ubyte) (rep[0] >> delta))
		{
			rep.length = rep.length + n / 8 + 1;
			j = i + 1;
		}
		else
		{
			rep.length = rep.length + n / 8;
			j = i;
		}
		do
		{
			--i;
			--j;
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

	///
	unittest
	{
		auto h1 = Integer(4294967295);
		h1 <<= 1;
		assert(h1.rep == [0x01, 0xff, 0xff, 0xff, 0xfe]);
	}

	Integer opOpAssign(string op)(in size_t n)
		if (op == ">>")
	{
		immutable step = n / 8;
		if (step >= rep.length)
		{
			rep.length = 1;
			rep[0] = 0;
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
		rep.length = max(1, rep.length - n / 8 - (i == j ? 0 : 1));

		return this;
	}

	///
	unittest
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
		assert(h1.rep == [0x00]);

		h1 >>= 2;
		assert(h1.rep == [0x00]);

		h1 = 1431655765;
		h1 >>= 16;
		assert(h1.rep == [0x55, 0x55]);

		h1 >>= 16;
		assert(h1.rep == [0x00]);
	}

	/**
	 * Multiply h1 by h2, overwriting the value of h1.
	 */
	Integer opOpAssign(string op)(in Integer h)
		if (op == "*")
	{
		ubyte mask;
		auto i = h.rep.length;
		auto temp = Integer(this);

		opAssign(0);

		do
		{
			--i;
			for (mask = 0x01; mask; mask <<= 1)
			{
				if (mask & h.rep[i])
				{
					opOpAssign!"+"(temp);
				}
				temp <<= 1;
			}
		}
		while (i);

		return this;
	}

	///
	unittest
	{
		auto h1 = Integer(123);
		auto h2 = Integer(456);
		h1 *= h2;
		assert(h1.rep == [0xdb, 0x18]); // 56088
	}

	/**
	 * divident = numerator, divisor = denominator
	 *
	 * Note that this process destroys divisor (and, of couse,
	 * overwrites quotient). The divident is the remainder of the
	 * division (if that's important to the caller). The divisor will
	 * be modified by this routine, but it will end up back where it
	 * "started".
	 */
	Integer opOpAssign(string op)(in Integer h)
		if ((op == "/") || (op == "%"))
	{
		auto divisor = Integer(h);
		// "bit_position" keeps track of which bit, of the quotient,
		// is being set or cleared on the current operation.
		size_t bit_size;

		// First, left-shift divisor until it's >= than the divident
		while (opCmp(divisor) > 0)
		{
			divisor <<= 1;
			++bit_size;
		}
		static if (op == "/")
		{
			auto quotient = new ubyte[bit_size / 8 + 1];
		}

		auto bit_position = 8 - (bit_size % 8) - 1;

		do
		{
			if (opCmp(divisor) >= 0)
			{
				opOpAssign!"-"(divisor);
				static if (op == "/")
				{
					quotient[bit_position / 8] |= (0x80 >> (bit_position % 8));
				}
			}

			if (bit_size)
			{
				divisor >>= 1;
			}
			++bit_position;
		}
		while (bit_size--);

		static if (op == "/")
		{
			destroy(rep);
			rep = quotient;
		}
		return this;
	}

	///
	unittest
	{
		auto h1 = Integer(18);
		auto h2 = Integer(4);
		h1 %= h2;
		assert(h1.rep == [0x02]);

		h1 = 8;
		h1 %= h2;
		assert(h1.rep == [0x00]);

		h1 = 7;
		h1 %= h2;
		assert(h1.rep == [0x03]);

		h1 = 56088;
		h2 = 456;
		h1 /= h2;
		assert(h1.rep == [0x7b]); // 123
	}

	Integer opOpAssign(string op)(in Integer exp)
		if (op == "^^")
	{
		auto i = exp.rep.length;
		auto tmp1 = Integer(this);
		Integer tmp2;

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

	///
	unittest
	{
		auto h1 = Integer(2);
		auto h2 = Integer(4);

		h1 ^^= h2;
		assert(h1.rep == [0x10]);

		h1 = Integer(2342);
		h1 ^^= h2;
		assert(h1.rep == [0x1b, 0x5c, 0xab, 0x9c, 0x31, 0x10]);
	}
}
