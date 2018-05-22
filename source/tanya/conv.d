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
 * Source: $(LINK2 https://github.com/caraus-ecms/tanya/blob/master/source/tanya/conv.d,
 *                 tanya/conv.d)
 */
module tanya.conv;

import tanya.container.string;
import tanya.format;
import tanya.memory;
import tanya.memory.op;
import tanya.meta.trait;
import tanya.meta.transform;

version (unittest)
{
    import tanya.test.assertion;
}

/**
 * Constructs a new object of type $(D_PARAM T) in $(D_PARAM memory) with the
 * given arguments.
 *
 * If $(D_PARAM T) is a $(D_KEYWORD class), emplace returns a class reference
 * of type $(D_PARAM T), otherwise a pointer to the constructed object is
 * returned.
 *
 * If $(D_PARAM T) is a nested class inside another class, $(D_PARAM outer)
 * should be an instance of the outer class.
 *
 * $(D_PARAM args) are arguments for the constructor of $(D_PARAM T). If
 * $(D_PARAM T) isn't an aggregate type and doesn't have a constructor,
 * $(D_PARAM memory) can be initialized to `args[0]` if `Args.length == 1`,
 * `Args[0]` should be implicitly convertible to $(D_PARAM T) then.
 *
 * Params:
 *  T     = Constructed type.
 *  U     = Type of the outer class if $(D_PARAM T) is a nested class.
 *  Args  = Types of the constructor arguments if $(D_PARAM T) has a constructor
 *          or the type of the initial value.
 *  outer = Outer class instance if $(D_PARAM T) is a nested class.
 *  args  = Constructor arguments if $(D_PARAM T) has a constructor or the
 *          initial value.
 *
 * Returns: New instance of type $(D_PARAM T) constructed in $(D_PARAM memory).
 *
 * Precondition: `memory.length == stateSize!T`.
 * Postcondition: $(D_PARAM memory) and the result point to the same memory.
 */
T emplace(T, U, Args...)(void[] memory, U outer, auto ref Args args)
if (!isAbstractClass!T && isInnerClass!T && is(typeof(T.outer) == U))
in
{
    assert(memory.length >= stateSize!T);
}
out (result)
{
    assert(memory.ptr is (() @trusted => cast(void*) result)());
}
do
{
    copy(typeid(T).initializer, memory);

    auto result = (() @trusted => cast(T) memory.ptr)();
    result.outer = outer;

    static if (is(typeof(result.__ctor(args))))
    {
        result.__ctor(args);
    }

    return result;
}

/// ditto
T emplace(T, Args...)(void[] memory, auto ref Args args)
if (is(T == class) && !isAbstractClass!T && !isInnerClass!T)
in
{
    assert(memory.length == stateSize!T);
}
out (result)
{
    assert(memory.ptr is (() @trusted => cast(void*) result)());
}
do
{
    copy(typeid(T).initializer, memory);

    auto result = (() @trusted => cast(T) memory.ptr)();
    static if (is(typeof(result.__ctor(args))))
    {
        result.__ctor(args);
    }
    return result;
}

///
@nogc nothrow pure @safe unittest
{
    import tanya.memory : stateSize;

    class C
    {
        int i = 5;
        class Inner
        {
            int i;

            this(int param) pure nothrow @safe @nogc
            {
                this.i = param;
            }
        }
    }
    ubyte[stateSize!C] memory1;
    ubyte[stateSize!(C.Inner)] memory2;

    auto c = emplace!C(memory1);
    assert(c.i == 5);

    auto inner = emplace!(C.Inner)(memory2, c, 8);
    assert(c.i == 5);
    assert(inner.i == 8);
    assert(inner.outer is c);
}

/// ditto
T* emplace(T, Args...)(void[] memory, auto ref Args args)
if (!isAggregateType!T && (Args.length <= 1))
in
{
    assert(memory.length >= T.sizeof);
}
out (result)
{
    assert(memory.ptr is result);
}
do
{
    auto result = (() @trusted => cast(T*) memory.ptr)();
    static if (Args.length == 1)
    {
        *result = T(args[0]);
    }
    else
    {
        *result = T.init;
    }
    return result;
}

/// ditto
T* emplace(T, Args...)(void[] memory, auto ref Args args)
if (!isPolymorphicType!T && isAggregateType!T)
in
{
    assert(memory.length >= T.sizeof);
}
out (result)
{
    assert(memory.ptr is result);
}
do
{
    auto result = (() @trusted => cast(T*) memory.ptr)();
    static if (!hasElaborateAssign!T && isAssignable!T)
    {
        *result = T.init;
    }
    else
    {
        static const T init = T.init;
        copy((cast(void*) &init)[0 .. T.sizeof], memory);
    }

    static if (Args.length == 0)
    {
        static assert(is(typeof({ static T t; })),
                      "Default constructor is disabled");
    }
    else static if (is(typeof(T(args))))
    {
        *result = T(args);
    }
    else static if (is(typeof(result.__ctor(args))))
    {
        result.__ctor(args);
    }
    else
    {
        static assert(false,
                      "Unable to construct value with the given arguments");
    }
    return result;
}

///
@nogc nothrow pure @safe unittest
{
    ubyte[4] memory;

    auto i = emplace!int(memory);
    static assert(is(typeof(i) == int*));
    assert(*i == 0);

    i = emplace!int(memory, 5);
    assert(*i == 5);

    static struct S
    {
        int i;
        @disable this();
        @disable this(this);
        this(int i) @nogc nothrow pure @safe
        {
            this.i = i;
        }
    }
    auto s = emplace!S(memory, 8);
    static assert(is(typeof(s) == S*));
    assert(s.i == 8);
}

// Handles "Cannot access frame pointer" error.
@nogc nothrow pure @safe unittest
{
    struct F
    {
        ~this() @nogc nothrow pure @safe
        {
        }
    }
    static assert(is(typeof(emplace!F((void[]).init))));
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

package bool stringToInt(R)(R range, ref ushort n)
{
    import tanya.encoding.ascii;
    import tanya.range.array;

    size_t i = 1;
    uint lPort;

    for (; !range.empty && range.front.isDigit() && i <= 6; ++i, range.popFront())
    {
        lPort = lPort * 10 + (range.front - '0');
    }
    if (i != 1 && (range.empty || range.front == '/'))
    {
        if (lPort > ushort.max)
        {
            return false;
        }
        n = cast(ushort) lPort;
        return true;
    }
    return false;
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

@nogc nothrow pure @safe unittest
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

@nogc nothrow pure @safe unittest
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

@nogc pure @safe unittest
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

@nogc pure @safe unittest
{
    assertThrown!ConvException(&to!(short, int), int.min);
    assertThrown!ConvException(&to!(short, int), int.max);
    assertThrown!ConvException(&to!(ushort, uint), uint.max);
    assertThrown!ConvException(&to!(uint, int), -1);
}

@nogc nothrow pure @safe unittest
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

@nogc pure @safe unittest
{
    assertThrown!ConvException(&to!(int, double), 2147483647.5);
    assertThrown!ConvException(&to!(int, double), -2147483648.5);
    assertThrown!ConvException(&to!(uint, double), -21474.5);
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

@nogc pure @safe unittest
{
    enum Test : uint
    {
        one,
        two,
    }
    assertThrown!ConvException(&to!(Test, int), 5);
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

@nogc pure @safe unittest
{
    assertThrown!ConvException(&to!(bool, int), -1);
    assertThrown!ConvException(&to!(bool, int), 2);
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

@nogc pure @safe unittest
{
    assertThrown!ConvException(() => "1".to!bool);
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
 * Converts $(D_PARAM From) to a $(D_PSYMBOL String).
 *
 * Params:
 *  From = Source type.
 *  To   = Target type.
 *  from = Source value.
 *
 * Returns: $(D_PARAM from) converted to $(D_PSYMBOL String).
 */
To to(To, From)(auto ref From from)
if (is(Unqual!To == String))
{
    return format!"{}"(from);
}

///
@nogc nothrow pure @safe unittest
{
    assert(true.to!String == "true");
    assert(false.to!String == "false");
}

@nogc nothrow pure @safe unittest
{
    static assert(is(typeof((const String("true")).to!bool)));
    static assert(is(typeof(false.to!(const String) == "false")));
}
