/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * Algorithms for comparing values.
 *
 * Copyright: Eugene Wissner 2018-2020.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 * Source: $(LINK2 https://github.com/caraus-ecms/tanya/blob/master/source/tanya/algorithm/comparison.d,
 *                 tanya/algorithm/comparison.d)
 */
module tanya.algorithm.comparison;

import std.traits : CommonType;
import tanya.algorithm.mutation;
import tanya.math;
static import tanya.memory.op;
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

/**
 * Compares element-wise two ranges for equality.
 *
 * If the ranges have different lengths, they aren't equal.
 *
 * Params:
 *  pred = Predicate used to compare individual element pairs.
 *  R1   = First range type.
 *  R2   = Second range type.
 *  r1   = First range.
 *  r2   = Second range.
 *
 * Returns: $(D_KEYWORD true) if both ranges are equal, $(D_KEYWORD false)
 *          otherwise.
 */
bool equal(alias pred = (auto ref a, auto ref b) => a == b, R1, R2)
          (R1 r1, R2 r2)
if (allSatisfy!(isInputRange, R1, R2)
 && is(typeof(pred(r1.front, r2.front)) == bool))
{
    static if (isDynamicArray!R1
            && is(R1 == R2)
            && __traits(isPOD, ElementType!R1))
    {
        return tanya.memory.op.equal(r1, r2);
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
            if (!pred(r1.front, r2.front))
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

/**
 * Compares element-wise two ranges for ordering.
 *
 * $(D_PSYMBOL compare) returns a negative value if $(D_PARAM r1) is less than
 * $(D_PARAM r2), a positive value if $(D_PARAM r2) is less than $(D_PARAM r1),
 * or `0` if $(D_PARAM r1) and $(D_PARAM r2) equal.
 *
 * $(D_PSYMBOL compare) iterates both ranges in lockstep. Whichever of them
 * contains an element that is greater than the respective element at the same
 * position in the other range is the greater one of the two.
 *
 * If one of the ranges becomes empty when iterating, but all elements equal so
 * far, the range with more elements is the greater one.
 *
 * If $(D_PARAM pred) is given, it is used for comparison. $(D_PARAM pred) is
 * called as $(D_INLINECODE pred(r1.front, r2.front)) and
 * $(D_INLINECODE pred(r2.front, r1.front)) to perform three-way comparison.
 * $(D_PARAM pred) should return a $(D_KEYWORD bool).
 *
 * If $(D_PARAM pred) is not given, but the element type of $(D_PARAM R1)
 * defines `opCmp()` for the element type of $(D_PARAM R2), `opCmp()` is used.
 *
 * Otherwise the comparison is perfomed using the basic comparison operators.
 *
 * Params:
 *  pred = Predicate used for comparison.
 *  R1   = First range type.
 *  R2   = Second range type.
 *  r1   = First range.
 *  r2   = Second range.
 *
 * Returns: A negative value if $(D_PARAM r1) is less than $(D_PARAM r2), a
 *          positive value if $D(_PARAM r2) is less than $(D_PARAM r1), `0`
 *          otherwise.
 */
int compare(alias pred, R1, R2)(R1 r1, R2 r2)
if (allSatisfy!(isInputRange, R1, R2)
 && is(typeof(pred(r1.front, r2.front)) == bool)
 && is(typeof(pred(r2.front, r1.front)) == bool))
{
    alias predImpl = (ref r1, ref r2) {
        return pred(r2.front, r1.front) - pred(r1.front, r2.front);
    };
    return compareImpl!(predImpl, R1, R2)(r1, r2);
}

/// ditto
int compare(R1, R2)(R1 r1, R2 r2)
if (allSatisfy!(isInputRange, R1, R2)
 && is(typeof(r1.front < r2.front || r2.front < r1.front)))
{
    static if (is(typeof(r1.front.opCmp(r2.front)) == int))
    {
        alias pred = (ref r1, ref r2) => r1.front.opCmp(r2.front);
    }
    else
    {
        alias pred = (ref r1, ref r2) {
            return (r2.front < r1.front) - (r1.front < r2.front);
        };
    }
    return compareImpl!(pred, R1, R2)(r1, r2);
}

///
@nogc nothrow pure @safe unittest
{
    assert(compare("abc", "abc") == 0);
    assert(compare("abcd", "abc") > 0);
    assert(compare("ab", "abc") < 0);
    assert(compare("abc", "abcd") < 0);
    assert(compare("abc", "ab") > 0);
    assert(compare("aec", "abc") > 0);
    assert(compare("aac", "abc") < 0);
    assert(compare("abc", "aec") < 0);
    assert(compare("abc", "aab") > 0);
    assert(compare("aacd", "abc") < 0);
    assert(compare("abc", "aacd") > 0);

    assert(compare!((a, b) => a > b)("aec", "abc") < 0);
    assert(compare!((a, b) => a > b)("aac", "abc") > 0);
}

private int compareImpl(alias pred, R1, R2)(ref R1 r1, ref R2 r2)
{
    for (; !r1.empty || !r2.empty; r1.popFront(), r2.popFront())
    {
        if (r1.empty)
        {
            return -1;
        }
        else if (r2.empty)
        {
            return 1;
        }
        const comparison = pred(r1, r2);
        if (comparison != 0)
        {
            return comparison;
        }
    }
    return 0;
}
