/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * This module defines primitives for working with ranges.
 *
 * Copyright: Eugene Wissner 2017-2020.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 * Source: $(LINK2 https://github.com/caraus-ecms/tanya/blob/master/source/tanya/range/primitive.d,
 *                 tanya/range/primitive.d)
 */
module tanya.range.primitive;

import std.algorithm.comparison;
import tanya.memory.lifetime;
import tanya.meta.trait;
import tanya.meta.transform;
import tanya.range.array;

/**
 * Returns the element type of the range $(D_PARAM R).
 *
 * Element type is the return type of such primitives like
 * $(D_INLINECODE R.front) and (D_INLINECODE R.back) or the array base type.
 * If $(D_PARAM R) is not a range, its element type is $(D_KEYWORD void).
 *
 * If $(D_PARAM R) is a string, $(D_PSYMBOL ElementType) doesn't distinguish
 * between narrow and wide strings, it just returns the base type of the
 * underlying array ($(D_KEYWORD char), $(D_KEYWORD wchar) or
 * $(D_KEYWORD dchar)).
 *
 * Params:
 *  R = Range type.
 *
 * Returns: Element type of the range $(D_PARAM R).
 */
template ElementType(R)
{
    static if (is(R U : U[]))
    {
        alias ElementType = U;
    }
    else static if (isInputRange!R)
    {
        alias ElementType = ReturnType!((R r) => r.front());
    }
    else
    {
        alias ElementType = void;
    }
}

/**
 * Detects whether $(D_PARAM R) has a length property.
 *
 * $(D_PARAM R) does not have to be a range to support the length.
 *
 * Length mustn't be a $(D_KEYWORD @property) or a function, it can be a member
 * variable or $(D_KEYWORD enum). But its type (or the type returned by the
 * appropriate function) should be $(D_KEYWORD size_t), otherwise
 * $(D_PSYMBOL hasLength) is $(D_KEYWORD false).
 *
 * All dynamic arrays except $(D_KEYWORD void)-arrays have length.
 *
 * Params:
 *  R = A type.
 *
 * Returns: $(D_KEYWORD true) if $(D_PARAM R) has a length property,
 *          $(D_KEYWORD false) otherwise.
 *
 * See_Also: $(D_PSYMBOL isInfinite).
 */
enum bool hasLength(R) = is(ReturnType!((R r) => r.length) == size_t);

///
@nogc nothrow pure @safe unittest
{
    static assert(hasLength!(char[]));
    static assert(hasLength!(int[]));
    static assert(hasLength!(const(int)[]));

    struct A
    {
        enum size_t length = 1;
    }
    static assert(hasLength!(A));

    struct B
    {
        @property size_t length() const @nogc nothrow pure @safe
        {
            return 0;
        }
    }
    static assert(hasLength!(B));

    struct C
    {
        @property const(size_t) length() const @nogc nothrow pure @safe
        {
            return 0;
        }
    }
    static assert(!hasLength!C);
}

/**
 * Determines whether $(D_PARAM R) is a forward range with slicing support
 * ($(D_INLINECODE R[i .. j])).
 *
 * For finite ranges, the result of `opSlice()` must be of the same type as the
 * original range. If the range defines opDollar, it must support subtraction.
 *
 * For infinite ranges, the result of `opSlice()` must be of the same type as
 * the original range only if it defines `opDollar()`. Otherwise it can be any
 * forward range.
 *
 * For both finite and infinite ranges, the result of `opSlice()` must have
 * length.
 *
 * Params:
 *  R = The type to be tested.
 *
 * Returns: $(D_KEYWORD true) if $(D_PARAM R) supports slicing,
 *          $(D_KEYWORD false) otherwise.
 */
template hasSlicing(R)
{
    private enum bool hasDollar = is(typeof((R r) => r[0 .. $]));
    private enum bool subDollar = !hasDollar
                               || isInfinite!R
                               || is(ReturnType!((R r) => r[0 .. $ - 1]) == R);

    static if (isForwardRange!R
            && is(ReturnType!((R r) => r[0 .. 0]) T)
            && (!hasDollar || is(ReturnType!((R r) => r[0 .. $]) == R))
            && subDollar
            && isForwardRange!(ReturnType!((ref R r) => r[0 .. 0])))
    {
        enum bool hasSlicing = (is(T == R) || isInfinite!R)
                            && hasLength!T;
    }
    else
    {
        enum bool hasSlicing = false;
    }
}

///
@nogc nothrow pure @safe unittest
{
    static assert(hasSlicing!(int[]));
    static assert(hasSlicing!(const(int)[]));
    static assert(hasSlicing!(dstring));
    static assert(hasSlicing!(string));
    static assert(!hasSlicing!(const int[]));
    static assert(!hasSlicing!(void[]));

    struct A
    {
        int front() @nogc nothrow pure @safe
        {
            return 0;
        }
        void popFront() @nogc nothrow pure @safe
        {
        }
        bool empty() const  @nogc nothrow pure @safe
        {
            return false;
        }
        typeof(this) save() @nogc nothrow pure @safe
        {
            return this;
        }
        @property size_t length() const @nogc nothrow pure @safe
        {
            return 0;
        }
        typeof(this) opSlice(const size_t i, const size_t j)
        pure nothrow  @safe @nogc
        {
            return this;
        }
    }
    static assert(hasSlicing!A);

    struct B
    {
        struct Dollar
        {
        }
        int front() @nogc nothrow pure @safe
        {
            return 0;
        }
        void popFront() @nogc nothrow pure @safe
        {
        }
        bool empty() const @nogc nothrow pure @safe
        {
            return false;
        }
        typeof(this) save() @nogc nothrow pure @safe
        {
            return this;
        }
        @property size_t length() const @nogc nothrow pure @safe
        {
            return 0;
        }
        @property Dollar opDollar() const @nogc nothrow pure @safe
        {
            return Dollar();
        }
        typeof(this) opSlice(const size_t i, const Dollar j)
        pure nothrow  @safe @nogc
        {
            return this;
        }
    }
    static assert(!hasSlicing!B);

    struct C
    {
        int front() @nogc nothrow pure @safe
        {
            return 0;
        }
        void popFront() @nogc nothrow pure @safe
        {
        }
        enum bool empty = false;
        typeof(this) save() @nogc nothrow pure @safe
        {
            return this;
        }
        typeof(this) opSlice(const size_t i, const size_t j)
        pure nothrow  @safe @nogc
        {
            return this;
        }
    }
    static assert(!hasSlicing!C);

    struct D
    {
        struct Range
        {
            int front() @nogc nothrow pure @safe
            {
                return 0;
            }
            void popFront() @nogc nothrow pure @safe
            {
            }
            bool empty() const @nogc nothrow pure @safe
            {
                return true;
            }
            typeof(this) save() @nogc nothrow pure @safe
            {
                return this;
            }
            @property size_t length() const @nogc nothrow pure @safe
            {
                return 0;
            }
        }
        int front() @nogc nothrow pure @safe
        {
            return 0;
        }
        void popFront() @nogc nothrow pure @safe
        {
        }
        enum bool empty = false;
        typeof(this) save() @nogc nothrow pure @safe
        {
            return this;
        }
        Range opSlice(const size_t i, const size_t j)
        pure nothrow  @safe @nogc
        {
            return Range();
        }
    }
    static assert(hasSlicing!D);
}

private template isDynamicArrayRange(R)
{
    static if (is(R E : E[]))
    {
        enum bool isDynamicArrayRange = !is(E == void);
    }
    else
    {
        enum bool isDynamicArrayRange = false;
    }
}

private struct Primitive(Candidate, string primitive)
{
    auto ref returnType(ref Candidate candidate)
    {
        mixin("return candidate." ~ primitive ~ ";");
    }

    alias ReturnType = .ReturnType!returnType;
    static assert(!is(ReturnType == void));

    enum uint attributes = functionAttributes!returnType
                         & FunctionAttribute.ref_;

    bool opEquals(That)(That) const
    {
        return is(ReturnType == That.ReturnType)
            && attributes == That.attributes;
    }
}

/**
 * Determines whether $(D_PARAM R) is an input range.
 *
 * An input range should define following primitives:
 *
 * $(UL
 *  $(LI front)
 *  $(LI empty)
 *  $(LI popFront)
 * )
 *
 * Params:
 *  R = The type to be tested.
 *
 * Returns: $(D_KEYWORD true) if $(D_PARAM R) is an input range,
 *          $(D_KEYWORD false) otherwise.
 */
template isInputRange(R)
{
    static if (is(Primitive!(R, "front()") U)
            && is(ReturnType!((R r) => r.empty) == bool)
            && is(typeof(R.popFront())))
    {
        enum bool isInputRange = true;
    }
    else
    {
        enum bool isInputRange = isDynamicArrayRange!R;
    }
}

///
@nogc nothrow pure @safe unittest
{
    static struct Range
    {
        void popFront() @nogc nothrow pure @safe
        {
        }

        int front() @nogc nothrow pure @safe
        {
            return 0;
        }

        bool empty() const @nogc nothrow pure @safe
        {
            return true;
        }
    }
    static assert(isInputRange!Range);
    static assert(isInputRange!(int[]));
    static assert(!isInputRange!(void[]));
}

/**
 * Determines whether $(D_PARAM R) is a forward range.
 *
 * A forward range is an input range that also defines:
 *
 * $(UL
 *  $(LI save)
 * )
 *
 * Params:
 *  R = The type to be tested.
 *
 * Returns: $(D_KEYWORD true) if $(D_PARAM R) is a forward range,
 *          $(D_KEYWORD false) otherwise.
 *
 * See_Also: $(D_PSYMBOL isInputRange).
 */
template isForwardRange(R)
{
    static if (is(ReturnType!((R r) => r.save()) U))
    {
        enum bool isForwardRange = isInputRange!R && is(U == R);
    }
    else
    {
        enum bool isForwardRange = false;
    }
}

///
@nogc nothrow pure @safe unittest
{
    static struct Range
    {
        void popFront() @nogc nothrow pure @safe
        {
        }

        int front() @nogc nothrow pure @safe
        {
            return 0;
        }

        bool empty() const @nogc nothrow pure @safe
        {
            return true;
        }

        typeof(this) save() @nogc nothrow pure @safe
        {
            return this;
        }
    }
    static assert(isForwardRange!Range);
    static assert(isForwardRange!(int[]));
    static assert(!isForwardRange!(void[]));
}

/**
 * Determines whether $(D_PARAM R) is a bidirectional range.
 *
 * A bidirectional range is a forward range that also defines:
 *
 * $(UL
 *  $(LI back)
 *  $(LI popBack)
 * )
 *
 * Params:
 *  R = The type to be tested.
 *
 * Returns: $(D_KEYWORD true) if $(D_PARAM R) is a bidirectional range,
 *          $(D_KEYWORD false) otherwise.
 *
 * See_Also: $(D_PSYMBOL isForwardRange).
 */
template isBidirectionalRange(R)
{
    static if (is(Primitive!(R, "back()") U)
            && is(typeof(R.popBack())))
    {
        enum bool isBidirectionalRange = isForwardRange!R
                                      && (U() == Primitive!(R, "front()")());
    }
    else
    {
        enum bool isBidirectionalRange = isDynamicArrayRange!R;
    }
}

///
@nogc nothrow pure @safe unittest
{
    static struct Range
    {
        void popFront() @nogc nothrow pure @safe
        {
        }

        void popBack() @nogc nothrow pure @safe
        {
        }

        @property int front() @nogc nothrow pure @safe
        {
            return 0;
        }

        @property int back() @nogc nothrow pure @safe
        {
            return 0;
        }

        bool empty() const @nogc nothrow pure @safe
        {
            return true;
        }

        Range save() @nogc nothrow pure @safe
        {
            return this;
        }
    }
    static assert(isBidirectionalRange!Range);
    static assert(isBidirectionalRange!(int[]));
    static assert(!isBidirectionalRange!(void[]));
}

/**
 * Determines whether $(D_PARAM R) is a random-access range.
 *
 * A random-access range is a range that allows random access to its
 * elements by index using $(D_INLINECODE [])-operator (defined with
 * $(D_INLINECODE opIndex())). Further a random access range should
 * have a length or be infinite.
 *
 * Params:
 *  R = The type to be tested.
 *
 * Returns: $(D_KEYWORD true) if $(D_PARAM R) is a random-access range,
 *          $(D_KEYWORD false) otherwise.
 *
 * See_Also: $(D_PSYMBOL isInfinite),
 *           $(D_PSYMBOL hasLength).
 *
 * Note: This definition differs from `std.range.primitives.isRandomAccessRange`
 *  in the D standard library in that it does not also require $(D_PARAM R) to
 *  be a forward range and a bidirectional range. Those properties may be tested
 *  separately with $(D_PSYMBOL isForwardRange) and
 *  $(D_PSYMBOL isBidirectionalRange).
 */
template isRandomAccessRange(R)
{
    static if (is(Primitive!(R, "opIndex(size_t.init)") U))
    {
        enum bool isRandomAccessRange = isInputRange!R
                                     && (hasLength!R || isInfinite!R)
                                     && (U() == Primitive!(R, "front()")());
    }
    else
    {
        enum bool isRandomAccessRange = isDynamicArrayRange!R;
    }
}

///
@nogc nothrow pure @safe unittest
{
    static struct A
    {
        void popFront() @nogc nothrow pure @safe
        {
        }

        @property int front() @nogc nothrow pure @safe
        {
            return 0;
        }

        bool empty() const @nogc nothrow pure @safe
        {
            return true;
        }

        int opIndex(size_t) @nogc nothrow pure @safe
        {
            return 0;
        }

        size_t length() const @nogc nothrow pure @safe
        {
            return 0;
        }
    }
    static assert(isRandomAccessRange!A);
    static assert(isRandomAccessRange!(int[]));
    static assert(!isRandomAccessRange!(void[]));

    static struct B
    {
        void popFront() @nogc nothrow pure @safe
        {
        }

        @property int front() @nogc nothrow pure @safe
        {
            return 0;
        }

        enum bool empty = false;

        int opIndex(const size_t pos) @nogc nothrow pure @safe
        {
            return 0;
        }
    }
    static assert(isRandomAccessRange!B);
}

/**
 * Puts $(D_PARAM e) into the $(D_PARAM range).
 *
 * $(D_PSYMBOL R) should be an output range for $(D_PARAM E), i.e. at least one
 * of the following conditions should met:
 *
 * $(OL
 *  $(LI $(D_PARAM e) can be put into $(D_PARAM range) using
 *       $(D_INLINECODE range(e))
 *  $(LI $(D_PARAM e) can be assigned to $(D_INLINECODE range.front))
 *  )
 * )
 *
 * The method to put $(D_PARAM e) into $(D_PARAM range) is chosen based on the
 * order specified above.
 *
 * If $(D_PARAM E) is an input range and $(D_PARAM R) is an output range for
 * its elements as well, use $(D_PSYMBOL tanya.algorithm.mutation.copy)
 * instead.
 *
 * $(D_PARAM range) is advanced after putting an element into it if it is an
 * input range that doesn't define a `put`-method.
 *
 * Params:
 *  R     = Target range type.
 *  E     = Source element type.
 *  range = Target range.
 *  e     = Source element.
 *
 * See_Also: $(D_PSYMBOL isOutputRange).
 */
void put(R, E)(ref R range, auto ref E e)
{
    static if (is(typeof((R r, E e) => r(e))))
    {
        range(e);
    }
    else static if (isInputRange!R
                 && is(typeof((R r, E e) => r.front = e)))
    {
        range.front = e;
        range.popFront();
    }
    else
    {
        static assert(false, R.stringof ~ " is not an output range for "
                           ~ E.stringof);
    }
}

///
@nogc nothrow pure @safe unittest
{
    int[2] actual;
    auto slice = actual[];

    put(slice, 2);
    assert(actual == [2, 0]);
}

///
@nogc nothrow pure @safe unittest
{
    static struct OpCall
    {
        int e;

        void opCall(int e)
        {
            this.e = e;
        }
    }
    OpCall oc;
    put(oc, 2);
    assert(oc.e == 2);
}

/**
 * Determines whether $(D_PARAM R) is an output range for the elemens of type
 * $(D_PARAM E).
 *
 * If $(D_PARAM R) is an output range for the elements of type $(D_PARAM E)
 * if an element `e` of type $(D_PARAM E) can be put into the range instance
 * `r` in one of the following ways:
 *
 * $(TABLE
 *  $(TR
 *      $(TH Code)
 *      $(TH Scenario)
 *  )
 *  $(TR
 *      $(TD r(e))
 *      $(TD $(D_PARAM R) defines `opCall` for $(D_PARAM E).)
 *  )
 *  $(TR
 *      $(TD r.front = e)
 *      $(TD $(D_PARAM R) is an input range with assignable elements of type
 *           $(D_PARAM E).)
 *  )
 * )
 *
 * Output ranges don't have element type (so $(D_PSYMBOL ElementType) returns
 * $(D_KEYWORD void) when applied to an output range). It is because an output
 * range can support puting differently typed elements into it.
 *
 * Params:
 *  R = The type to be tested.
 *  E = Element type should be tested for.
 *
 * Returns: $(D_KEYWORD true) if $(D_PARAM R) is an output range for the
 *          elements of the type $(D_PARAM E), $(D_KEYWORD false) otherwise.
 *
 * See_Also: $(D_PSYMBOL put).
 */
template isOutputRange(R, E)
{
    static if (is(typeof((R r, E e) => put(r, e))))
    {
        enum bool isOutputRange = true;
    }
    else static if (isInputRange!E)
    {
        pragma(msg, "Deprecation. An input range whose element type is "
                  ~ "supported by the output range isn't considered itself to "
                  ~ "be a source for such an output range. Don't rely on this "
                  ~ "behavior and use tanya.algorithm.copy() to write one "
                  ~ "range into another one.");
        alias ET = ElementType!E;
        enum bool isOutputRange = is(typeof((R r, ET e) => put(r, e)));
    }
    else
    {
        enum bool isOutputRange = false;
    }
}

///
@nogc nothrow pure @safe unittest
{
    static struct R1
    {
        void opCall(int) @nogc nothrow pure @safe
        {
        }
    }
    static assert(isOutputRange!(R1, int));

    static struct R2
    {
        int value;

        void popFront() @nogc nothrow pure @safe
        {
        }

        ref int front() @nogc nothrow pure @safe
        {
            return value;
        }

        bool empty() const @nogc nothrow pure @safe
        {
            return true;
        }
    }
    static assert(isOutputRange!(R2, int));

    static struct R3
    {
        void popFront() @nogc nothrow pure @safe
        {
        }

        int front() @nogc nothrow pure @safe
        {
            return 0;
        }

        bool empty() const @nogc nothrow pure @safe
        {
            return true;
        }
    }
    static assert(!isOutputRange!(R3, int));
}

/**
 * Determines whether $(D_PARAM R) is an infinite range.
 *
 * An infinite range is an input range whose `empty` member is defined as
 * $(D_KEYWORD enum) which is always $(D_KEYWORD false).
 *
 * Params:
 *  R = A type.
 *
 * Returns: $(D_KEYWORD true) if $(D_PARAM R) is an infinite range,
 *          $(D_KEYWORD false) otherwise.
 */
template isInfinite(R)
{
    static if (isInputRange!R && is(typeof({enum bool e = R.empty;})))
    {
        enum bool isInfinite = R.empty == false;
    }
    else
    {
        enum bool isInfinite = false;
    }
}

///
@nogc nothrow pure @safe unittest
{
    static assert(!isInfinite!int);

    static struct NotRange
    {
        enum bool empty = false;
    }
    static assert(!isInfinite!NotRange);

    static struct InfiniteRange
    {
        void popFront() @nogc nothrow pure @safe
        {
        }
        @property int front() @nogc nothrow pure @safe
        {
            return 0;
        }
        enum bool empty = false;
    }
    static assert(isInfinite!InfiniteRange);

    static struct InputRange
    {
        void popFront() @nogc nothrow pure @safe
        {
        }
        @property int front() @nogc nothrow pure @safe
        {
            return 0;
        }
        @property bool empty() const @nogc nothrow pure @safe
        {
            return false;
        }
    }
    static assert(!isInfinite!InputRange);
}

/**
 * Removes exactly $(D_PARAM count) first elements from the input range
 * $(D_PARAM range).
 *
 * $(D_PARAM R) must have length or be infinite.
 *
 * Params:
 *  R     = Range type.
 *  range = Some input range.
 *  count = Number of elements to remove.
 *
 * See_Also: $(D_PSYMBOL popBackExactly),
 *           $(D_PSYMBOL popFrontN),
 *           $(D_PSYMBOL isInputRange),
 *           $(D_PSYMBOL hasLength),
 *           $(D_PSYMBOL isInfinite).
 *
 * Precondition: If $(D_PARAM R) has length, it must be less than or equal to
 *               $(D_PARAM count).
 */
void popFrontExactly(R)(ref R range, size_t count)
if (isInputRange!R && (hasLength!R || isInfinite!R))
in
{
    static if (hasLength!R)
    {
        assert(count <= range.length);
    }
}
do
{
    static if (hasSlicing!R)
    {
        range = range[count .. $];
    }
    else
    {
        while (count-- != 0)
        {
            range.popFront();
        }
    }
}

///
@nogc nothrow pure @safe unittest
{
    int[5] a = [1, 2, 3, 4, 5];
    auto slice = a[];

    popFrontExactly(slice, 3);
    assert(slice.length == 2);
    assert(slice[0] == 4);
    assert(slice[$ - 1] == 5);

    popFrontExactly(slice, 2);
    assert(slice.length == 0);
}

/**
 * Removes exactly $(D_PARAM count) last elements from the bidirectional range
 * $(D_PARAM range).
 *
 * $(D_PARAM R) must have length or be infinite.
 *
 * Params:
 *  R     = Range type.
 *  range = Some bidirectional range.
 *  count = Number of elements to remove.
 *
 * See_Also: $(D_PSYMBOL popFrontExactly),
 *           $(D_PSYMBOL popBackN),
 *           $(D_PSYMBOL isBidirectionalRange),
 *           $(D_PSYMBOL hasLength),
 *           $(D_PSYMBOL isInfinite).
 *
 * Precondition: If $(D_PARAM R) has length, it must be less than or equal to
 *               $(D_PARAM count).
 */
void popBackExactly(R)(ref R range, size_t count)
if (isBidirectionalRange!R && (hasLength!R || isInfinite!R))
in
{
    static if (hasLength!R)
    {
        assert(count <= range.length);
    }
}
do
{
    static if (hasSlicing!R)
    {
        range = range[0 .. $ - count];
    }
    else
    {
        while (count-- != 0)
        {
            range.popBack();
        }
    }
}

///
@nogc nothrow pure @safe unittest
{
    int[5] a = [1, 2, 3, 4, 5];
    auto slice = a[];

    popBackExactly(slice, 3);
    assert(slice.length == 2);
    assert(slice[0] == 1);
    assert(slice[$ - 1] == 2);

    popBackExactly(slice, 2);
    assert(slice.length == 0);
}

/**
 * Removes maximum $(D_PARAM count) first elements from the input range
 * $(D_PARAM range).
 *
 * Params:
 *  R     = Range type.
 *  range = Some input range.
 *  count = Number of elements to remove.
 *
 * See_Also: $(D_PSYMBOL popBackN),
 *           $(D_PSYMBOL popFrontExactly),
 *           $(D_PSYMBOL isInputRange).
 */
void popFrontN(R)(ref R range, size_t count)
if (isInputRange!R)
{
    static if (hasLength!R && hasSlicing!R)
    {
        range = range[min(count, range.length) .. $];
    }
    else static if (hasLength!R)
    {
        size_t length = min(count, range.length);
        while (length--)
        {
            range.popFront();
        }
    }
    else
    {
        while (count-- != 0 && !range.empty)
        {
            range.popFront();
        }
    }
}

///
@nogc nothrow pure @safe unittest
{
    int[5] a = [1, 2, 3, 4, 5];
    auto slice = a[];

    popFrontN(slice, 3);
    assert(slice.length == 2);
    assert(slice[0] == 4);
    assert(slice[$ - 1] == 5);

    popFrontN(slice, 20);
    assert(slice.length == 0);
}

/**
 * Removes maximum $(D_PARAM count) last elements from the bidirectional range
 * $(D_PARAM range).
 *
 * Params:
 *  R     = Range type.
 *  range = Some bidirectional range.
 *  count = Number of elements to remove.
 *
 * See_Also: $(D_PSYMBOL popFrontN),
 *           $(D_PSYMBOL popBackExactly),
 *           $(D_PSYMBOL isBidirectionalRange).
 */
void popBackN(R)(ref R range, size_t count)
if (isBidirectionalRange!R)
{
    static if (hasLength!R && hasSlicing!R)
    {
        range = range[0 .. $ - min(count, range.length)];
    }
    else static if (hasLength!R)
    {
        size_t length = min(count, range.length);
        while (length--)
        {
            range.popBack();
        }
    }
    else
    {
        while (count-- != 0 && !range.empty)
        {
            range.popBack();
        }
    }
}

///
@nogc nothrow pure @safe unittest
{
    int[5] a = [1, 2, 3, 4, 5];
    auto slice = a[];

    popBackN(slice, 3);
    assert(slice.length == 2);
    assert(slice[0] == 1);
    assert(slice[$ - 1] == 2);

    popBackN(slice, 20);
    assert(slice.length == 0);
}

/**
 * Moves the front element of an input range.
 *
 * The front element is left in a valid but unspecified state.
 * $(D_PSYMBOL moveFront) doesn't advances the range, so `popFront` should be
 * probably called after this function.
 *
 * Params:
 *  R     = Type of the range.
 *  range = Input range.
 *
 * Returns: The front element of the $(D_PSYMBOL range).
 *
 * See_Also: $(D_PSYMBOL move).
 */
ElementType!R moveFront(R)(R range)
if (isInputRange!R)
{
    static if (!hasElaborateCopyConstructor!(ElementType!R))
    {
        return range.front;
    }
    else static if (is(typeof(((ref ElementType!R e) => e)(range.front))))
    {
        return move(range.front);
    }
    else
    {
        static assert(false, "Front element cannot be moved");
    }
}

///
@nogc nothrow pure @safe unittest
{
    // Has elements without a postblit constructor.
    int[2] a = 5;

    assert(moveFront(a[]) == 5);
}

/**
 * Moves the back element of a bidirectional range.
 *
 * The back element is left in a valid but unspecified state.
 * $(D_PSYMBOL moveBack) doesn't advances the range, so `popBack` should be
 * probably called after this function.
 *
 * Params:
 *  R     = Type of the range.
 *  range = Bidirectional range.
 *
 * Returns: The back element of the $(D_PSYMBOL range).
 *
 * See_Also: $(D_PSYMBOL move).
 */
ElementType!R moveBack(R)(R range)
if (isBidirectionalRange!R)
{
    static if (!hasElaborateCopyConstructor!(ElementType!R))
    {
        return range.back;
    }
    else static if (is(typeof(((ref ElementType!R e) => e)(range.back))))
    {
        return move(range.back);
    }
    else
    {
        static assert(false, "Back element cannot be moved");
    }
}

///
@nogc nothrow pure @safe unittest
{
    // Has elements without a postblit constructor.
    int[2] a = 5;

    assert(moveBack(a[]) == 5);
}

/**
 * Moves the element at the position $(D_PARAM n) out of the range.
 *
 * The moved element is left in a valid but unspecified state.
 *
 * Params:
 *  R     = Range type.
 *  range = Random-access range.
 *  n     = Element position.
 *
 * Returns: The element at the position $(D_PARAM n).
 *
 * See_Also: $(D_PSYMBOL move).
 */
ElementType!R moveAt(R)(R range, size_t n)
if (isRandomAccessRange!R)
{
    static if (!hasElaborateCopyConstructor!(ElementType!R))
    {
        return range[n];
    }
    else static if (is(typeof(((ref ElementType!R e) => e)(range[0]))))
    {
        return move(range[n]);
    }
    else
    {
        static assert(false, "Random element cannot be moved");
    }
}

///
@nogc nothrow pure @safe unittest
{
    // Has elements without a postblit constructor.
    int[3] a = 5;

    assert(moveAt(a[], 1) == 5);
}

/**
 * Determines whether $(D_PSYMBOL R) is a range containing mobile elements,
 * i.e. elements that can be moved out of the range.
 *
 * Having mobile elements means for an input range to support
 * $(D_PSYMBOL moveFront), for a bidirectional range - both,
 * $(D_PSYMBOL moveFront) and $(D_PSYMBOL moveBack), for a random-access
 * range - $(D_PSYMBOL moveFront) and $(D_PSYMBOL moveAt).
 *
 * Params:
 *  R = Range type.
 *
 * Returns: $(D_KEYWORD true) if $(D_PSYMBOL R) has mobile elements,
 *          $(D_KEYWORD false) otherwise.
 *
 * See_Also: $(D_PSYMBOL moveFront), $(D_PSYMBOL moveBack),
 *           $(D_PSYMBOL moveAt).
 */
template hasMobileElements(R)
{
    static if (isRandomAccessRange!R)
    {
        enum bool hasMobileElements = is(typeof((R r) => moveFront(r)))
                                   && is(typeof((R r) => moveAt(r, 0)));
    }
    else static if (isBidirectionalRange!R)
    {
        enum bool hasMobileElements = is(typeof((R r) => moveFront(r)))
                                   && is(typeof((R r) => moveBack(r)));
    }
    else
    {
        enum bool hasMobileElements = is(typeof((R r) => moveFront(r)));
    }
}

///
@nogc nothrow pure @safe unittest
{
    static assert(hasMobileElements!(int[]));
}

///
@nogc nothrow pure @safe unittest
{
    static struct Element
    {
        this(this) @nogc nothrow pure @safe
        {
        }
    }

    static struct R1
    {
        enum bool empty = false;

        Element front() @nogc nothrow pure @safe
        {
            return Element();
        }

        void popFront() @nogc nothrow pure @safe
        {
        }
    }
    static assert(!hasMobileElements!R1);

    static struct R2
    {
        enum bool empty = false;
        private Element front_;

        ref Element front() @nogc nothrow pure @safe
        {
            return front_;
        }

        void popFront() @nogc nothrow pure @safe
        {
        }
    }
    static assert(hasMobileElements!R2);
}

/**
 * Determines whether $(D_PARAM R) provides access to its elements by
 * reference.
 *
 * Params:
 *  R = Range type.
 *
 * Returns: $(D_KEYWORD true) if $(D_PARAM R) has lvalue elements,
 *          $(D_KEYWORD false) otherwise.
 */
template hasLvalueElements(R)
{
    private alias refDg = (ref ElementType!R e) => &e;

    static if (isRandomAccessRange!R)
    {
        enum bool hasLvalueElements = is(typeof(refDg(R.init.front)))
                                   && is(typeof(refDg(R.init[0])));
    }
    else static if (isBidirectionalRange!R)
    {
        enum bool hasLvalueElements = is(typeof(refDg(R.init.front)))
                                   && is(typeof(refDg(R.init.back)));
    }
    else
    {
        enum bool hasLvalueElements = is(typeof(refDg(R.init.front)));
    }
}

///
@nogc nothrow pure @safe unittest
{
    static struct R1
    {
        enum bool empty = false;

        int front() @nogc nothrow pure @safe
        {
            return 5;
        }

        void popFront() @nogc nothrow pure @safe
        {
        }
    }
    static assert(!hasLvalueElements!R1);

    static struct R2
    {
        int element;
        enum bool empty = false;

        ref const(int) front() const @nogc nothrow pure @safe
        {
            return element;
        }

        void popFront() @nogc nothrow pure @safe
        {
        }

        ref const(int) opIndex(size_t) const @nogc nothrow pure @safe
        {
            return element;
        }
    }
    static assert(hasLvalueElements!R2);
}

/**
 * Determines whether the elements of $(D_PARAM R) are assignable.
 *
 * Params:
 *  R = Range type.
 *
 * Returns: $(D_KEYWORD true) if the elements of $(D_PARAM R) are assignable
 *          $(D_KEYWORD false) otherwise.
 */
template hasAssignableElements(R)
{
    static if (isRandomAccessRange!R)
    {
        enum bool assignable = is(typeof({R.init.front = R.init.front;}))
                            && is(typeof({R.init[0] = R.init[0];}));
    }
    else static if (isBidirectionalRange!R)
    {
        enum bool assignable = is(typeof({R.init.front = R.init.front;}))
                            && is(typeof({R.init.back = R.init.back;}));
    }
    else
    {
        enum bool assignable = is(typeof({R.init.front = R.init.front;}));
    }
    enum bool hasAssignableElements = assignable;
}

///
@nogc nothrow pure @safe unittest
{
    static struct R1
    {
        int element;
        enum bool empty = false;

        ref int front() @nogc nothrow pure @safe
        {
            return element;
        }
        alias back = front;

        void popFront() @nogc nothrow pure @safe
        {
        }
        alias popBack = popFront;

        R1 save() const @nogc nothrow pure @safe
        {
            return this;
        }
    }
    static assert(hasAssignableElements!R1);

    static struct R2
    {
        int element;
        enum bool empty = false;

        ref const(int) front() const @nogc nothrow pure @safe
        {
            return element;
        }
        alias back = front;

        void popFront() @nogc nothrow pure @safe
        {
        }
        alias popBack = popFront;

        R2 save() const @nogc nothrow pure @safe
        {
            return this;
        }
    }
    static assert(!hasAssignableElements!R2);
}

/**
 * Determines whether the elements of $(D_PSYMBOL R) can be swapped with
 * $(D_PSYMBOL swap).
 *
 * Params:
 *  R = Range type.
 *
 * Returns: $(D_KEYWORD true) if $(D_PARAM R) has swappable elements,
 *          $(D_KEYWORD false) otherwise.
 */
template hasSwappableElements(R)
{
    static if (isRandomAccessRange!R)
    {
        enum bool hasSwappableElements = is(typeof(swap(R.init.front, R.init.front)))
                                      && is(typeof(swap(R.init[0], R.init[0])));
    }
    else static if (isBidirectionalRange!R)
    {
        enum bool hasSwappableElements = is(typeof(swap(R.init.front, R.init.front)))
                                      && is(typeof(swap(R.init.back, R.init.back)));
    }
    else
    {
        enum bool hasSwappableElements = is(typeof(swap(R.init.front, R.init.front)));
    }
}

///
@nogc nothrow pure @safe unittest
{
    static struct R1
    {
        int element;
        enum bool empty = false;

        ref int front() @nogc nothrow pure @safe
        {
            return element;
        }
        alias back = front;

        void popFront() @nogc nothrow pure @safe
        {
        }
        alias popBack = popFront;

        R1 save() const @nogc nothrow pure @safe
        {
            return this;
        }
    }
    static assert(hasSwappableElements!R1);

    static struct R2
    {
        int element;
        enum bool empty = false;

        int front() const @nogc nothrow pure @safe
        {
            return element;
        }
        alias back = front;

        void popFront() @nogc nothrow pure @safe
        {
        }
        alias popBack = popFront;

        R2 save() const @nogc nothrow pure @safe
        {
            return this;
        }
    }
    static assert(!hasSwappableElements!R2);
}

/**
 * Determines whether `r1.front` and `r2.front` point to the same element.
 *
 * Params:
 *  r1 = First range.
 *  r2 = Second range.
 *
 * Returns: $(D_KEYWORD true) if $(D_PARAM r1) and $(D_PARAM r2) have the same
 *          head, $(D_KEYWORD false) otherwise.
 */
bool sameHead(Range)(Range r1, Range r2) @trusted
if (isInputRange!Range && hasLvalueElements!Range)
{
    return &r1.front is &r2.front;
}

///
@nogc nothrow pure @safe unittest
{
    const int[2] array;

    auto r1 = array[];
    auto r2 = array[];

    assert(sameHead(r1, r2));
}

///
@nogc nothrow pure @safe unittest
{
    const int[2] array;

    auto r1 = array[];
    auto r2 = array[1 .. $];

    assert(!sameHead(r1, r2));
}

/**
 * Returns the first element and advances the range.
 *
 * If $(D_PARAM range) has lvalue elements, then $(D_PSYMBOL getAndPopFront)
 * returns by reference, otherwise the returned element is copied.
 *
 * Params:
 *  R     = Input range type.
 *  range = Input range.
 *
 * Returns: Front range element.
 *
 * See_Also: $(D_PSYMBOL getAndPopBack).
 */
ElementType!R getAndPopFront(R)(ref R range)
if (isInputRange!R)
in
{
    assert(!range.empty);
}
do
{
    static if (hasLvalueElements!R)
    {
        if (false)
        {
            // This code is removed by the compiler but ensures that
            // this function isn't @safe if range.front isn't @safe.
            auto _ = range.front();
        }
        auto el = (() @trusted => &range.front())();
    }
    else
    {
        auto el = range.front;
    }
    range.popFront();
    static if (hasLvalueElements!R)
    {
        return *el;
    }
    else
    {
        return el;
    }
}

///
@nogc nothrow pure @safe unittest
{
    int[3] array = [1, 2, 3];
    auto slice = array[];

    assert(getAndPopFront(slice) == 1);
    assert(slice.length == 2);
}

/**
 * Returns the last element and removes it from the range.
 *
 * If $(D_PARAM range) has lvalue elements, then $(D_PSYMBOL getAndPopBack)
 * returns by reference, otherwise the returned element is copied.
 *
 * Params:
 *  R     = Bidirectional range type.
 *  range = Bidirectional range.
 *
 * Returns: Last range element.
 *
 * See_Also: $(D_PSYMBOL getAndPopFront).
 */
auto ref getAndPopBack(R)(ref R range)
if (isBidirectionalRange!R)
in
{
    assert(!range.empty);
}
do
{
    static if (hasLvalueElements!R)
    {
        if (false)
        {
            // This code is removed by the compiler but ensures that
            // this function isn't @safe if range.back isn't @safe.
            auto _ = range.back();
        }
        auto el = (() @trusted => &range.back())();
    }
    else
    {
        auto el = range.back;
    }
    range.popBack();
    static if (hasLvalueElements!R)
    {
        return *el;
    }
    else
    {
        return el;
    }
}

///
@nogc nothrow pure @trusted unittest
{
    int[3] array = [1, 2, 3];
    auto slice = array[];

    assert(getAndPopBack(slice) == 3);
    assert(slice.length == 2);
}
