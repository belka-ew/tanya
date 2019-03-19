/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */
module tanya.meta.tests.transform;

import tanya.meta.transform;

@nogc nothrow pure @safe unittest
{
    static assert(is(CommonType!(void*, int*) == void*));
    static assert(is(CommonType!(void*, const(int)*) == const(void)*));
    static assert(is(CommonType!(void*, const(void)*) == const(void)*));
    static assert(is(CommonType!(int*, void*) == void*));
    static assert(is(CommonType!(const(int)*, void*) == const(void)*));
    static assert(is(CommonType!(const(void)*, void*) == const(void)*));

    static assert(is(CommonType!() == void));
    static assert(is(CommonType!(int*, const(int)*) == const(int)*));
    static assert(is(CommonType!(int**, const(int)**) == const(int*)*));

    static assert(is(CommonType!(float, double) == double));
    static assert(is(CommonType!(float, int) == void));

    static assert(is(CommonType!(bool, const bool) == bool));
    static assert(is(CommonType!(int, bool) == void));
    static assert(is(CommonType!(int, void) == void));
    static assert(is(CommonType!(Object, void*) == void));

    class A
    {
    }
    static assert(is(CommonType!(A, Object) == Object));
    static assert(is(CommonType!(const(A)*, Object*) == const(Object)*));
    static assert(is(CommonType!(A, typeof(null)) == A));

    class B : A
    {
    }
    class C : A
    {
    }
    static assert(is(CommonType!(B, C) == A));

    static struct S
    {
        int opCast(T : int)()
        {
            return 1;
        }
    }
    static assert(is(CommonType!(S, int) == void));
    static assert(is(CommonType!(const S, S) == const S));
}
