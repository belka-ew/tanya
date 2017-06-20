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
 * equal, does nothing.
 *
 * Params:
 *  From = Source type.
 *  To   = Target type.
 *  from = Source value.
 *
 * Returns: $(D_PARAM from).
 */
template to(To)
{
    ref To to(From)(ref From from)
    if (is(To == From))
    {
        return from;
    }

    To to(From)(From from)
    if (is(Unqual!To == Unqual!From))
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
 * integral type $(D_PARAM To). If the conversion isn't possible (for example
 * because $(D_PARAM from) is too small or too large to be represented by
 * $(D_PARAM To)), an exception is thrown.
 *
 * Params:
 *  From = Source type.
 *  To   = Target type.
 *  from = Source value.
 *
 * Returns: $(D_PARAM from) converted to $(D_PARAM To).
 *
 * Throws: $(D_PSYMBOL ConvException).
 */
To to(To, From)(From from)
if (isIntegral!From && isIntegral!To && !is(To == From))
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

/**
 * Converts a number to a boolean. If $(D_PARAM from) is greater than `1` or
 * less than `0`, an exception is thrown, `0` results in $(D_KEYWORD false) and
 * all other values result in $(D_KEYWORD true).
 *
 * Params:
 *  From = Source type.
 *  To   = Target type.
 *  from = Source value.
 *
 * Returns: $(D_KEYWORD true) if $(D_INLINECODE from > 0 && from <= 1),
 *          otherwise $(D_KEYWORD false).
 *
 * Throws: $(D_PSYMBOL ConvException).
 */
To to(To, From)(From from)
if (isNumeric!From && is(Unqual!To == bool) && !is(To == From))
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

private unittest
{
    assert(0.0.to!bool == false);
    assert(0.2.to!bool == true);
    assert(0.5.to!bool == true);
    assert(1.0.to!bool == true);

    assert(0.to!bool == false);
    assert(1.to!bool == true);
}

private unittest
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

private unittest
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
 * Converts a boolean to a number. $(D_KEYWORD true) is `1`, $(D_KEYWORD false)
 * is `0`.
 *
 * Params:
 *  From = Source type.
 *  To   = Target type.
 *  from = Source value.
 *
 * Returns: `1` if $(D_PARAM from) is $(D_KEYWORD true), otherwise `0`.
 */
To to(To, From)(From from)
if (is(Unqual!From == bool) && isNumeric!To && !is(To == From))
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
