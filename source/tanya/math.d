/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * Copyright: Eugene Wissner 2016.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:belka@caraus.de, Eugene Wissner)
 */  
module tanya.container.math;

version (unittest)
{
	import std.algorithm.iteration;
}

@nogc:

/**
 * Computes $(D_PARAM x) to the power $(D_PARAM y) modulo $(D_PARAM z).
 *
 * Params:
 * 	x = Base.
 * 	y = Exponent.
 * 	z = Divisor.
 *
 * Returns: Reminder of the division of $(D_PARAM x) to the power $(D_PARAM y)
 *          by $(D_PARAM z).
 */
ulong pow(ulong x, ulong y, ulong z) @safe nothrow pure
in
{
	assert(z > 0);
}
out (result)
{
	assert(result >= 0);
}
body
{
    ulong mask = ulong.max / 2 + 1, result;

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
        auto bit = y & mask;
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

///
unittest
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

/**
 * Checks if $(D_PARAM x) is a prime.
 *
 * Params:
 * 	x = The number should be checked.
 *
 * Returns: $(D_KEYWORD true) if $(D_PARAM x) is a prime number,
 *          $(D_KEYWORD false) otherwise.
 */
bool isPseudoprime(ulong x) @safe nothrow pure
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
