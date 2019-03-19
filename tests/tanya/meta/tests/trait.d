/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */
module tanya.meta.tests.trait;

import tanya.meta.metafunction;
import tanya.meta.trait;

// typeof(null) is not a pointer.
@nogc nothrow pure @safe unittest
{
    static assert(!isPointer!(typeof(null)));
    static assert(!isPointer!(const shared typeof(null)));

    enum typeOfNull : typeof(null)
    {
        null_ = null,
    }
    static assert(!isPointer!typeOfNull);
}

@nogc nothrow pure @safe unittest
{
    static struct S
    {
        @property int opCall()
        {
            return 0;
        }
    }
    S s;
    static assert(isCallable!S);
    static assert(isCallable!s);
}

@nogc nothrow pure @safe unittest
{
    static assert(is(FunctionTypeOf!(void delegate()) == function));

    static void staticFunc()
    {
    }
    auto functionPointer = &staticFunc;
    static assert(is(FunctionTypeOf!staticFunc == function));
    static assert(is(FunctionTypeOf!functionPointer == function));

    void func()
    {
    }
    auto dg = &func;
    static assert(is(FunctionTypeOf!func == function));
    static assert(is(FunctionTypeOf!dg == function));

    interface I
    {
        @property int prop();
    }
    static assert(is(FunctionTypeOf!(I.prop) == function));

    static struct S
    {
        void opCall()
        {
        }
    }
    class C
    {
        static void opCall()
        {
        }
    }
    S s;

    static assert(is(FunctionTypeOf!s == function));
    static assert(is(FunctionTypeOf!C == function));
    static assert(is(FunctionTypeOf!S == function));
}

@nogc nothrow pure @safe unittest
{
    static struct S2
    {
        @property int opCall()
        {
            return 0;
        }
    }
    S2 s2;
    static assert(is(FunctionTypeOf!S2 == function));
    static assert(is(FunctionTypeOf!s2 == function));
}

@nogc nothrow pure @safe unittest
{
    static assert(!hasElaborateAssign!int);

    static struct S1
    {
        void opAssign(S1)
        {
        }
    }
    static struct S2
    {
        void opAssign(int)
        {
        }
    }
    static struct S3
    {
        S1 s;
        alias s this;
    }
    static assert(hasElaborateAssign!S1);
    static assert(!hasElaborateAssign!(const S1));
    static assert(hasElaborateAssign!(S1[1]));
    static assert(!hasElaborateAssign!(S1[0]));
    static assert(!hasElaborateAssign!S2);
    static assert(hasElaborateAssign!S3);

    static struct S4
    {
        void opAssign(S4)
        {
        }
        @disable this(this);
    }
    static assert(hasElaborateAssign!S4);
}

// Produces a tuple for an enum with only one member
@nogc nothrow pure @safe unittest
{
    enum E : int
    {
        one = 0,
    }
    static assert(EnumMembers!E == AliasSeq!0);
}

@nogc nothrow pure @safe unittest
{
    class RefCountedStore(T)
    {
    }
    static assert(!isInnerClass!(RefCountedStore!int));
}

@nogc nothrow pure @safe unittest
{
    static struct DisabledOpEquals
    {
        @disable bool opEquals(typeof(this)) @nogc nothrow pure @safe;

        int opCmp(typeof(this)) @nogc nothrow pure @safe
        {
            return 0;
        }
    }
    static assert(!isEqualityComparable!DisabledOpEquals);
    static assert(isOrderingComparable!DisabledOpEquals);

    static struct OpEquals
    {
        bool opEquals(typeof(this)) @nogc nothrow pure @safe
        {
            return true;
        }
    }
    static assert(isEqualityComparable!OpEquals);
    static assert(!isOrderingComparable!OpEquals);
}
