/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * Bit manipulation.
 *
 * Copyright: Eugene Wissner 2018.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 * Source: $(LINK2 https://github.com/caraus-ecms/tanya/blob/master/source/tanya/bitmanip.d,
 *                 tanya/bitmanip.d)
 */
module tanya.bitmanip;

import tanya.meta.metafunction;
import tanya.meta.trait;
import tanya.meta.transform;

/**
 * Determines whether $(D_PARAM E) is a $(D_KEYWORD enum), whose members can be
 * used as bit flags.
 *
 * This is the case if all members of $(D_PARAM E) are integral numbers that
 * are either 0 or positive integral powers of 2.
 *
 * Params:
 *  E = Some $(D_KEYWORD enum).
 *
 * Returns: $(D_KEYWORD true) if $(D_PARAM E) contains only bit flags,
 *          $(D_KEYWORD false) otherwise.
 */
template isBitFlagEnum(E)
{
    enum bool isValid(OriginalType!E x) = x == 0
                                       || (x > 0 && ((x & (x - 1)) == 0));
    static if (isIntegral!E)
    {
        enum bool isBitFlagEnum = allSatisfy!(isValid, EnumMembers!E);
    }
    else
    {
        enum bool isBitFlagEnum = false;
    }
}

///
@nogc nothrow pure @safe unittest
{
    enum Valid
    {
        none = 0,
        one = 1 << 0,
        two = 1 << 1,
    }
    static assert(isBitFlagEnum!Valid);

    enum Invalid
    {
        one,
        two,
        three,
        four,
    }
    static assert(!isBitFlagEnum!Invalid);

    enum Negative
    {
        one = -1,
        two = -2,
    }
    static assert(!isBitFlagEnum!Negative);
}

/**
 * Validates that $(D_PARAM field) contains only bits from $(D_PARAM E).
 *
 * Params:
 *  E     = Some $(D_KEYWORD enum).
 *  field = Bit field.
 *
 * Returns: $(D_KEYWORD true) if $(D_PARAM field) is valid, $(D_KEYWORD false)
 *          otherwise.
 */
bool containsBitFlags(E)(E field)
if (isBitFlagEnum!E)
{
    OriginalType!E fillField()
    {
        typeof(return) full;
        static foreach (member; EnumMembers!E)
        {
            full |= member;
        }
        return full;
    }
    enum OriginalType!E full = fillField();
    return (field & ~full) == OriginalType!E.init;
}

///
@nogc nothrow pure @safe unittest
{
    enum E
    {
        one,
        two,
        three,
    }
    assert(containsBitFlags(E.one | E.two));
    assert(!containsBitFlags(cast(E) 0x8));
}

/**
 * Allows to use $(D_KEYWORD enum) values as a set of bit flags.
 *
 * $(D_PSYMBOL BitFlags) behaves the same as a bit field of type $(D_PARAM E),
 * but does additional cheks to ensure that the bit field contains only valid
 * values, this is only values from $(D_PARAM E).
 *
 * Params:
 *  E = Some $(D_KEYWORD enum).
 */
struct BitFlags(E)
if (isBitFlagEnum!E)
{
    private OriginalType!E field;

    /**
     * Constructs $(D_PSYMBOL BitFlags) from $(D_PARAM field).
     *
     * Params:
     *  field = Bits to be set.
     */
    this(E field)
    {
        this.field = field;
    }

    /**
     * Converts $(D_PSYMBOL BitFlags) to a boolean.
     *
     * It is $(D_KEYWORD true) if any bit is set, $(D_KEYWORD false) otherwise.
     *
     * Returns: $(D_KEYWORD true) if this $(D_PSYMBOL BitFlags) contains any
     *          set bits, $(D_KEYWORD false) otherwise.
     */
    bool opCast(T : bool)()
    {
        return this.field != 0;
    }

    /**
     * Converts to the original type of $(D_PARAM E) ($(D_KEYWORD int) by
     * default).
     *
     * Returns: $(D_KEYWORD this) as $(D_INLINECODE OriginalType!T).
     */
    OriginalType!E opCast(T : OriginalType!E)() const
    {
        return this.field;
    }

    /**
     * Tests (&), sets (|) or toggles (^) bits.
     *
     * Params:
     *  op   = Operation.
     *  that = 0 or more bit flags.
     *
     * Returns: New $(D_PSYMBOL BitFlags) object.
     */
    BitFlags opBinary(string op)(E that) const
    if (op == "&" || op == "|" || op == "^")
    {
        BitFlags result = this;
        mixin("return result " ~ op ~ "= that;");
    }

    /// ditto
    BitFlags opBinary(string op)(BitFlags that) const
    if (op == "&" || op == "|" || op == "^")
    {
        BitFlags result = this;
        mixin("return result " ~ op ~ "= that;");
    }

    /// ditto
    BitFlags opBinaryRight(string op)(E that) const
    if (op == "&" || op == "|" || op == "^")
    {
        BitFlags result = this;
        mixin("return result " ~ op ~ "= that;");
    }

    /**
     * Tests (&), sets (|) or toggles (^) bits.
     *
     * Params:
     *  op   = Operation.
     *  that = 0 or more bit flags.
     *
     * Returns: $(D_KEYWORD this).
     */
    ref BitFlags opOpAssign(string op)(E that)
    if (op == "&" || op == "|" || op == "^")
    {
        mixin("this.field " ~ op ~ "= that;");
        return this;
    }

    /// ditto
    ref BitFlags opOpAssign(string op)(BitFlags that)
    if (op == "&" || op == "|" || op == "^")
    {
        mixin("this.field " ~ op ~ "= that.field;");
        return this;
    }

    /**
     * Inverts all bit flags.
     *
     * Returns: New $(D_PSYMBOL BitFlags) object with all bits inverted.
     */
    BitFlags opUnary(string op : "~")() const
    {
        BitFlags result;
        result.field  = ~this.field;
        return result;
    }

    /**
     * Assigns a bit field.
     *
     * Params:
     *  that = Bit field of type $(D_PARAM E).
     *
     * Returns: $(D_KEYWORD this).
     */
    ref BitFlags opAssign(E that)
    {
        this.field = that;
        return this;
    }

    /**
     * Compares this $(D_PSYMBOL BitFlags) object to another bit field.
     *
     * Params:
     *  that = $(D_PSYMBOL BitFlags) object or a bit field of type
     *         $(D_PARAM E).
     *
     * Returns: $(D_KEYWORD true) if $(D_KEYWORD this) and $(D_PARAM that)
     *          contain the same bits ,$(D_KEYWORD false) otherwise.
     */
    bool opEquals(E that) const
    {
        return this.field == that;
    }

    /// ditto
    bool opEquals(BitFlags that) const
    {
        return this.field == that.field;
    }

    /**
     * Generates a hash value of this object.
     *
     * Returns: Hash value.
     */
    size_t toHash() const
    {
        return cast(size_t) this.field;
    }
}

@nogc nothrow pure @safe unittest
{
    enum E : int
    {
        one = 1,
    }

    // Casts to a boolean
    assert(BitFlags!E(E.one));
    assert(!BitFlags!E());

    // Assigns to and compares with a single value
    {
        BitFlags!E bitFlags;
        bitFlags = E.one;
        assert(bitFlags == E.one);
    }
    // Assigns to and compares with the same type
    {
        auto bitFlags1 = BitFlags!E(E.one);
        BitFlags!E bitFlags2;
        bitFlags2 = bitFlags1;
        assert(bitFlags1 == bitFlags2);
    }
    assert((BitFlags!E() | E.one) == BitFlags!E(E.one));
    assert((BitFlags!E() | BitFlags!E(E.one)) == BitFlags!E(E.one));

    assert(!(BitFlags!E() & BitFlags!E(E.one)));

    assert(!(BitFlags!E(E.one) ^ E.one));
    assert(BitFlags!E() ^ BitFlags!E(E.one));

    assert(~BitFlags!E());

    assert(BitFlags!E().toHash() == 0);
    assert(BitFlags!E(E.one).toHash() != 0);

    // opBinaryRight is allowed
    static assert(is(typeof({ E.one | BitFlags!E(); })));
}

/**
 * Creates a $(D_PSYMBOL BitFlags) object initialized with $(D_PARAM field).
 *
 * Params:
 *  E     = Some $(D_KEYWORD enum).
 *  field = Bits to be set.
 */
BitFlags!E bitFlags(E)(E field)
if (isBitFlagEnum!E)
{
    return BitFlags!E(field);
}

///
@nogc nothrow pure @safe unittest
{
    enum E
    {
        one = 1 << 0,
        two = 1 << 1,
        three = 1 << 2,
    }
    // Construct with E.one and E.two set
    auto flags = bitFlags(E.one | E.two);

    // Test wheter E.one is set
    assert(flags & E.one);

    // Toggle E.one
    flags ^= E.one;
    assert(!(flags & E.one));

    // Set E.three
    flags |= E.three;
    assert(flags & E.three);

    // Clear E.three
    flags &= ~E.three;
    assert(!(flags & E.three));
}
