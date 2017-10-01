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

import tanya.meta.trait;
import tanya.meta.transform;

/**
 * Returns the element type of the range $(D_PARAM R).
 *
 * Element type is the return type of such primitives like
 * $(D_INLINECODE R.front) and (D_INLINECODE R.back) or the array base type.
 *
 * If $(D_PARAM R) is a string, $(D_PSYMBOL ElementType) doesn't distinguish
 * between narrow and wide strings, it just returns the base type of the
 * underlying array ($(D_KEYWORD char), $(D_KEYWORD wchar) or
 * $(D_KEYWORD dchar)).
 *
 * Params:
 *  R = Any range type.
 *
 * Returns: Element type of the range $(D_PARAM R).
 */
template ElementType(R)
if (isInputRange!R)
{
    static if (is(R U : U[]))
    {
        alias ElementType = U;
    }
    else
    {
        alias ElementType = ReturnType!((R r) => r.front());
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
    enum bool hasLength = is(ReturnType!((R r) => r.length) == size_t)
                       && !is(ElementType!R == void);
}

///
pure nothrow @safe @nogc unittest
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
        @property size_t length() const pure nothrow @safe @nogc
        {
            return 0;
        }
    }
    static assert(hasLength!(B));

    struct C
    {
        @property const(size_t) length() const pure nothrow @safe @nogc
        {
            return 0;
        }
    }
    static assert(!hasLength!(C));
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
pure nothrow @safe @nogc unittest
{
    static assert(hasSlicing!(int[]));
    static assert(hasSlicing!(const(int)[]));
    static assert(hasSlicing!(dstring));
    static assert(hasSlicing!(string));
    static assert(!hasSlicing!(const int[]));
    static assert(!hasSlicing!(void[]));

    struct A
    {
        int front() pure nothrow @safe @nogc
        {
            return 0;
        }
        void popFront() pure nothrow @safe @nogc
        {
        }
        bool empty() const pure nothrow @safe @nogc
        {
            return false;
        }
        typeof(this) save() pure nothrow @safe @nogc
        {
            return this;
        }
        @property size_t length() const pure nothrow @safe @nogc
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
        int front() pure nothrow @safe @nogc
        {
            return 0;
        }
        void popFront() pure nothrow @safe @nogc
        {
        }
        bool empty() const pure nothrow @safe @nogc
        {
            return false;
        }
        typeof(this) save() pure nothrow @safe @nogc
        {
            return this;
        }
        @property size_t length() const pure nothrow @safe @nogc
        {
            return 0;
        }
        @property Dollar opDollar() const pure nothrow @safe @nogc
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
        int front() pure nothrow @safe @nogc
        {
            return 0;
        }
        void popFront() pure nothrow @safe @nogc
        {
        }
        enum bool empty = false;
        typeof(this) save() pure nothrow @safe @nogc
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
            int front() pure nothrow @safe @nogc
            {
                return 0;
            }
            void popFront() pure nothrow @safe @nogc
            {
            }
            bool empty() const pure nothrow @safe @nogc
            {
                return true;
            }
            typeof(this) save() pure nothrow @safe @nogc
            {
                return this;
            }
            @property size_t length() const pure nothrow @safe @nogc
            {
                return 0;
            }
        }
        int front() pure nothrow @safe @nogc
        {
            return 0;
        }
        void popFront() pure nothrow @safe @nogc
        {
        }
        enum bool empty = false;
        typeof(this) save() pure nothrow @safe @nogc
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
        @property int front() pure nothrow @safe @nogc
        {
            return 0;
        }
        @property bool empty() const pure nothrow @safe @nogc
        {
            return false;
        }
        void popFront() pure nothrow @safe @nogc
        {
        }
    }
    mixin template BidirectionalRangeStub()
    {
        @property int back() pure nothrow @safe @nogc
        {
            return 0;
        }
        void popBack() pure nothrow @safe @nogc
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
            && is(ReturnType!((R r) => r.empty) == bool))
    {
        enum bool isInputRange = !is(U == void)
                              && is(typeof(R.popFront()));
    }
    else
    {
        enum bool isInputRange = isDynamicArrayRange!R;
    }
}

///
pure nothrow @safe @nogc unittest
{
    static struct Range
    {
        void popFront() pure nothrow @safe @nogc
        {
        }
        int front() pure nothrow @safe @nogc
        {
            return 0;
        }
        bool empty() const pure nothrow @safe @nogc
        {
            return true;
        }
    }
    static assert(isInputRange!Range);
    static assert(isInputRange!(int[]));
    static assert(!isInputRange!(void[]));
}

private pure nothrow @safe @nogc unittest
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
        int popFront() pure nothrow @safe @nogc
        {
            return 100;
        }
        int front() pure nothrow @safe @nogc
        {
            return 100;
        }
        bool empty() const pure nothrow @safe @nogc
        {
            return true;
        }
    }
    static assert(isInputRange!Range2);

    static struct Range3
    {
        void popFront() pure nothrow @safe @nogc
        {
        }
        void front() pure nothrow @safe @nogc
        {
        }
        bool empty() const pure nothrow @safe @nogc
        {
            return true;
        }
    }
    static assert(!isInputRange!Range3);

    static struct Range4
    {
        void popFront() pure nothrow @safe @nogc
        {
        }
        int front() pure nothrow @safe @nogc
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
        enum bool isForwardRange = isDynamicArrayRange!R;
    }
}

///
pure nothrow @safe @nogc unittest
{
    static struct Range
    {
        void popFront() pure nothrow @safe @nogc
        {
        }
        int front() pure nothrow @safe @nogc
        {
            return 0;
        }
        bool empty() const pure nothrow @safe @nogc
        {
            return true;
        }
        typeof(this) save() pure nothrow @safe @nogc
        {
            return this;
        }
    }
    static assert(isForwardRange!Range);
    static assert(isForwardRange!(int[]));
    static assert(!isForwardRange!(void[]));
}

private pure nothrow @safe @nogc unittest
{
    static struct Range1
    {
    }
    static struct Range2
    {
        mixin InputRangeStub;
        Range1 save() pure nothrow @safe @nogc
        {
            return Range1();
        }
    }
    static assert(!isForwardRange!Range2);

    static struct Range3
    {
        mixin InputRangeStub;
        const(typeof(this)) save() const pure nothrow @safe @nogc
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
    static if (is(ReturnType!((R r) => r.back()) U))
    {
        enum bool isBidirectionalRange = isForwardRange!R
                                      && is(U == ReturnType!((R r) => r.front()))
                                      && is(typeof(R.popBack()));
    }
    else
    {
        enum bool isBidirectionalRange = isDynamicArrayRange!R;
    }
}

///
pure nothrow @safe @nogc unittest
{
    static struct Range
    {
        void popFront() pure nothrow @safe @nogc
        {
        }
        void popBack() pure nothrow @safe @nogc
        {
        }
        @property int front() pure nothrow @safe @nogc
        {
            return 0;
        }
        @property int back() pure nothrow @safe @nogc
        {
            return 0;
        }
        bool empty() const pure nothrow @safe @nogc
        {
            return true;
        }
        Range save() pure nothrow @safe @nogc
        {
            return this;
        }
    }
    static assert(isBidirectionalRange!Range);
    static assert(isBidirectionalRange!(int[]));
    static assert(!isBidirectionalRange!(void[]));
}

private nothrow  @safe @nogc unittest
{
    static struct Range(T, U)
    {
        void popFront() pure nothrow @safe @nogc
        {
        }
        void popBack() pure nothrow @safe @nogc
        {
        }
        @property T front() pure nothrow @safe @nogc
        {
            return T.init;
        }
        @property U back() pure nothrow @safe @nogc
        {
            return U.init;
        }
        bool empty() const pure nothrow @safe @nogc
        {
            return true;
        }
        Range save() pure nothrow @safe @nogc
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
pure nothrow @safe @nogc unittest
{
    static struct A
    {
        void popFront() pure nothrow @safe @nogc
        {
        }
        void popBack() pure nothrow @safe @nogc
        {
        }
        @property int front() pure nothrow @safe @nogc
        {
            return 0;
        }
        @property int back() pure nothrow @safe @nogc
        {
            return 0;
        }
        bool empty() const pure nothrow @safe @nogc
        {
            return true;
        }
        typeof(this) save() pure nothrow @safe @nogc
        {
            return this;
        }
        int opIndex(const size_t pos) pure nothrow @safe @nogc
        {
            return 0;
        }
        size_t length() const pure nothrow @safe @nogc
        {
            return 0;
        }
    }
    static assert(isRandomAccessRange!A);
    static assert(isRandomAccessRange!(int[]));
    static assert(!isRandomAccessRange!(void[]));

    static struct B
    {
        void popFront() pure nothrow @safe @nogc
        {
        }
        @property int front() pure nothrow @safe @nogc
        {
            return 0;
        }
        enum bool empty = false;
        typeof(this) save() pure nothrow @safe @nogc
        {
            return this;
        }
        int opIndex(const size_t pos) pure nothrow @safe @nogc
        {
            return 0;
        }
    }
    static assert(isRandomAccessRange!B);
}

private pure nothrow @safe @nogc unittest
{
    static struct Range1
    {
        mixin InputRangeStub;
        mixin BidirectionalRangeStub;

        typeof(this) save() pure nothrow @safe @nogc
        {
            return this;
        }
        int opIndex(const size_t pos) pure nothrow @safe @nogc
        {
            return 0;
        }
    }
    static assert(!isRandomAccessRange!Range1);

    static struct Range2(Args...)
    {
        mixin InputRangeStub;
        mixin BidirectionalRangeStub;

        typeof(this) save() pure nothrow @safe @nogc
        {
            return this;
        }
        int opIndex(Args) pure nothrow @safe @nogc
        {
            return 0;
        }
        size_t length() const pure nothrow @safe @nogc
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

        typeof(this) save() pure nothrow @safe @nogc
        {
            return this;
        }
        int opIndex(const size_t pos1, const size_t pos2 = 0)
        pure nothrow @safe @nogc
        {
            return 0;
        }
        size_t length() const pure nothrow @safe @nogc
        {
            return 0;
        }
    }
    static assert(isRandomAccessRange!Range3);

    static struct Range4
    {
        mixin InputRangeStub;
        mixin BidirectionalRangeStub;

        typeof(this) save() pure nothrow @safe @nogc
        {
            return this;
        }
        int opIndex(const size_t pos1) pure nothrow @safe @nogc
        {
            return 0;
        }
        size_t opDollar() const pure nothrow @safe @nogc
        {
            return 0;
        }
    }
    static assert(!isRandomAccessRange!Range4);
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
pure nothrow @safe @nogc unittest
{
    static assert(!isInfinite!int);

    static struct NotRange
    {
        enum bool empty = false;
    }
    static assert(!isInfinite!NotRange);

    static struct InfiniteRange
    {
        void popFront() pure nothrow @safe @nogc
        {
        }
        @property int front() pure nothrow @safe @nogc
        {
            return 0;
        }
        enum bool empty = false;
    }
    static assert(isInfinite!InfiniteRange);

    static struct InputRange
    {
        void popFront() pure nothrow @safe @nogc
        {
        }
        @property int front() pure nothrow @safe @nogc
        {
            return 0;
        }
        @property bool empty() const pure nothrow @safe @nogc
        {
            return false;
        }
    }
    static assert(!isInfinite!InputRange);
}

private pure nothrow @safe @nogc unittest
{
    static struct StaticConstRange
    {
        void popFront() pure nothrow @safe @nogc
        {
        }
        @property int front() pure nothrow @safe @nogc
        {
            return 0;
        }
        static bool empty = false;
    }
    static assert(!isInfinite!StaticConstRange);

    static struct TrueRange
    {
        void popFront() pure nothrow @safe @nogc
        {
        }
        @property int front() pure nothrow @safe @nogc
        {
            return 0;
        }
        static const bool empty = true;
    }
    static assert(!isInfinite!TrueRange);
}
