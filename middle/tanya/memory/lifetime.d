/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * Lifetime management functions, types and related exceptions.
 *
 * Copyright: Eugene Wissner 2019-2020.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 * Source: $(LINK2 https://github.com/caraus-ecms/tanya/blob/master/middle/tanya/memory/lifetime.d,
 *                 tanya/memory/lifetime.d)
 */
module tanya.memory.lifetime;

import tanya.memory.allocator;
import tanya.meta.metafunction;
import tanya.meta.trait;

package(tanya) void destroyAllImpl(R, E)(R p)
{
    static if (hasElaborateDestructor!E)
    {
        foreach (ref e; p)
        {
            destroy(e);
        }
    }
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
in (memory.length >= stateSize!T)
out (result; memory.ptr is (() @trusted => cast(void*) result)())
{
    import tanya.memory.op : copy;

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
in (memory.length == stateSize!T)
out (result; memory.ptr is (() @trusted => cast(void*) result)())
{
    import tanya.memory.op : copy;

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
in (memory.length >= T.sizeof)
out (result; memory.ptr is result)
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

private void initializeOne(T)(ref void[] memory, ref T* result) @trusted
{
    import tanya.memory.op : copy, fill;

    static if (!hasElaborateAssign!T && isAssignable!T)
    {
        *result = T.init;
    }
    else static if (__VERSION__ >= 2083 // __traits(isZeroInit) available.
        && __traits(isZeroInit, T))
    {
        memory.ptr[0 .. T.sizeof].fill!0;
    }
    else
    {
        static immutable T init = T.init;
        copy((&init)[0 .. 1], memory);
    }
}

/// ditto
T* emplace(T, Args...)(void[] memory, auto ref Args args)
if (!isPolymorphicType!T && isAggregateType!T)
in (memory.length >= T.sizeof)
out (result; memory.ptr is result)
{
    auto result = (() @trusted => cast(T*) memory.ptr)();

    static if (Args.length == 0)
    {
        static assert(is(typeof({ static T t; })),
                      "Default constructor is disabled");
        initializeOne(memory, result);
    }
    else static if (is(typeof(result.__ctor(args))))
    {
        initializeOne(memory, result);
        result.__ctor(args);
    }
    else static if (Args.length == 1 && is(typeof({ T t = args[0]; })))
    {
        import tanya.memory.op : copy;

        ((ref arg) @trusted =>
            copy((cast(void*) &arg)[0 .. T.sizeof], memory))(args[0]);
        static if (hasElaborateCopyConstructor!T)
        {
            result.__postblit();
        }
    }
    else static if (is(typeof({ T t = T(args); })))
    {
        auto init = T(args);
        (() @trusted => moveEmplace(init, *result))();
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

private void deinitialize(bool zero, T)(ref T value)
{
    static if (is(T == U[S], U, size_t S))
    {
        foreach (ref e; value)
        {
            deinitialize!zero(e);
        }
    }
    else
    {
        import tanya.memory.op : copy, fill;

        static if (isNested!T)
        {
            // Don't override the context pointer.
            enum size_t size = T.sizeof - (void*).sizeof;
        }
        else
        {
            enum size_t size = T.sizeof;
        }
        static if (zero)
        {
            fill!0((cast(void*) &value)[0 .. size]);
        }
        else
        {
            copy(typeid(T).initializer()[0 .. size], (&value)[0 .. 1]);
        }
    }
}

/**
 * Moves $(D_PARAM source) into $(D_PARAM target) assuming that
 * $(D_PARAM target) isn't initialized.
 *
 * Moving the $(D_PARAM source) copies it into the $(D_PARAM target) and places
 * the $(D_PARAM source) into a valid but unspecified state, which means that
 * after moving $(D_PARAM source) can be destroyed or assigned a new value, but
 * accessing it yields an unspecified value. No postblits or destructors are
 * called. If the $(D_PARAM target) should be destroyed before, use
 * $(D_PSYMBOL move).
 *
 * $(D_PARAM source) and $(D_PARAM target) must be different objects.
 *
 * Params:
 *  T      = Object type.
 *  source = Source object.
 *  target = Target object.
 *
 * See_Also: $(D_PSYMBOL move),
 *           $(D_PSYMBOL hasElaborateCopyConstructor),
 *           $(D_PSYMBOL hasElaborateDestructor).
 *
 * Precondition: `&source !is &target`.
 */
void moveEmplace(T)(ref T source, ref T target) @system
in (&source !is &target, "Source and target must be different")
{
    static if (is(T == struct) || isStaticArray!T)
    {
        import tanya.memory.op : copy;

        copy((&source)[0 .. 1], (&target)[0 .. 1]);

        static if (hasElaborateCopyConstructor!T || hasElaborateDestructor!T)
        {
            static if (__VERSION__ >= 2083) // __traits(isZeroInit) available.
            {
                deinitialize!(__traits(isZeroInit, T))(source);
            }
            else
            {
                if (typeid(T).initializer().ptr is null)
                {
                    deinitialize!true(source);
                }
                else
                {
                    deinitialize!false(source);
                }
            }
        }
    }
    else
    {
        target = source;
    }
}

///
@nogc nothrow pure @system unittest
{
    static struct S
    {
        int member = 5;

        this(this) @nogc nothrow pure @safe
        {
            assert(false);
        }
    }
    S source, target = void;
    moveEmplace(source, target);
    assert(target.member == 5);

    int x1 = 5, x2;
    moveEmplace(x1, x2);
    assert(x2 == 5);
}

/**
 * Moves $(D_PARAM source) into $(D_PARAM target) assuming that
 * $(D_PARAM target) isn't initialized.
 *
 * Moving the $(D_PARAM source) copies it into the $(D_PARAM target) and places
 * the $(D_PARAM source) into a valid but unspecified state, which means that
 * after moving $(D_PARAM source) can be destroyed or assigned a new value, but
 * accessing it yields an unspecified value. $(D_PARAM target) is destroyed before
 * the new value is assigned. If $(D_PARAM target) isn't initialized and
 * therefore shouldn't be destroyed, $(D_PSYMBOL moveEmplace) can be used.
 *
 * If $(D_PARAM target) isn't specified, $(D_PSYMBOL move) returns the source
 * as rvalue without calling its copy constructor or destructor.
 *
 * $(D_PARAM source) and $(D_PARAM target) are the same object,
 * $(D_PSYMBOL move) does nothing.
 *
 * Params:
 *  T      = Object type.
 *  source = Source object.
 *  target = Target object.
 *
 * See_Also: $(D_PSYMBOL moveEmplace).
 */
void move(T)(ref T source, ref T target)
{
    if ((() @trusted => &source is &target)())
    {
        return;
    }
    static if (hasElaborateDestructor!T)
    {
        target.__xdtor();
    }
    (() @trusted => moveEmplace(source, target))();
}

/// ditto
T move(T)(ref T source) @trusted
{
    static if (hasElaborateCopyConstructor!T || hasElaborateDestructor!T)
    {
        T target = void;
        moveEmplace(source, target);
        return target;
    }
    else
    {
        return source;
    }
}

///
@nogc nothrow pure @safe unittest
{
    static struct S
    {
        int member = 5;

        this(this) @nogc nothrow pure @safe
        {
            assert(false);
        }
    }
    S source, target = void;
    move(source, target);
    assert(target.member == 5);
    assert(move(target).member == 5);

    int x1 = 5, x2;
    move(x1, x2);
    assert(x2 == 5);
    assert(move(x2) == 5);
}

/**
 * Exchanges the values of $(D_PARAM a) and $(D_PARAM b).
 *
 * $(D_PSYMBOL swap) moves the contents of $(D_PARAM a) and $(D_PARAM b)
 * without calling its postblits or destructors.
 *
 * Params:
 *  a = The first object.
 *  b = The second object.
 */
void swap(T)(ref T a, ref T b) @trusted
{
    T tmp = void;
    moveEmplace(a, tmp);
    moveEmplace(b, a);
    moveEmplace(tmp, b);
}

///
@nogc nothrow pure @safe unittest
{
    int a = 3, b = 5;
    swap(a, b);
    assert(a == 5);
    assert(b == 3);
}

/**
 * Forwards its argument list preserving $(D_KEYWORD ref) and $(D_KEYWORD out)
 * storage classes.
 *
 * $(D_PSYMBOL forward) accepts a list of variables or literals. It returns an
 * argument list of the same length that can be for example passed to a
 * function accepting the arguments of this type.
 *
 * Params:
 *  args = Argument list.
 *
 * Returns: $(D_PARAM args) with their original storage classes.
 */
template forward(args...)
{
    static if (args.length == 0)
    {
        alias forward = AliasSeq!();
    }
    else static if (__traits(isRef, args[0]) || __traits(isOut, args[0]))
    {
        static if (args.length == 1)
        {
            alias forward = args[0];
        }
        else
        {
            alias forward = AliasSeq!(args[0], forward!(args[1 .. $]));
        }
    }
    else
    {
        @property auto forwardOne()
        {
            return move(args[0]);
        }
        static if (args.length == 1)
        {
            alias forward = forwardOne;
        }
        else
        {
            alias forward = AliasSeq!(forwardOne, forward!(args[1 .. $]));
        }
    }
}

///
@nogc nothrow pure @safe unittest
{
    static assert(is(typeof((int i) { int v = forward!i; })));
    static assert(is(typeof((ref int i) { int v = forward!i; })));
    static assert(is(typeof({
        void f(int i, ref int j, out int k)
        {
            f(forward!(i, j, k));
        }
    })));
}
