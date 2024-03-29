/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * This module provides functions for converting between different types.
 *
 * Copyright: Eugene Wissner 2017-2020.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 * Source: $(LINK2 https://github.com/caraus-ecms/tanya/blob/master/source/tanya/conv.d,
 *                 tanya/conv.d)
 */
module tanya.conv;

import std.traits : Unsigned, isNumeric;
import tanya.container.string;
import tanya.memory.allocator;
import tanya.meta.trait;
import tanya.meta.transform;
import tanya.range;

/**
 * Thrown if a type conversion fails.
 */
final class ConvException : Exception
{
    /**
     * Params:
     *  msg  = The message for the exception.
     *  file = The file where the exception occurred.
     *  line = The line number where the exception occurred.
     *  next = The previous exception in the chain of exceptions, if any.
     */
    this(string msg,
         string file = __FILE__,
         size_t line = __LINE__,
         Throwable next = null) @nogc @safe pure nothrow
    {
        super(msg, file, line, next);
    }
}

/*
 * Converts a string $(D_PARAM range) into an integral value of type
 * $(D_PARAM T) in $(D_PARAM base).
 *
 * The convertion stops when $(D_PARAM range) is empty of if the next character
 * cannot be converted because it is not a digit (with respect to the
 * $(D_PARAM base)) or if the reading the next character would cause integer
 * overflow. The function returns the value converted so far then. The front
 * element of the $(D_PARAM range) points to the first character cannot be
 * converted or $(D_PARAM range) is empty if the whole string could be
 * converted.
 *
 * Base must be between 2 and 36 inclursive. Default base is 10.
 *
 * The function doesn't handle the sign (+ or -) or number prefixes (like 0x).
 */
package T readIntegral(T, R)(ref R range, const ubyte base = 10)
if (isInputRange!R
        && isSomeChar!(ElementType!R)
        && isIntegral!T
        && isUnsigned!T)
in
{
    assert(base >= 2);
    assert(base <= 36);
}
do
{
    T boundary = cast(T) (T.max / base);
    if (range.empty)
    {
        return T.init;
    }

    T n;
    int digit;
    do
    {
        if (range.front >= 'a')
        {
            digit = range.front - 'W';
        }
        else if (range.front >= 'A' && range.front <= 'Z')
        {
            digit = range.front - '7';
        }
        else if (range.front >= '0' && range.front <= '9')
        {
            digit = range.front - '0';
        }
        else
        {
            return n;
        }
        if (digit >= base)
        {
            return n;
        }
        n = cast(T) (n * base + digit);
        range.popFront();

        if (range.empty)
        {
            return n;
        }
    }
    while (n < boundary);

    if (range.front >= 'a')
    {
        digit = range.front - 'W';
    }
    else if (range.front >= 'A')
    {
        digit = range.front - '7';
    }
    else if (range.front >= '0')
    {
        digit = range.front - '0';
    }
    else
    {
        return n;
    }
    if (n > cast(T) ((T.max - digit) / base))
    {
        return n;
    }
    n = cast(T) (n * base + digit);
    range.popFront();

    return n;
}

/**
 * If the source type $(D_PARAM From) and the target type $(D_PARAM To) are
 * equal, does nothing. If $(D_PARAM From) can be implicitly converted to
 * $(D_PARAM To), just returns $(D_PARAM from).
 *
 * Params:
 *  To = Target type.
 *
 * Returns: $(D_PARAM from).
 */
template to(To)
{
    /**
     * Params:
     *  From = Source type.
     *  from = Source value.
     */
    ref To to(From)(ref From from)
    if (is(To == From))
    {
        return from;
    }

    /// ditto
    To to(From)(From from)
    if (is(Unqual!To == Unqual!From) || (isNumeric!From && isFloatingPoint!To))
    {
        return from;
    }
}

///
@nogc nothrow pure @safe unittest
{
    auto val = 5.to!int();
    assert(val == 5);
    static assert(is(typeof(val) == int));
}

/**
 * Performs checked conversion from an integral type $(D_PARAM From) to an
 * integral type $(D_PARAM To).
 *
 * Params:
 *  From = Source type.
 *  To   = Target type.
 *  from = Source value.
 *
 * Returns: $(D_PARAM from) converted to $(D_PARAM To).
 *
 * Throws: $(D_PSYMBOL ConvException) if $(D_PARAM from) is too small or too
 *         large to be represented by $(D_PARAM To).
 */
To to(To, From)(From from)
if (isIntegral!From
 && isIntegral!To
 && !is(Unqual!To == Unqual!From)
 && !is(To == enum))
{
    static if ((isUnsigned!From && isSigned!To && From.sizeof == To.sizeof)
            || From.sizeof > To.sizeof)
    {
        if (from > To.max)
        {
            throw make!ConvException(defaultAllocator,
                                     "Positive integer overflow");
        }
    }
    static if (isSigned!From)
    {
        static if (isUnsigned!To)
        {
            if (from < 0)
            {
                throw make!ConvException(defaultAllocator,
                                         "Negative integer overflow");
            }
        }
        else static if (From.sizeof > To.sizeof)
        {
            if (from < To.min)
            {
                throw make!ConvException(defaultAllocator,
                                         "Negative integer overflow");
            }
        }
    }
    static if (From.sizeof <= To.sizeof)
    {
        return from;
    }
    else static if (isSigned!To)
    {
        return cast(To) from;
    }
    else
    {
        return from & To.max;
    }
}

/**
 * Converts a floating point number to an integral type.
 *
 * Params:
 *  From = Source type.
 *  To   = Target type.
 *  from = Source value.
 *
 * Returns: Truncated $(D_PARAM from) (everything after the decimal point is
 *          dropped).
 *
 * Throws: $(D_PSYMBOL ConvException) if
 *         $(D_INLINECODE from < To.min || from > To.max).
 */
To to(To, From)(From from)
if (isFloatingPoint!From
 && isIntegral!To
 && !is(Unqual!To == Unqual!From)
 && !is(To == enum))
{
    if (from > To.max)
    {
        throw make!ConvException(defaultAllocator,
                                 "Positive number overflow");
    }
    else if (from < To.min)
    {
        throw make!ConvException(defaultAllocator,
                                 "Negative number overflow");
    }
    return cast(To) from;
}

///
@nogc pure @safe unittest
{
    assert(1.5.to!int == 1);
    assert(2147483646.5.to!int == 2147483646);
    assert((-2147483647.5).to!int == -2147483647);
    assert(2147483646.5.to!uint == 2147483646);
}

/**
 * Performs checked conversion from an integral type $(D_PARAM From) to an
 * $(D_KEYWORD enum).
 *
 * Params:
 *  From = Source type.
 *  To   = Target type.
 *  from = Source value.
 *
 * Returns: $(D_KEYWORD enum) value.
 *
 * Throws: $(D_PSYMBOL ConvException) if $(D_PARAM from) is not a member of
 *         $(D_PSYMBOL To).
 */
To to(To, From)(From from)
if (isIntegral!From && is(To == enum))
{
    foreach (m; EnumMembers!To)
    {
        if (from == m)
        {
            return m;
        }
    }
    throw make!ConvException(defaultAllocator,
                             "Value not found in enum '" ~ To.stringof ~ "'");
}

///
@nogc pure @safe unittest
{
    enum Test : int
    {
        one,
        two,
    }
    static assert(is(typeof(1.to!Test) == Test));
    assert(0.to!Test == Test.one);
    assert(1.to!Test == Test.two);
}

/**
 * Converts $(D_PARAM from) to a boolean.
 *
 * If $(D_PARAM From) is a numeric type, then `1` becomes $(D_KEYWORD true),
 * `0` $(D_KEYWORD false). Otherwise $(D_PSYMBOL ConvException) is thrown.
 *
 * If $(D_PARAM To) is a string (built-in string or $(D_PSYMBOL String)),
 * then `"true"` or `"false"` are converted to the appropriate boolean value.
 * Otherwise $(D_PSYMBOL ConvException) is thrown.
 *
 * Params:
 *  From = Source type.
 *  To   = Target type.
 *  from = Source value.
 *
 * Returns: $(D_KEYWORD from) converted to a boolean.
 *
 * Throws: $(D_PSYMBOL ConvException) if $(D_PARAM from) isn't convertible.
 */
To to(To, From)(From from)
if (isNumeric!From && is(Unqual!To == bool) && !is(Unqual!To == Unqual!From))
{
    if (from == 0)
    {
        return false;
    }
    else if (from < 0)
    {
        throw make!ConvException(defaultAllocator,
                                 "Negative number overflow");
    }
    else if (from <= 1)
    {
        return true;
    }
    throw make!ConvException(defaultAllocator,
                             "Positive number overflow");
}

///
@nogc pure @safe unittest
{
    assert(!0.0.to!bool);
    assert(0.2.to!bool);
    assert(0.5.to!bool);
    assert(1.0.to!bool);

    assert(!0.to!bool);
    assert(1.to!bool);
}

/// ditto
To to(To, From)(auto ref const From from)
if ((is(From == String) || isSomeString!From) && is(Unqual!To == bool))
{
    if (from == "true")
    {
        return true;
    }
    else if (from == "false")
    {
        return false;
    }
    throw make!ConvException(defaultAllocator,
                             "String doesn't contain a boolean value");
}

///
@nogc pure @safe unittest
{
    assert("true".to!bool);
    assert(!"false".to!bool);
    assert(String("true").to!bool);
    assert(!String("false").to!bool);

}

/**
 * Converts a boolean to $(D_PARAM To).
 *
 * If $(D_PARAM To) is a numeric type, then $(D_KEYWORD true) becomes `1`,
 * $(D_KEYWORD false) `0`.
 *
 * If $(D_PARAM To) is a $(D_PSYMBOL String), then `"true"` or `"false"`
 * is returned.
 *
 * Params:
 *  From = Source type.
 *  To   = Target type.
 *  from = Source value.
 *
 * Returns: $(D_PARAM from) converted to $(D_PARAM To).
 */
To to(To, From)(From from)
if (is(Unqual!From == bool) && isNumeric!To && !is(Unqual!To == Unqual!From))
{
    return from;
}

///
@nogc nothrow pure @safe unittest
{
    assert(true.to!float == 1.0);
    assert(true.to!double == 1.0);
    assert(true.to!ubyte == 1);
    assert(true.to!byte == 1);
    assert(true.to!ushort == 1);
    assert(true.to!short == 1);
    assert(true.to!uint == 1);
    assert(true.to!int == 1);

    assert(false.to!float == 0);
    assert(false.to!double == 0);
    assert(false.to!ubyte == 0);
    assert(false.to!byte == 0);
    assert(false.to!ushort == 0);
    assert(false.to!short == 0);
    assert(false.to!uint == 0);
    assert(false.to!int == 0);
}

/**
 * Converts a stringish range to an integral value.
 *
 * Params:
 *  From = Source type.
 *  To   = Target type.
 *  from = Source value.
 *
 * Returns: $(D_PARAM from) converted to $(D_PARAM To).
 *
 * Throws: $(D_PSYMBOL ConvException) if $(D_PARAM from) doesn't contain an
 *         integral value.
 */
To to(To, From)(auto ref From from)
if (isInputRange!From && isSomeChar!(ElementType!From) && isIntegral!To)
{
    if (from.empty)
    {
        throw make!ConvException(defaultAllocator, "Input range is empty");
    }

    static if (isSigned!To)
    {
        bool negative;
    }
    if (from.front == '-')
    {
        static if (isUnsigned!To)
        {
            throw make!ConvException(defaultAllocator,
                                     "Negative integer overflow");
        }
        else
        {
            negative = true;
            from.popFront();
        }
    }

    if (from.empty)
    {
        throw make!ConvException(defaultAllocator, "Input range is empty");
    }

    ubyte base = 10;
    if (from.front == '0')
    {
        from.popFront();
        if (from.empty)
        {
            return To.init;
        }
        else if (from.front == 'x' || from.front == 'X')
        {
            base = 16;
            from.popFront();
        }
        else if (from.front == 'b' || from.front == 'B')
        {
            base = 2;
            from.popFront();
        }
        else
        {
            base = 8;
        }
    }

    auto unsigned = readIntegral!(Unsigned!To, From)(from, base);
    if (!from.empty)
    {
        throw make!ConvException(defaultAllocator, "Integer overflow");
    }

    static if (isSigned!To)
    {
        if (negative)
        {
            auto predecessor = cast(Unsigned!To) (unsigned - 1);
            if (predecessor > cast(Unsigned!To) To.max)
            {
                throw make!ConvException(defaultAllocator,
                                         "Negative integer overflow");
            }
            return cast(To) (-(cast(Largest!(To, ptrdiff_t)) predecessor) - 1);
        }
        else if (unsigned > cast(Unsigned!To) To.max)
        {
            throw make!ConvException(defaultAllocator, "Integer overflow");
        }
        else
        {
            return unsigned;
        }
    }
    else
    {
        return unsigned;
    }
}

///
@nogc pure @safe unittest
{
    assert("1234".to!uint() == 1234);
    assert("1234".to!int() == 1234);
    assert("1234".to!int() == 1234);

    assert("0".to!int() == 0);
    assert("-0".to!int() == 0);

    assert("0x10".to!int() == 16);
    assert("0X10".to!int() == 16);
    assert("-0x10".to!int() == -16);

    assert("0b10".to!int() == 2);
    assert("0B10".to!int() == 2);
    assert("-0b10".to!int() == -2);

    assert("010".to!int() == 8);
    assert("-010".to!int() == -8);

    assert("-128".to!byte == cast(byte) -128);
}
