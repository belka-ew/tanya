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
    if (is(To == From))
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
        return from & Signed!To.max;
    }
    else
    {
        return from & To.max;
    }
}

private /*pure nothrow @safe @nogc */unittest
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

    assert((cast(int) short.min).to!int == short.min);
    assert((cast(int) short.min + 1).to!int == short.min + 1);
    assert((cast(int) -1).to!int == -1);
    assert((cast(int) 0).to!int == 0);
    assert((cast(int) 1).to!int == 1);
    assert((cast(int) short.max - 1).to!int == short.max - 1);
    assert((cast(int) short.max).to!int == short.max);

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
}
