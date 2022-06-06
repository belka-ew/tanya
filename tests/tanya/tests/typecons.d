module tanya.tests.typecons;

import tanya.test.stub;
import tanya.typecons;

@nogc nothrow pure @safe unittest
{
    static assert(is(Tuple!(int, int)));
    static assert(!is(Tuple!(int, 5)));

    static assert(is(Tuple!(int, "first", int)));
    static assert(is(Tuple!(int, "first", int, "second")));
    static assert(is(Tuple!(int, "first", int)));

    static assert(is(Tuple!(int, int, "second")));
    static assert(!is(Tuple!("first", int, "second", int)));
    static assert(!is(Tuple!(int, int, int)));

    static assert(!is(Tuple!(int, "first")));

    static assert(!is(Tuple!(int, double, char)));
    static assert(!is(Tuple!(int, "first", double, "second", char, "third")));
}
