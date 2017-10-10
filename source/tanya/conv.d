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

import tanya.memory;
import tanya.memory.op;
import tanya.meta.trait;

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
body
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
}body
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
body
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
body
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
