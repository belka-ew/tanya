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

import tanya.algorithm.mutation;
import tanya.math : isNaN;
import tanya.memory.op;
import tanya.meta.metafunction;
import tanya.meta.trait;
import tanya.meta.transform;
import tanya.range.array;
import tanya.range.primitive;

private ref inout(Args[0]) minMax(alias cmp, Args...)(ref inout Args args)
{
    auto actual = ((ref arg) @trusted => &arg)(args[0]);

    foreach (i, arg; args[1 .. $])
    {
        static if (isFloatingPoint!(Args[0]))
        {
            if (isNaN(arg))
            {
                continue;
            }
            if (isNaN(*actual))
            {
                actual = ((ref arg) @trusted => &arg)(args[i + 1]);
                continue;
            }
        }
        if (cmp(arg, *actual))
        {
            actual = ((ref arg) @trusted => &arg)(args[i + 1]);
        }
    }

    return *actual;
}

private T moveIf(T)(ref T arg)
{
    static if (hasElaborateCopyConstructor!T && isMutable!T)
    {
        return move(arg);
    }
    else
    {
        return arg;
    }
}

/**
 * Finds the smallest element in the argument list or a range.
 *
 * If a range is passed, $(D_PSYMBOL min) returns a range of the same type,
 * whose front element is the smallest in the range. If more than one element
 * fulfills this condition, the front of the returned range points to
 * the first one found.
 * If $(D_PARAM range) is empty, the original range is returned.
 *
 * If $(D_PARAM Args) are floating point numbers, $(B NaN) is not considered
 * for comparison. $(B NaN) is returned only if all arguments are $(B NaN)s.
 *
 * Params:
 *  Args  = Types of the arguments. All arguments should have the same type.
 *  Range = Forward range type.
 *  args  = Argument list.
 *  range = Forward range.
 *
 * Returns: The smallest element.
 */
CommonType!Args min(Args...)(Args args)
if (Args.length >= 2
 && isOrderingComparable!(Args[0])
 && allSameType!(Map!(Unqual, Args)))
{
    return moveIf(minMax!((ref a, ref b) => a < b)(args));
}

/// ditto
ref inout(Unqual!(Args[0])) min(Args...)(ref inout Args args)
if (Args.length >= 2
 && isOrderingComparable!(Args[0])
 && allSameType!(Map!(Unqual, Args)))
{
    return minMax!((ref a, ref b) => a < b)(args);
}

@nogc nothrow pure @safe unittest
{
    static assert(!is(typeof(min(1, 1UL))));
}

@nogc nothrow pure @safe unittest
{
    assert(min(5, 3) == 3);
    assert(min(4, 4) == 4);
    assert(min(5.2, 3.0) == 3.0);

    assert(min(5.2, double.nan) == 5.2);
    assert(min(double.nan, 3.0) == 3.0);
    assert(isNaN(min(double.nan, double.nan)));
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
 * If a range is passed, $(D_PSYMBOL max) returns a range of the same type,
 * whose front element is the largest in the range. If more than one element
 * fulfills this condition, the front of the returned range points to
 * the first one found.
 * If $(D_PARAM range) is empty, the original range is returned.
 *
 * If $(D_PARAM Args) are floating point numbers, $(B NaN) is not considered
 * for comparison. $(B NaN) is returned only if all arguments are $(B NaN)s.
 *
 * Params:
 *  Args  = Types of the arguments. All arguments should have the same type.
 *  Range = Forward range type.
 *  args  = Argument list.
 *  range = Forward range.
 *
 * Returns: The largest element.
 */
CommonType!Args max(Args...)(Args args)
if (Args.length >= 2
 && isOrderingComparable!(Args[0])
 && allSameType!(Map!(Unqual, Args)))
{
    return moveIf(minMax!((ref a, ref b) => a > b)(args));
}

/// ditto
ref inout(Unqual!(Args[0])) max(Args...)(ref inout Args args)
if (Args.length >= 2
 && isOrderingComparable!(Args[0])
 && allSameType!(Map!(Unqual, Args)))
{
    return minMax!((ref a, ref b) => a > b)(args);
}

@nogc nothrow pure @safe unittest
{
    static assert(!is(typeof(max(1, 1UL))));
}

@nogc nothrow pure @safe unittest
{
    assert(max(5, 3) == 5);
    assert(max(4, 4) == 4);
    assert(max(5.2, 3.0) == 5.2);

    assert(max(5.2, double.nan) == 5.2);
    assert(max(double.nan, 3.0) == 3.0);
    assert(isNaN(max(double.nan, double.nan)));
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

// min/max compare const and mutable structs.
@nogc nothrow pure @safe unittest
{
    static struct S
    {
        int s;

        int opCmp(typeof(this) that) const @nogc nothrow pure @safe
        {
            return this.s - that.s;
        }
    }
    {
        const s1 = S(1);
        assert(min(s1, S(2)).s == 1);
        assert(max(s1, S(2)).s == 2);
    }
    {
        auto s2 = S(2), s3 = S(3);
        assert(min(s2, s3).s == 2);
        assert(max(s2, s3).s == 3);
    }
}

/**
 * Compares element-wise two ranges for equality.
 *
 * If the ranges have different lengths, they aren't equal.
 *
 * Params:
 *  R1     = First range type.
 *  R2     = Second range type.
 *  range1 = First range.
 *  range2 = Second range.
 *
 * Returns: $(D_KEYWORD true) if both ranges are equal, $(D_KEYWORD false)
 *          otherwise.
 */
bool equal(R1, R2)(R1 r1, R2 r2)
if (allSatisfy!(isInputRange, R1, R2) && is(typeof(r1.front == r2.front)))
{
    static if (isDynamicArray!R1
            && is(R1 == R2)
            && __traits(isPOD, ElementType!R1))
    {
        return cmp(r1, r2) == 0;
    }
    else
    {
        static if (hasLength!R1 && hasLength!R2)
        {
            if (r1.length != r2.length)
            {
                return false;
            }
        }
        for (; !r1.empty && !r2.empty; r1.popFront(), r2.popFront())
        {
            if (r1.front != r2.front)
            {
                return false;
            }
        }
        static if (hasLength!R1 && hasLength!R2)
        {
            return true;
        }
        else
        {
            return r1.empty && r2.empty;
        }
    }
}

///
@nogc nothrow pure @safe unittest
{
    int[2] range1 = [1, 2];
    assert(equal(range1[], range1[]));

    int[3] range2 = [1, 2, 3];
    assert(!equal(range1[], range2[]));
}
