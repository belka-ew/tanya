/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * This module defines primitives for working with ranges.
 *
 * Copyright: Eugene Wissner 2017.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 * Source: $(LINK2 https://github.com/caraus-ecms/tanya/blob/master/source/tanya/range/primitive.d,
 *                 tanya/range/primitive.d)
 */
module tanya.range.primitive;

import tanya.math;
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
template hasLength(R)
{
    enum bool hasLength = is(ReturnType!((R r) => r.length) == size_t);
}

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

version (unittest)
{
    mixin template InputRangeStub()
    {
        @property int front() @nogc nothrow pure @safe
        {
            return 0;
        }
        @property bool empty() const @nogc nothrow pure @safe
        {
            return false;
        }
        void popFront() @nogc nothrow pure @safe
        {
        }
    }
    mixin template BidirectionalRangeStub()
    {
        @property int back() @nogc nothrow pure @safe
        {
            return 0;
        }
        void popBack() @nogc nothrow pure @safe
        {
        }
    }
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
    static if (is(ReturnType!((R r) => r.front()) U)
            && is(ReturnType!((R r) => r.empty) == bool)
            && is(typeof(R.popFront())))
    {
        enum bool isInputRange = !is(U == void);
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

@nogc nothrow pure @safe unittest
{
    static struct Range1(T)
    {
        void popFront()
        {
        }
        int front()
        {
            return 0;
        }
        T empty() const
        {
            return true;
        }
    }
    static assert(!isInputRange!(Range1!int));
    static assert(!isInputRange!(Range1!(const bool)));

    static struct Range2
    {
        int popFront() @nogc nothrow pure @safe
        {
            return 100;
        }
        int front() @nogc nothrow pure @safe
        {
            return 100;
        }
        bool empty() const @nogc nothrow pure @safe
        {
            return true;
        }
    }
    static assert(isInputRange!Range2);

    static struct Range3
    {
        void popFront() @nogc nothrow pure @safe
        {
        }
        void front() @nogc nothrow pure @safe
        {
        }
        bool empty() const @nogc nothrow pure @safe
        {
            return true;
        }
    }
    static assert(!isInputRange!Range3);

    static struct Range4
    {
        void popFront() @nogc nothrow pure @safe
        {
        }
        int front() @nogc nothrow pure @safe
        {
            return 0;
        }
        enum bool empty = false;
    }
    static assert(isInputRange!Range4);
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

@nogc nothrow pure @safe unittest
{
    static struct Range1
    {
    }
    static struct Range2
    {
        mixin InputRangeStub;
        Range1 save() @nogc nothrow pure @safe
        {
            return Range1();
        }
    }
    static assert(!isForwardRange!Range2);

    static struct Range3
    {
        mixin InputRangeStub;
        const(typeof(this)) save() const @nogc nothrow pure @safe
        {
            return this;
        }
    }
    static assert(!isForwardRange!Range3);
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
    static if (is(ReturnType!((R r) => r.back()) U)
            && is(typeof(R.popBack())))
    {
        enum bool isBidirectionalRange = isForwardRange!R
                                      && is(U == ReturnType!((R r) => r.front()));
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

@nogc nothrow pure @safe unittest
{
    static struct Range(T, U)
    {
        void popFront() @nogc nothrow pure @safe
        {
        }
        void popBack() @nogc nothrow pure @safe
        {
        }
        @property T front() @nogc nothrow pure @safe
        {
            return T.init;
        }
        @property U back() @nogc nothrow pure @safe
        {
            return U.init;
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
    static assert(!isBidirectionalRange!(Range!(int, uint)));
    static assert(!isBidirectionalRange!(Range!(int, const int)));
}

/**
 * Determines whether $(D_PARAM R) is a random-access range.
 *
 * A random-access range is a range that allows random access to its
 * elements by index using $(D_INLINECODE [])-operator (defined with
 * $(D_INLINECODE opIndex())). Further a random access range should be a
 * bidirectional range that also has a length or an infinite forward range.
 *
 * Params:
 *  R = The type to be tested.
 *
 * Returns: $(D_KEYWORD true) if $(D_PARAM R) is a random-access range,
 *          $(D_KEYWORD false) otherwise.
 *
 * See_Also: $(D_PSYMBOL isBidirectionalRange),
 *           $(D_PSYMBOL isForwardRange),
 *           $(D_PSYMBOL isInfinite),
 *           $(D_PSYMBOL hasLength).
 */
template isRandomAccessRange(R)
{
    static if (is(ReturnType!((R r) => r.opIndex(size_t.init)) U))
    {
        private enum bool isBidirectional = isBidirectionalRange!R
                                         && hasLength!R;
        private enum bool isForward = isInfinite!R && isForwardRange!R;
        enum bool isRandomAccessRange = (isBidirectional || isForward)
                                     && is(U == ReturnType!((R r) => r.front()));
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
        typeof(this) save() @nogc nothrow pure @safe
        {
            return this;
        }
        int opIndex(const size_t pos) @nogc nothrow pure @safe
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
        typeof(this) save() @nogc nothrow pure @safe
        {
            return this;
        }
        int opIndex(const size_t pos) @nogc nothrow pure @safe
        {
            return 0;
        }
    }
    static assert(isRandomAccessRange!B);
}

@nogc nothrow pure @safe unittest
{
    static struct Range1
    {
        mixin InputRangeStub;
        mixin BidirectionalRangeStub;

        typeof(this) save() @nogc nothrow pure @safe
        {
            return this;
        }
        int opIndex(const size_t pos) @nogc nothrow pure @safe
        {
            return 0;
        }
    }
    static assert(!isRandomAccessRange!Range1);

    static struct Range2(Args...)
    {
        mixin InputRangeStub;
        mixin BidirectionalRangeStub;

        typeof(this) save() @nogc nothrow pure @safe
        {
            return this;
        }
        int opIndex(Args) @nogc nothrow pure @safe
        {
            return 0;
        }
        size_t length() const @nogc nothrow pure @safe
        {
            return 0;
        }
    }
    static assert(isRandomAccessRange!(Range2!size_t));
    static assert(!isRandomAccessRange!(Range2!()));
    static assert(!isRandomAccessRange!(Range2!(size_t, size_t)));

    static struct Range3
    {
        mixin InputRangeStub;
        mixin BidirectionalRangeStub;

        typeof(this) save() @nogc nothrow pure @safe
        {
            return this;
        }
        int opIndex(const size_t pos1, const size_t pos2 = 0)
        @nogc nothrow pure @safe
        {
            return 0;
        }
        size_t length() const @nogc nothrow pure @safe
        {
            return 0;
        }
    }
    static assert(isRandomAccessRange!Range3);

    static struct Range4
    {
        mixin InputRangeStub;
        mixin BidirectionalRangeStub;

        typeof(this) save() @nogc nothrow pure @safe
        {
            return this;
        }
        int opIndex(const size_t pos1) @nogc nothrow pure @safe
        {
            return 0;
        }
        size_t opDollar() const @nogc nothrow pure @safe
        {
            return 0;
        }
    }
    static assert(!isRandomAccessRange!Range4);
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
 *      $(TD r.put(e))
 *      $(TD $(D_PARAM R) defines `put` for $(D_PARAM E).)
 *  )
 *  $(TR
 *      $(TD r.front = e)
 *      $(TD $(D_PARAM R) is an input range, whose element type is
 *      $(D_PARAM E) and `front` is an lvalue.)
 *  )
 *  $(TR
 *      $(TD r(e))
 *      $(TD $(D_PARAM R) defines `opCall` for $(D_PARAM E).)
 *  )
 *  $(TR
 *      $(TD for (; !e.empty; e.popFront()) r.put(e.front) $(BR)
 *           for (; !e.empty; e.popFront(), r.popFront())
 *           r.front = e.front $(BR)
 *           for (; !e.empty; e.popFront()) r(e.front)
 *      )
 *      $(TD $(D_PARAM E) is input range, whose elements can be put into
 *           $(D_PARAM R) according to the rules described above in this table.
 *      )
 *  )
 * )
 *
 * Params:
 *  R = The type to be tested.
 *  E = Element type should be tested for.
 *
 * Returns: $(D_KEYWORD true) if $(D_PARAM R) is an output range for the
 *          elements of the type $(D_PARAM E), $(D_KEYWORD false) otherwise.
 */
template isOutputRange(R, E)
{
    private enum bool doPut(E) = is(typeof((R r, E e) => r.put(e)))
                              || (isInputRange!R
                              && is(typeof((R r, E e) => r.front = e)))
                              || is(typeof((R r, E e) => r(e)));

    static if (doPut!E)
    {
        enum bool isOutputRange = true;
    }
    else static if (isInputRange!E)
    {
        enum bool isOutputRange = doPut!(ElementType!E);
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
        void put(int) @nogc nothrow pure @safe
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

    static struct R4
    {
        void opCall(int) @nogc nothrow pure @safe
        {
        }
    }
    static assert(isOutputRange!(R4, int));

    static assert(isOutputRange!(R1, R3));
    static assert(isOutputRange!(R2, R3));
    static assert(isOutputRange!(R4, R3));
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

@nogc nothrow pure @safe unittest
{
    static struct StaticConstRange
    {
        void popFront() @nogc nothrow pure @safe
        {
        }
        @property int front() @nogc nothrow pure @safe
        {
            return 0;
        }
        static bool empty = false;
    }
    static assert(!isInfinite!StaticConstRange);

    static struct TrueRange
    {
        void popFront() @nogc nothrow pure @safe
        {
        }
        @property int front() @nogc nothrow pure @safe
        {
            return 0;
        }
        static const bool empty = true;
    }
    static assert(!isInfinite!TrueRange);
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
body
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
body
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

@nogc nothrow pure @safe unittest
{
    static struct InfiniteRange
    {
        private int i;

        InfiniteRange save() @nogc nothrow pure @safe
        {
            return this;
        }

        void popFront() @nogc nothrow pure @safe
        {
            ++this.i;
        }

        void popBack() @nogc nothrow pure @safe
        {
            --this.i;
        }

        @property int front() const @nogc nothrow pure @safe
        {
            return this.i;
        }

        @property int back() const @nogc nothrow pure @safe
        {
            return this.i;
        }

        enum bool empty = false;
    }
    {
        InfiniteRange range;
        popFrontExactly(range, 2);
        assert(range.front == 2);
        popFrontN(range, 2);
        assert(range.front == 4);
    }
    {
        InfiniteRange range;
        popBackExactly(range, 2);
        assert(range.back == -2);
        popBackN(range, 2);
        assert(range.back == -4);
    }
}

@nogc nothrow pure @safe unittest
{
    static struct Range
    {
        private int[5] a = [1, 2, 3, 4, 5];
        private size_t begin = 0, end = 5;

        Range save() @nogc nothrow pure @safe
        {
            return this;
        }

        void popFront() @nogc nothrow pure @safe
        {
            ++this.begin;
        }

        void popBack() @nogc nothrow pure @safe
        {
            --this.end;
        }

        @property int front() const @nogc nothrow pure @safe
        {
            return this.a[this.begin];
        }

        @property int back() const @nogc nothrow pure @safe
        {
            return this.a[this.end - 1];
        }

        @property bool empty() const @nogc nothrow pure @safe
        {
            return this.begin >= this.end;
        }
    }
    {
        Range range;

        popFrontN(range, 3);
        assert(range.front == 4);
        assert(range.back == 5);

        popFrontN(range, 20);
        assert(range.empty);
    }
    {
        Range range;

        popBackN(range, 3);
        assert(range.front == 1);
        assert(range.back == 2);

        popBackN(range, 20);
        assert(range.empty);
    }
}
