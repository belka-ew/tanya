/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * Copyright: Eugene Wissner 2016.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:belka@caraus.de, Eugene Wissner)
 */  
module tanya.math;

import std.traits;
public import tanya.math.mp;
public import tanya.math.random;

version (unittest)
{
	import std.algorithm.iteration;
}

/**
 * Computes $(D_PARAM x) to the power $(D_PARAM y) modulo $(D_PARAM z).
 *
 * If $(D_PARAM I) is an $(D_PSYMBOL Integer), the allocator of $(D_PARAM x)
 * is used to allocate the result.
 *
 * Params:
 * 	I = Base type.
 * 	G = Exponent type.
 * 	H = Divisor type:
 * 	x = Base.
 * 	y = Exponent.
 * 	z = Divisor.
 *
 * Returns: Reminder of the division of $(D_PARAM x) to the power $(D_PARAM y)
 *          by $(D_PARAM z).
 *
 * Precondition: $(D_INLINECODE z > 0)
 */
H pow(I, G, H)(in auto ref I x, in auto ref G y, in auto ref H z)
	if (isIntegral!I && isIntegral!G && isIntegral!H)
in
{
	assert(z > 0, "Division by zero.");
}
body
{
	G mask = G.max / 2 + 1;
	H result;

	if (y == 0)
	{
		return 1 % z;
	}
	else if (y == 1)
	{
		return x % z;
	}
	do
	{
		immutable bit = y & mask;
		if (!result && bit)
		{
			result = x;
			continue;
		}

		result *= result;
		if (bit)
		{
			result *= x;
		}
		result %= z;
	}
	while (mask >>= 1);

	return result;
}

/// Ditto.
I pow(I)(in auto ref I x, in auto ref I y, in auto ref I z)
	if (is(I == Integer))
in
{
	assert(z.length > 0, "Division by zero.");
}
body
{
	size_t i = y.length;
	auto tmp2 = Integer(x.allocator), tmp1 = Integer(x, x.allocator);
	Integer result = Integer(x.allocator);

	if (x.length == 0 && i != 0)
	{
		i = 0;
	}
	else
	{
		result = 1;
	}
	while (i)
	{
		--i;
		for (ubyte mask = 0x01; mask; mask <<= 1)
		{
			if (y.rep[i] & mask)
			{
				result *= tmp1;
				result %= z;
			}
			tmp2 = tmp1;
			tmp1 *= tmp2;
			tmp1 %= z;
		}
	}
	return result;
}

///
pure nothrow @safe @nogc unittest
{
	assert(pow(3, 5, 7) == 5);
	assert(pow(2, 2, 1) == 0);
	assert(pow(3, 3, 3) == 0);
	assert(pow(7, 4, 2) == 1);
	assert(pow(53, 0, 2) == 1);
	assert(pow(53, 1, 3) == 2);
	assert(pow(53, 2, 5) == 4);
	assert(pow(0, 0, 5) == 1);
	assert(pow(0, 5, 5) == 0);
}

///
unittest
{
	assert(cast(long) pow(Integer(3), Integer(5), Integer(7)) == 5);
	assert(cast(long) pow(Integer(2), Integer(2), Integer(1)) == 0);
	assert(cast(long) pow(Integer(3), Integer(3), Integer(3)) == 0);
	assert(cast(long) pow(Integer(7), Integer(4), Integer(2)) == 1);
	assert(cast(long) pow(Integer(53), Integer(0), Integer(2)) == 1);
	assert(cast(long) pow(Integer(53), Integer(1), Integer(3)) == 2);
	assert(cast(long) pow(Integer(53), Integer(2), Integer(5)) == 4);
	assert(cast(long) pow(Integer(0), Integer(0), Integer(5)) == 1);
	assert(cast(long) pow(Integer(0), Integer(5), Integer(5)) == 0);
}

/**
 * Checks if $(D_PARAM x) is a prime.
 *
 * Params:
 * 	x = The number should be checked.
 *
 * Returns: $(D_KEYWORD true) if $(D_PARAM x) is a prime number,
 *          $(D_KEYWORD false) otherwise.
 */
bool isPseudoprime(ulong x) nothrow pure @safe @nogc
{
	return pow(2, x - 1, x) == 1;
}

///
unittest
{
	uint[30] known = [74623, 74653, 74687, 74699, 74707, 74713, 74717, 74719,
	                  74843, 74747, 74759, 74761, 74771, 74779, 74797, 74821,
	                  74827, 9973, 104729, 15485867, 49979693, 104395303,
	                  593441861, 104729, 15485867, 49979693, 104395303,
	                  593441861, 899809363, 982451653];

	known.each!((ref x) => assert(isPseudoprime(x)));
}
