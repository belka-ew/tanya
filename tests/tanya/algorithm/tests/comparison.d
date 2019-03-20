/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */
module tanya.algorithm.tests.comparison;

import tanya.algorithm.comparison;
import tanya.math;
import tanya.range;

@nogc nothrow pure @safe unittest
{
    static assert(!is(typeof(min(1, 1UL))));
}

@nogc nothrow pure @safe unittest
{
    assert(min(5, 3) == 3);
    assert(min(4, 4) == 4);
    assert(min(5.2, 3.0) == 3.0);

    assert(min(5.2, double.nan) == 5.2);
    assert(min(double.nan, 3.0) == 3.0);
    assert(isNaN(min(double.nan, double.nan)));
}

@nogc nothrow pure @safe unittest
{
    assert(min(cast(ubyte[]) []).empty);
}

@nogc nothrow pure @safe unittest
{
    static assert(!is(typeof(max(1, 1UL))));
}

@nogc nothrow pure @safe unittest
{
    assert(max(5, 3) == 5);
    assert(max(4, 4) == 4);
    assert(max(5.2, 3.0) == 5.2);

    assert(max(5.2, double.nan) == 5.2);
    assert(max(double.nan, 3.0) == 3.0);
    assert(isNaN(max(double.nan, double.nan)));
}

@nogc nothrow pure @safe unittest
{
    assert(max(cast(ubyte[]) []).empty);
}

// min/max compare const and mutable structs.
@nogc nothrow pure @safe unittest
{
    static struct S
    {
        int s;

        int opCmp(typeof(this) that) const @nogc nothrow pure @safe
        {
            return this.s - that.s;
        }
    }
    {
        const s1 = S(1);
        assert(min(s1, S(2)).s == 1);
        assert(max(s1, S(2)).s == 2);
    }
    {
        auto s2 = S(2), s3 = S(3);
        assert(min(s2, s3).s == 2);
        assert(max(s2, s3).s == 3);
    }
}

@nogc nothrow pure @safe unittest
{
    static struct OpCmp(int value)
    {
        int opCmp(OpCmp) @nogc nothrow pure @safe
        {
            return value;
        }
    }
    {
        OpCmp!(-1)[1] range;
        assert(compare(range[], range[]) < 0);
    }
    {
        OpCmp!1[1] range;
        assert(compare(range[], range[]) > 0);
    }
    {
        OpCmp!0[1] range;
        assert(compare(range[], range[]) == 0);
    }
}
