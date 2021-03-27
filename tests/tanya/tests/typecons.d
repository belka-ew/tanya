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

@nogc nothrow pure @safe unittest
{
    Variant!(int, double) variant;
    variant = 5;
    assert(variant.peek!int);
}

@nogc nothrow pure @safe unittest
{
    Variant!(int, double) variant;
    variant = 5.0;
    assert(!variant.peek!int);
}

@nogc nothrow pure @safe unittest
{
    Variant!(int, double) variant = 5;
    assert(variant.get!int == 5);
}

@nogc nothrow pure @safe unittest
{
    static assert(is(Variant!(int, float)));
    static assert(is(Variant!int));
}

@nogc nothrow pure @safe unittest
{
    static struct WithDestructorAndCopy
    {
        this(this) @nogc nothrow pure @safe
        {
        }

        ~this() @nogc nothrow pure @safe
        {
        }
    }
    static assert(is(Variant!WithDestructorAndCopy));
}

// Equality compares the underlying objects
@nogc nothrow pure @safe unittest
{
    Variant!(int, double) variant1 = 5;
    Variant!(int, double) variant2 = 5;
    assert(variant1 == variant2);
}

@nogc nothrow pure @safe unittest
{
    Variant!(int, double) variant1 = 5;
    Variant!(int, double) variant2 = 6;
    assert(variant1 != variant2);
}

// Differently typed variants aren't equal
@nogc nothrow pure @safe unittest
{
    Variant!(int, double) variant1 = 5;
    Variant!(int, double) variant2 = 5.0;
    assert(variant1 != variant2);
}

// Uninitialized variants are equal
@nogc nothrow pure @safe unittest
{
    Variant!(int, double) variant1, variant2;
    assert(variant1 == variant2);
}

// Calls postblit constructor of the active type
@nogc nothrow pure @safe unittest
{
    static struct S
    {
        bool called;

        this(this)
        {
            this.called = true;
        }
    }
    Variant!(int, S) variant1 = S();
    auto variant2 = variant1;
    assert(variant2.get!S.called);
}

// Variant.type is null if the Variant doesn't have a value
@nogc nothrow pure @safe unittest
{
    Variant!(int, uint) variant;
    assert(variant.type is null);
}

// Variant can contain only distinct types
@nogc nothrow pure @safe unittest
{
    static assert(!is(Variant!(int, int)));
}
