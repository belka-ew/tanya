/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * Algorithms that modify its arguments.
 *
 * Copyright: Eugene Wissner 2017.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 * Source: $(LINK2 https://github.com/caraus-ecms/tanya/blob/master/source/tanya/algorithm/mutation.d,
 *                 tanya/algorithm/mutation.d)
 */
module tanya.algorithm.mutation;

import tanya.memory.op;
import tanya.meta.trait;

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
in
{
    assert(&source !is &target, "Source and target must be different");
}
body
{
    static if (is(T == struct) || isStaticArray!T)
    {
        copy((&source)[0 .. 1], (&target)[0 .. 1]);

        static if (hasElaborateCopyConstructor!T || hasElaborateDestructor!T)
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

// Is pure.
@nogc nothrow pure @system unittest
{
    struct S
    {
        this(this)
        {
        }
    }
    S source, target = void;
    static assert(is(typeof({ moveEmplace(source, target); })));
}

// Moves nested.
@nogc nothrow pure @system unittest
{
    struct Nested
    {
        void method() @nogc nothrow pure @safe
        {
        }
    }
    Nested source, target = void;
    moveEmplace(source, target);
    assert(source == target);
}

// Emplaces static arrays.
@nogc nothrow pure @system unittest
{
    static struct S
    {
        size_t member;
        this(size_t i) @nogc nothrow pure @safe
        {
            this.member = i;
        }
        ~this() @nogc nothrow pure @safe
        {
        }
    }
    S[2] source = [ S(5), S(5) ], target = void;
    moveEmplace(source, target);
    assert(source[0].member == 0);
    assert(target[0].member == 5);
    assert(source[1].member == 0);
    assert(target[1].member == 5);
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
T move(T)(ref T source)
{
    T target = void;
    (() @trusted => moveEmplace(source, target))();
    return target;
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

// Moves if source is target.
@nogc nothrow pure @safe unittest
{
    int x = 5;
    move(x, x);
    assert(x == 5);
}

/**
 * Exchanges the values of $(D_PARAM a) and $(D_PARAM b).
 *
 * $(D_PSYMBOL swap) moves the contents of $(D_PARAM a) and $(D_PARAM b)
 * without calling its postblits or destructors.
 *
 * Params:
 *  a = The first object.
 *  a = The second object.
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
