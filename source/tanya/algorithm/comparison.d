/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * Algorithms for comparing values.
 *
 * Copyright: Eugene Wissner 2018.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 * Source: $(LINK2 https://github.com/caraus-ecms/tanya/blob/master/source/tanya/algorithm/comparison.d,
 *                 tanya/algorithm/comparison.d)
 */
module tanya.algorithm.comparison;

import tanya.meta.trait;
import tanya.range.array;
import tanya.range.primitive;

/**
 * Finds the smallest element in the argument list or a range.
 *
 * The function should take at least one argument.
 *
 * If a range is passed, $(D_PSYMBOL min) returns a range of the same type,
 * whose front element is the smallest in the range. If more than one element
 * fulfills this condition, the front of the returned range points to
 * the first one found.
 * If $(D_PARAM range) is empty, the original range is returned.
 *
 * Params:
 *  Args  = Types of the arguments. All arguments should have the same type.
 *  Range = Forward range type.
 *  args  = Argument list.
 *  range = Forward range.
 *
 * Returns: The smallest element.
 */
Args[0] min(Args...)(Args args)
if (Args.length > 0 && isOrderingComparable!(Args[0]) && allSameType!Args)
{
    return min!Args(args);
}

/// ditto
ref Args[0] min(Args...)(ref Args args)
if (Args.length > 0 && isOrderingComparable!(Args[0]) && allSameType!Args)
{
    auto actual = (() @trusted => &args[0])();

    foreach (arg; args[1 .. $])
    {
        if (arg < *actual)
        {
            actual = (() @trusted => &arg)();
        }
    }

    return *actual;
}

@nogc nothrow pure @safe unittest
{
    assert(min(1) == 1);
    static assert(!is(typeof(min(1, 1UL))));
}

/// ditto
Range min(Range)(Range range)
if (isForwardRange!Range && isOrderingComparable!(ElementType!Range))
{
    if (range.empty)
    {
        return range;
    }
    auto actual = range.save;

    range.popFront();
    for (; !range.empty; range.popFront())
    {
        if (range.front < actual.front)
        {
            actual = range.save;
        }
    }

    return actual;
}

///
@nogc nothrow pure @safe unittest
{
    assert(min(1, 2) == 1);
    assert(min(3, 2) == 2);
    assert(min(3, 1, 2) == 1);

    int[4] range = [3, 1, 1, 2];
    auto minElement = min(range[]);
    assert(minElement.front == 1);
    assert(minElement.length == 3);
}

@nogc nothrow pure @safe unittest
{
    assert(min(cast(ubyte[]) []).empty);
}
    
/**
 * Finds the largest element in the argument list or a range.
 *
 * The function should take at least one argument.
 *
 * If a range is passed, $(D_PSYMBOL max) returns a range of the same type,
 * whose front element is the largest in the range. If more than one element
 * fulfills this condition, the front of the returned range points to
 * the first one found.
 * If $(D_PARAM range) is empty, the original range is returned.
 *
 * Params:
 *  Args  = Types of the arguments. All arguments should have the same type.
 *  Range = Forward range type.
 *  args  = Argument list.
 *  range = Forward range.
 *
 * Returns: The largest element.
 */
Args[0] max(Args...)(Args args)
if (Args.length > 0 && isOrderingComparable!(Args[0]) && allSameType!Args)
{
    return max!Args(args);
}

/// ditto
ref Args[0] max(Args...)(ref Args args)
if (Args.length > 0 && isOrderingComparable!(Args[0]) && allSameType!Args)
{
    auto actual = (() @trusted => &args[0])();

    foreach (arg; args[1 .. $])
    {
        if (arg > *actual)
        {
            actual = (() @trusted => &arg)();
        }
    }

    return *actual;
}

@nogc nothrow pure @safe unittest
{
    assert(max(1) == 1);
    static assert(!is(typeof(max(1, 1UL))));
}

/// ditto
Range max(Range)(Range range)
if (isForwardRange!Range && isOrderingComparable!(ElementType!Range))
{
    if (range.empty)
    {
        return range;
    }
    auto actual = range.save;

    range.popFront();
    for (; !range.empty; range.popFront())
    {
        if (range.front > actual.front)
        {
            actual = range.save;
        }
    }

    return actual;
}

///
@nogc nothrow pure @safe unittest
{
    assert(max(1, 2) == 2);
    assert(max(3, 2) == 3);
    assert(max(1, 3, 2) == 3);

    int[4] range = [1, 5, 5, 2];
    auto maxElement = max(range[]);
    assert(maxElement.front == 5);
    assert(maxElement.length == 3);
}

@nogc nothrow pure @safe unittest
{
    assert(max(cast(ubyte[]) []).empty);
}
