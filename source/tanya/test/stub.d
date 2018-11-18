/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * Range generators.
 *
 * Copyright: Eugene Wissner 2018.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 * Source: $(LINK2 https://github.com/caraus-ecms/tanya/blob/master/source/tanya/test/stub.d,
 *                 tanya/test/stub.d)
 */
module tanya.test.stub;

/**
 * Attribute signalizing that the generated range should contain the given
 * number of elements.
 *
 * $(D_PSYMBOL Count) should be always specified with some value and not as a
 * type, so $(D_INLINECODE Count(1)) instead just $(D_INLINECODE Count),
 * otherwise you can just omit $(D_PSYMBOL Count) and it will default to 0.
 *
 * $(D_PSYMBOL Count) doesn't generate `.length` property - use
 * $(D_PSYMBOL Length) for that.
 *
 * If neither $(D_PSYMBOL Length) nor $(D_PSYMBOL Infinite) is given,
 * $(D_ILNINECODE Count(0)) is assumed.
 *
 * This attribute conflicts with $(D_PSYMBOL Infinite) and $(D_PSYMBOL Length).
 */
struct Count
{
    /// Original range length.
    size_t count = 0;

    @disable this();

    /**
     * Constructs the attribute with the given length.
     *
     * Params:
     *  count = Original range length.
     */
    this(size_t count) @nogc nothrow pure @safe
    {
        this.count = count;
    }
}

/**
 * Attribute signalizing that the generated range should be infinite.
 *
 * This attribute conflicts with $(D_PSYMBOL Count) and $(D_PSYMBOL Length).
 */
struct Infinite
{
}

/**
 * Generates `.length` property for the range.
 *
 * The length of the range can be specified as a constructor argument,
 * otherwise it is 0.
 *
 * This attribute conflicts with $(D_PSYMBOL Count) and $(D_PSYMBOL Infinite).
 */
struct Length
{
    /// Original range length.
    size_t length = 0;
}

/**
 * Attribute signalizing that the generated range should return values by
 * reference.
 *
 * This atribute affects the return values of `.front`, `.back` and `[]`.
 */
struct WithLvalueElements
{
}

/**
 * Generates an input range.
 *
 * Params:
 *  E = Element type.
 */
mixin template InputRangeStub(E = int)
{
    import tanya.meta.metafunction : Alias;
    import tanya.meta.trait : getUDAs, hasUDA;

    /*
     * Aliases for the attribute lookups to access them faster
     */
    private enum bool infinite = hasUDA!(typeof(this), Infinite);
    private enum bool withLvalueElements = hasUDA!(typeof(this),
                                                   WithLvalueElements);
    private alias Count = getUDAs!(typeof(this), .Count);
    private alias Length = getUDAs!(typeof(this), .Length);

    static if (Count.length != 0)
    {
        private enum size_t count = Count[0].count;

        static assert (!infinite,
                       "Range cannot have count and be infinite at the same time");
        static assert (Length.length == 0,
                       "Range cannot have count and length at the same time");
    }
    else static if (Length.length != 0)
    {
        private enum size_t count = evalUDA!(Length[0]).length;

        static assert (!infinite,
                       "Range cannot have length and be infinite at the same time");
    }
    else static if (!infinite)
    {
        private enum size_t count = 0;
    }

    /*
     * Member generation
     */
    static if (infinite)
    {
        enum bool empty = false;
    }
    else
    {
        private size_t length_ = count;

        @property bool empty() const @nogc nothrow pure @safe
        {
            return this.length_ == 0;
        }
    }

    static if (withLvalueElements)
    {
        private E* element; // Pointer to enable range copying in save()
    }

    void popFront() @nogc nothrow pure @safe
    in (!empty)
    {
        static if (!infinite)
        {
            --this.length_;
        }
    }

    static if (withLvalueElements)
    {
        ref E front() @nogc nothrow pure @safe
        in (!empty)
        {
            return *this.element;
        }
    }
    else
    {
        E front() @nogc nothrow pure @safe
        in (!empty)
        {
            return E.init;
        }
    }

    static if (Length.length != 0)
    {
        size_t length() const @nogc nothrow pure @safe
        {
            return this.length_;
        }
    }
}

/**
 * Generates a forward range.
 *
 * This mixin includes input range primitives as well, but can be combined with
 * $(D_PSYMBOL RandomAccessRangeStub).
 *
 * Params:
 *  E = Element type.
 */
mixin template ForwardRangeStub(E = int)
{
    static if (!is(typeof(this.InputRangeMixin) == void))
    {
        mixin InputRangeStub!E InputRangeMixin;
    }

    auto save() @nogc nothrow pure @safe
    {
        return this;
    }
}

/**
 * Generates a bidirectional range.
 *
 * This mixin includes forward range primitives as well, but can be combined with
 * $(D_PSYMBOL RandomAccessRangeStub).
 *
 * Params:
 *  E = Element type.
 */
mixin template BidirectionalRangeStub(E = int)
{
    mixin ForwardRangeStub!E;

    void popBack() @nogc nothrow pure @safe
    in (!empty)
    {
        static if (!infinite)
        {
            --this.length_;
        }
    }

    static if (withLvalueElements)
    {
        ref E back() @nogc nothrow pure @safe
        in (!empty)
        {
            return *this.element;
        }
    }
    else
    {
        E back() @nogc nothrow pure @safe
        in (!empty)
        {
            return E.init;
        }
    }
}

/**
 * Generates a random-access range.
 *
 * This mixin includes input range primitives as well, but can be combined with
 * $(D_PSYMBOL ForwardRangeStub) or $(D_PSYMBOL BidirectionalRangeStub).
 *
 * Params:
 *  E = Element type.
 */
mixin template RandomAccessRangeStub(E = int)
{
    static if (!is(typeof(this.InputRangeMixin) == void))
    {
        mixin InputRangeStub!E InputRangeMixin;
    }

    static if (withLvalueElements)
    {
        ref E opIndex(size_t) @nogc nothrow pure @safe
        {
            return *this.element;
        }
    }
    else
    {
        E opIndex(size_t) @nogc nothrow pure @safe
        {
            return E.init;
        }
    }
}
