/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * This module provides functions for converting between different types.
 *
 * Copyright: Eugene Wissner 2017.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 */
module tanya.format.conv;

import std.traits;
import tanya.container.string;
import tanya.memory;

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

    /// Ditto.
    To to(From)(From from)
    if (is(Unqual!To == Unqual!From) || (isNumeric!From && isFloatingPoint!To))
    {
        return from;
    }
}

///
pure nothrow @safe @nogc unittest
{
    auto val = 5.to!int();
    assert(val == 5);
    static assert(is(typeof(val) == int));
}

private pure nothrow @safe @nogc unittest
{
    int val = 5;
    assert(val.to!int() == 5);
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

private pure nothrow @safe @nogc unittest
{
    // ubyte -> ushort
    assert((cast(ubyte) 0).to!ushort == 0);
    assert((cast(ubyte) 1).to!ushort == 1);
    assert((cast(ubyte) (ubyte.max - 1)).to!ushort == ubyte.max - 1);
    assert((cast(ubyte) ubyte.max).to!ushort == ubyte.max);

    // ubyte -> short
    assert((cast(ubyte) 0).to!short == 0);
    assert((cast(ubyte) 1).to!short == 1);
    assert((cast(ubyte) (ubyte.max - 1)).to!short == ubyte.max - 1);
    assert((cast(ubyte) ubyte.max).to!short == ubyte.max);
}

private unittest
{
    // ubyte <- ushort
    assert((cast(ushort) 0).to!ubyte == 0);
    assert((cast(ushort) 1).to!ubyte == 1);
    assert((cast(ushort) (ubyte.max - 1)).to!ubyte == ubyte.max - 1);
    assert((cast(ushort) ubyte.max).to!ubyte == ubyte.max);

    // ubyte <- short
    assert((cast(short) 0).to!ubyte == 0);
    assert((cast(short) 1).to!ubyte == 1);
    assert((cast(short) (ubyte.max - 1)).to!ubyte == ubyte.max - 1);
    assert((cast(short) ubyte.max).to!ubyte == ubyte.max);

    // short <-> int
    assert(short.min.to!int == short.min);
    assert((short.min + 1).to!int == short.min + 1);
    assert((cast(short) -1).to!int == -1);
    assert((cast(short) 0).to!int == 0);
    assert((cast(short) 1).to!int == 1);
    assert((short.max - 1).to!int == short.max - 1);
    assert(short.max.to!int == short.max);

    assert((cast(int) short.min).to!short == short.min);
    assert((cast(int) short.min + 1).to!short == short.min + 1);
    assert((cast(int) -1).to!short == -1);
    assert((cast(int) 0).to!short == 0);
    assert((cast(int) 1).to!short == 1);
    assert((cast(int) short.max - 1).to!short == short.max - 1);
    assert((cast(int) short.max).to!short == short.max);

    // uint <-> int
    assert((cast(uint) 0).to!int == 0);
    assert((cast(uint) 1).to!int == 1);
    assert((cast(uint) (int.max - 1)).to!int == int.max - 1);
    assert((cast(uint) int.max).to!int == int.max);

    assert((cast(int) 0).to!uint == 0);
    assert((cast(int) 1).to!uint == 1);
    assert((cast(int) (int.max - 1)).to!uint == int.max - 1);
    assert((cast(int) int.max).to!uint == int.max);
}

private unittest
{
    ConvException exception;
    try
    {
        assert(int.min.to!short == int.min);
    }
    catch (ConvException e)
    {
        exception = e;
    }
    assert(exception !is null);
    defaultAllocator.dispose(exception);
}

private unittest
{
    ConvException exception;
    try
    {
        assert(int.max.to!short == int.max);
    }
    catch (ConvException e)
    {
        exception = e;
    }
    assert(exception !is null);
    defaultAllocator.dispose(exception);
}

private unittest
{
    ConvException exception;
    try
    {
        assert(uint.max.to!ushort == ushort.max);
    }
    catch (ConvException e)
    {
        exception = e;
    }
    assert(exception !is null);
    defaultAllocator.dispose(exception);
}

private unittest
{
    ConvException exception;
    try
    {
        assert((-1).to!uint == -1);
    }
    catch (ConvException e)
    {
        exception = e;
    }
    assert(exception !is null);
    defaultAllocator.dispose(exception);
}

private @nogc unittest
{
    enum Test : int
    {
        one,
        two,
    }
    assert(Test.one.to!int == 0);
    assert(Test.two.to!int == 1);
}

/**
 * Converts a number to a boolean.
 *
 * Params:
 *  From = Source type.
 *  To   = Target type.
 *  from = Source value.
 *
 * Returns: $(D_KEYWORD true) if $(D_INLINECODE from > 0 && from <= 1),
 *          otherwise $(D_KEYWORD false).
 *
 * Throws: $(D_PSYMBOL ConvException) if $(D_PARAM from) is greater than `1` or
 *         less than `0`.
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

private @nogc unittest
{
    assert(0.0.to!bool == false);
    assert(0.2.to!bool == true);
    assert(0.5.to!bool == true);
    assert(1.0.to!bool == true);

    assert(0.to!bool == false);
    assert(1.to!bool == true);
}

private @nogc unittest
{
    ConvException exception;
    try
    {
        assert((-1).to!bool == true);
    }
    catch (ConvException e)
    {
        exception = e;
    }
    assert(exception !is null);
    defaultAllocator.dispose(exception);
}

private @nogc unittest
{
    ConvException exception;
    try
    {
        assert(2.to!bool == true);
    }
    catch (ConvException e)
    {
        exception = e;
    }
    assert(exception !is null);
    defaultAllocator.dispose(exception);
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
To to(To, From)(const From from)
if (is(Unqual!From == bool) && isNumeric!To && !is(Unqual!To == Unqual!From))
{
    return from;
}

///
pure nothrow @safe @nogc unittest
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

/// Ditto.
To to(To, From)(const From from)
if (is(Unqual!From == bool) && is(To == String))
{
    return String(from ? "true" : "false");
}

///
@nogc unittest
{
    assert(true.to!String == "true");
    assert(false.to!String == "false");
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
@nogc unittest
{
    assert(1.5.to!int == 1);
    assert(2147483646.5.to!int == 2147483646);
    assert((-2147483647.5).to!int == -2147483647);
    assert(2147483646.5.to!uint == 2147483646);
}

private @nogc unittest
{
    ConvException exception;
    try
    {
        assert(2147483647.5.to!int == 2147483647);
    }
    catch (ConvException e)
    {
        exception = e;
    }
    assert(exception !is null);
    defaultAllocator.dispose(exception);
}

private @nogc unittest
{
    ConvException exception;
    try
    {
        assert((-2147483648.5).to!int == -2147483648);
    }
    catch (ConvException e)
    {
        exception = e;
    }
    assert(exception !is null);
    defaultAllocator.dispose(exception);
}

private @nogc unittest
{
    ConvException exception;
    try
    {
        assert((-21474.5).to!uint == -21474);
    }
    catch (ConvException e)
    {
        exception = e;
    }
    assert(exception !is null);
    defaultAllocator.dispose(exception);
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
@nogc unittest
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

private @nogc unittest
{
    enum Test : uint
    {
        one,
        two,
    }

    ConvException exception;
    try
    {
        assert(5.to!Test == Test.one);
    }
    catch (ConvException e)
    {
        exception = e;
    }
    assert(exception !is null);
    defaultAllocator.dispose(exception);
}
