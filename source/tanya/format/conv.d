/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * This module provides functions for converting between different types.
 *
 * Copyright: Eugene Wissner 2017.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: Jeff Roberts, $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 * Source: $(LINK2 https://github.com/caraus-ecms/tanya/blob/master/source/tanya/format/conv.d,
 *                 tanya/format/conv.d)
 */
module tanya.format.conv;

import tanya.container.string;
import tanya.memory;
import tanya.memory.op;
import tanya.meta.trait;
import tanya.meta.transform;

version (unittest)
{
    import tanya.test.assertion;
}

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
deprecated("Use tanya.conv.to instead")
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
deprecated("Use tanya.conv.to instead")
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
deprecated("Use tanya.conv.to instead")
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

/// ditto
deprecated("Use tanya.conv.to instead")
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
deprecated("Use tanya.conv.to instead")
To to(To, From)(const From from)
if (is(Unqual!From == bool) && isNumeric!To && !is(Unqual!To == Unqual!From))
{
    return from;
}

/// ditto
deprecated("Use tanya.conv.to instead")
To to(To, From)(const From from)
if (is(Unqual!From == bool) && is(Unqual!To == String))
{
    return String(from ? "true" : "false");
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
deprecated("Use tanya.conv.to instead")
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
deprecated("Use tanya.conv.to instead")
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
