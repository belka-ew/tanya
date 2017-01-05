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

/**
 * Mutliple precision integer.
 */
struct Integer
{
	package ubyte[] rep;
	private bool sign;

	/**
	 * Creates a multiple precision integer.
	 *
	 * Params:
	 * 	T         = Value type.
	 * 	value     = Initial value.
	 *	allocator = Allocator.
	 *
	 * Precondition: $(D_INLINECODE allocator !is null)
	 */
	this(T)(in auto ref T value, shared Allocator allocator = defaultAllocator)
	nothrow @safe @nogc
		if (isIntegral!T || is(T == Integer))
	{
		this(allocator);
		static if (isIntegral!T)
		{
			assignInt(value);
		}
		else if (value.length > 0)
		{
			allocator.resize!(ubyte, false)(rep, value.length);
			rep[] = value.rep[];
			sign = value.sign;
		}
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

	private @nogc unittest
	{
		auto h1 = Integer(79);
		assert(h1.length == 1);
		assert(h1.rep[0] == 79);
		assert(!h1.sign);

		auto h2 = Integer(-2);
		assert(h2.length == 1);
		assert(h2.rep[0] == 2);
		assert(h2.sign);
	}

	@disable this(this);

	/**
	 * Destroys the internal representation.
	 */
	~this() nothrow @safe @nogc
	{
		allocator.dispose(rep);
	}

	/*
	 * Figures out the minimum amount of space this value will take
	 * up in bytes and resizes the internal storage. Sets the sign.
	 */
	private void assignInt(T)(in ref T value)
	nothrow @safe @nogc
	in
	{
		static assert(isIntegral!T);
	}
	body
	{
		ubyte size = ulong.sizeof;
		ulong mask;

		static if (isSigned!T)
		{
			sign = value < 0 ? true : false;
			immutable absolute = value.abs;
		}
		else
		{
			sign = false;
			alias absolute = value;
		}
		for (mask = 0xff00000000000000; mask >= 0xff; mask >>= 8)
		{
			if (absolute & mask)
			{
				break;
			}
			--size;
		}
		allocator.resize!(ubyte, false)(rep, size);

		/* Work backward through the int, masking off each byte (up to the
		   first 0 byte) and copy it into the internal representation in
		   big-endian format. */
		mask = 0xff;
		ushort shift;
		for (auto i = rep.length; i; --i, mask <<= 8, shift += 8)
		{
			rep[i - 1] = cast(ubyte) ((absolute & mask) >> shift);
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
	ref Integer opAssign(T)(in auto ref T value) nothrow @safe @nogc
		if (isIntegral!T || is(T == Integer))
	{
		static if (isIntegral!T)
		{
			assignInt(value);
		}
		else
		{
			allocator.resize!(ubyte, false)(rep, value.length);
			rep[0 .. $] = value.rep[0 .. $];
			sign = value.sign;
		}
		return this;
	}

	private @nogc unittest
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
		return rep.length;
	}

	/**
	 * Params:
	 * 	h = The second integer.
	 *
	 * Returns: Whether the two integers are equal.
	 */
	bool opEquals(in Integer h) const nothrow @safe @nogc
	{
		return rep == h.rep;
	}

	/// Ditto.
	bool opEquals(in ref Integer h) const nothrow @safe @nogc
	{
		return rep == h.rep;
	}

	///
	unittest
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
	int opCmp(in ref Integer h) const nothrow @safe @nogc
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

	/// Ditto.
	int opCmp(in Integer h) const nothrow @safe @nogc
	{
		return opCmp(h);
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

	private void add(in ref ubyte[] h) nothrow @safe @nogc
	{
		uint sum;
		uint carry = 0;
		ubyte[] tmp;

		if (h.length > length)
		{
			allocator.resize!(ubyte, false)(tmp, h.length);
			tmp[0 .. h.length] = 0;
			tmp[h.length - length .. $] = rep[0 .. length];
			swap(rep, tmp);
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
			allocator.resize!(ubyte, false)(tmp, length + 1);
			tmp[1 .. $] = rep[0 .. length];
			tmp[0] = 0x01;
			swap(rep, tmp);
		}
		allocator.dispose(tmp);
	}

	private void subtract(in ref ubyte[] h) nothrow @trusted @nogc
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
		immutable offset = rep.countUntil!((const ref a) => a != 0);
		if (offset > 0)
		{
			ubyte[] tmp = cast(ubyte[]) allocator.allocate(rep.length - offset);
			tmp[0 .. $] = rep[offset .. $];
			allocator.deallocate(rep);
			rep = tmp;
		}
		else if (offset == -1)
		{
			allocator.dispose(rep);
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
	ref Integer opOpAssign(string op)(in auto ref Integer h) nothrow @safe @nogc
		if ((op == "+") || (op == "-"))
	out
	{
		assert(rep.length || !sign, "0 should be positive.");
		assert(!rep.length || rep[0]);
	}
	body
	{
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
					swap(rep, tmp.rep);
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
					swap(rep, tmp.rep);
					sign = length == 0 ? false : !sign;
				}
			}
			else
			{
				add(h.rep);
			}
		}
		return this;
	}

	private @nogc unittest
	{
		{
			auto h1 = Integer(1019);
			auto h2 = Integer(3337);
			h1 += h2;
			assert(h1.length == 2);
			assert(h1.rep[0] == 0x11 && h1.rep[1] == 0x04);
		}
		{
			auto h1 = Integer(4356);
			auto h2 = Integer(2_147_483_647);
			ubyte[4] expected = [0x80, 0x00, 0x11, 0x03];
			h1 += h2;
			assert(h1.rep == expected);
		}
		{
			auto h1 = Integer(2147488003L);
			auto h2 = Integer(2_147_483_647);
			ubyte[5] expected = [0x01, 0x00, 0x00, 0x11, 0x02];
			h1 += h2;
			assert(h1.rep == expected);
		}
		{
			auto h1 = Integer(3);
			auto h2 = Integer(4);
			h1 -= h2;
			assert(h1.length == 1);
			assert(h1.rep[0] == 0x01);
			assert(h1.sign);
		}
	}

	private @nogc unittest
	{
		{
			auto h1 = Integer(8589934590L);
			auto h2 = Integer(2147483647);
			ubyte[5] expected = [0x01, 0x7f, 0xff, 0xff, 0xff];

			h1 -= h2;
			assert(h1.rep == expected);
		}
		{
			auto h1 = Integer(6442450943);
			auto h2 = Integer(4294967294);
			ubyte[4] expected = [0x80, 0x00, 0x00, 0x01];
			h1 -= h2;
			assert(h1.rep == expected);
		}
		{
			auto h1 = Integer(2147483649);
			auto h2 = Integer(h1);
			h1 -= h2;
			assert(h1.length == 0);
		}
	}

	/// Ditto.
	ref Integer opOpAssign(string op)(in auto ref Integer h) nothrow @safe @nogc
		if (op == "*")
	out
	{
		assert(rep.length || !sign, "0 should be positive.");
		assert(!rep.length || rep[0]);
	}
	body
	{
		auto i = h.rep.length;
		if (length == 0)
		{
			return this;
		}
		else if (i == 0)
		{
			opAssign(0);
			return this;
		}
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

	///
	unittest
	{
		auto h1 = Integer(123);
		auto h2 = Integer(456);
		h1 *= h2;
		assert(cast(long) h1 == 56088);
	}

	private unittest
	{
		assert((Integer(1) * Integer()).length == 0);
	}

	/// Ditto.
	ref Integer opOpAssign(string op)(in auto ref Integer h) nothrow @safe @nogc
		if ((op == "/") || (op == "%"))
	in
	{
		assert(h.length > 0, "Division by zero.");
	}
	body
	{
		auto divisor = Integer(h, allocator);
		size_t bitSize;

		// First, left-shift divisor until it's >= than the dividend
		for (; opCmp(divisor) > 0; ++bitSize)
		{
			divisor <<= 1;
		}
		static if (op == "/")
		{
			ubyte[] quotient;
			allocator.resize!(ubyte, false)(quotient, bitSize / 8 + 1);
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
			allocator.dispose(rep);
			rep = quotient;
			sign = sign == h.sign ? false : true;
		}
		return this;
	}

	private @nogc unittest
	{
		auto h1 = Integer(18);
		auto h2 = Integer(4);
		h1 %= h2;
		assert(h1.length == 1);
		assert(h1.rep[0] == 0x02);

		h1 = 8;
		h1 %= h2;
		assert(h1.length == 0);

		h1 = 7;
		h1 %= h2;
		assert(h1.length == 1);
		assert(h1.rep[0] == 0x03);

		h1 = 56088;
		h2 = 456;
		h1 /= h2;
		assert(h1.length == 1);
		assert(h1.rep[0] == 0x7b);
	}

	/// Ditto.
	ref Integer opOpAssign(string op)(in auto ref Integer exp) nothrow @safe @nogc
		if (op == "^^")
	out
	{
		assert(rep.length || !sign, "0 should be positive.");
		assert(!rep.length || rep[0]);
	}
	body
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

	private @nogc unittest
	{
		auto h1 = Integer(2);
		auto h2 = Integer(4);

		h1 ^^= h2;
		assert(h1.length == 1);
		assert(h1.rep[0] == 0x10);

		h1 = Integer(2342);
		h1 ^^= h2;
		ubyte[6] expected = [0x1b, 0x5c, 0xab, 0x9c, 0x31, 0x10];
		assert(h1.rep == expected);
	}

	/**
	 * Unary operators.
	 *
	 * Params:
	 * 	op = Operation.
	 *
	 * Returns: New $(D_PSYMBOL Integer).
	 */
	Integer opUnary(string op)() nothrow @safe @nogc
		if ((op == "+") || (op == "-") || (op == "~"))
	{
		auto h = Integer(this, allocator);
		static if (op == "-")
		{
			h.sign = !h.sign;
		}
		else static if (op == "~")
		{
			h.rep.each!((ref a) => a = ~a);
		}
		return h;
	}

	private @nogc unittest
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

	private void decrement() nothrow @safe @nogc
	{
		immutable size = rep.retro.countUntil!((const ref a) => a != 0);
		if (rep[0] == 1)
		{
			allocator.resize!(ubyte, false)(rep, rep.length - 1);
			rep[0 .. $] = typeof(rep[0]).max;
		}
		else
		{
			--rep[$ - size - 1];
			rep[$ - size .. $] = typeof(rep[0]).max;
		}
	}

	private void increment() nothrow @safe @nogc
	{
		auto size = rep.retro.countUntil!((const ref a) => a != typeof(rep[0]).max);
		if (size == -1)
		{
			size = length;
			allocator.resize!(ubyte, false)(rep, rep.length + 1);
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
	ref Integer opUnary(string op)() nothrow @safe @nogc
		if ((op == "++") || (op == "--"))
	out
	{
		assert(rep.length || !sign, "0 should be positive.");
		assert(!rep.length || rep[0]);
	}
	body
	{
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

	private @nogc unittest
	{
		Integer h;

		++h;
		assert(h.length == 1);
		assert(h.rep[0] == 0x01);

		--h;
		assert(h.length == 0);

		h = 511;
		++h;
		assert(h.length == 2);
		assert(h.rep[0] == 0x02 && h.rep[1] == 0x00);

		--h;
		assert(h.length == 2);
		assert(h.rep[0] == 0x01 && h.rep[1] == 0xff);

		h = 79;
		++h;
		assert(h.length == 1);
		assert(h.rep[0] == 0x50);

		--h;
		assert(h.length == 1);
		assert(h.rep[0] == 0x4f);

		h = 65535;
		++h;
		assert(h.length == 3);
		assert(h.rep[0] == 0x01 && h.rep[1] == 0x00 && h.rep[2] == 0x00);

		--h;
		assert(h.length == 2);
		assert(h.rep[0] == 0xff && h.rep[1] == 0xff);

		h = -2;
		++h;
		assert(h.length == 1);
		assert(h.rep[0] == 0x01);
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

	/// Ditto.
	T opCast(T)() const pure nothrow @safe @nogc
		if (isIntegral!T && isSigned!T)
	{
		ulong ret;
		for (size_t i = length, j; i > 0 && j <= T.sizeof * 4; --i, j += 8)
		{
			ret |= cast(T) (rep[i - 1]) << j;
		}
		return sign ? -ret : ret;
	}

	/// Ditto.
	T opCast(T)() const pure nothrow @safe @nogc
		if (isIntegral!T && isUnsigned!T)
	{
		ulong ret;
		for (size_t i = length, j; i > 0 && j <= T.sizeof * 8; --i, j += 8)
		{
			ret |= cast(T) (rep[i - 1]) << j;
		}
		return ret;
	}

	///
	unittest
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

	/**
	 * Shift operations.
	 *
	 * Params:
	 * 	op = Left or right shift.
	 * 	n  = Number of bits to shift by.
	 *
	 * Returns: An $(D_PSYMBOL Integer) shifted by $(D_PARAM n) bits.
	 */
	ref Integer opOpAssign(string op)(in auto ref size_t n) nothrow @safe @nogc
		if (op == ">>")
	out
	{
		assert(rep.length || !sign, "0 should be positive.");
		assert(!rep.length || rep[0]);
	}
	body
	{
		immutable step = n / 8;

		if (step >= rep.length)
		{
			allocator.resize!(ubyte, false)(rep, 0);
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
		allocator.resize!(ubyte, false)(rep, rep.length - n / 8 - (i == j ? 0 : 1));

		return this;
	}

	private @nogc unittest
	{
		auto h1 = Integer(4294967294);
		h1 >>= 10;
		assert(h1.length == 3);
		assert(h1.rep[0] == 0x3f && h1.rep[1] == 0xff && h1.rep[2] == 0xff);

		h1 = 27336704;
		h1 >>= 1;
		assert(h1.length == 3);
		assert(h1.rep[0] == 0xd0 && h1.rep[1] == 0x90 && h1.rep[2] == 0x00);

		h1 = 4294967294;
		h1 >>= 20;
		assert(h1.length == 2);
		assert(h1.rep[0] == 0x0f && h1.rep[1] == 0xff);

		h1 >>= 0;
		assert(h1.length == 2);
		assert(h1.rep[0] == 0x0f && h1.rep[1] == 0xff);

		h1 >>= 20;
		assert(h1.length == 0);

		h1 >>= 2;
		assert(h1.length == 0);

		h1 = 1431655765;
		h1 >>= 16;
		assert(h1.length == 2);
		assert(h1.rep[0] == 0x55 && h1.rep[1] == 0x55);

		h1 >>= 16;
		assert(h1.length == 0);
	}

	/// Ditto.
	ref Integer opOpAssign(string op)(in auto ref size_t n) nothrow @safe @nogc
		if (op == "<<")
	out
	{
		assert(rep.length || !sign, "0 should be positive.");
		assert(!rep.length || rep[0]);
	}
	body
	{
		ubyte carry;
		auto i = rep.length;
		size_t j;
		immutable bit = n % 8;
		immutable delta = 8 - bit;

		if (cast(ubyte) (rep[0] >> delta))
		{
			allocator.resize!(ubyte, false)(rep, i + n / 8 + 1);
			j = i + 1;
		}
		else
		{
			allocator.resize!(ubyte, false)(rep, i + n / 8);
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

	private @nogc unittest
	{
		auto h1 = Integer(4294967295);
		ubyte[5] expected = [0x01, 0xff, 0xff, 0xff, 0xfe];
		h1 <<= 1;
		assert(h1.rep == expected);
	}

	/// Ditto.
	Integer opBinary(string op)(in auto ref size_t n) nothrow @safe @nogc
		if (op == "<<" || op == ">>" || op == "+" || op == "-" || op == "/"
		 || op == "*" || op == "^^" || op == "%")
	{
		auto ret = Integer(this, allocator);
		mixin("ret " ~ op ~ "= n;");
		return ret;
	}

	///
	unittest
	{
		auto h1 = Integer(425);
		auto h2 = h1 << 1;
		assert(cast(long) h2 == 850);

		h2 = h1 >> 1;
		assert(cast(long) h2 == 212);
	}

	/// Ditto.
	Integer opBinary(string op)(in auto ref Integer h) nothrow @safe @nogc
		if (op == "+" || op == "-" || op == "/"
		 || op == "*" || op == "^^" || op == "%")
	{
		auto ret = Integer(this, allocator);
		mixin("ret " ~ op ~ "= h;");
		return ret;
	}

	mixin DefaultAllocator;
}
