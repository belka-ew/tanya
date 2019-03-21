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

// Assigns a new value
@nogc nothrow pure @safe unittest
{
    Option!int option = 5;
    option = 8;
    assert(!option.isNothing);
    assert(option == 8);
}

@nogc nothrow pure @safe unittest
{
    Option!int option;
    const int newValue = 8;
    assert(option.isNothing);
    option = newValue;
    assert(!option.isNothing);
    assert(option == newValue);
}

@nogc nothrow pure @safe unittest
{
    Option!int option1;
    Option!int option2 = 5;
    assert(option1.isNothing);
    option1 = option2;
    assert(!option1.isNothing);
    assert(option1.get == 5);
}

// Constructs with a value passed by reference
@nogc nothrow pure @safe unittest
{
    int i = 5;
    assert(Option!int(i).get == 5);
}

// Moving
@nogc nothrow pure @safe unittest
{
    static assert(is(typeof(Option!NonCopyable(NonCopyable()))));
    // The value cannot be returned by reference because the default value
    // isn't passed by reference
    static assert(!is(typeof(Option!DisabledPostblit().or(NonCopyable()))));
}

@nogc nothrow pure @safe unittest
{
    NonCopyable notCopyable;
    static assert(is(typeof(Option!NonCopyable().or(notCopyable))));
}

@nogc nothrow pure @safe unittest
{
    Option!NonCopyable option;
    assert(option.isNothing);
    option = NonCopyable();
    assert(!option.isNothing);
}

@nogc nothrow pure @safe unittest
{
    Option!NonCopyable option;
    assert(option.isNothing);
    option = Option!NonCopyable(NonCopyable());
    assert(!option.isNothing);
}

// Cast to bool is done before touching the encapsulated value
@nogc nothrow pure @safe unittest
{
    assert(Option!bool(false));
}

// Option can be const
@nogc nothrow pure @safe unittest
{
    assert((const Option!int(5)).get == 5);
    assert((const Option!int()).or(5) == 5);
}

// Equality
@nogc nothrow pure @safe unittest
{
    assert(Option!int() == Option!int());
    assert(Option!int(0) != Option!int());
    assert(Option!int(5) == Option!int(5));
    assert(Option!int(5) == 5);
    assert(Option!int(5) == cast(ubyte) 5);
}

// Returns default value
@nogc nothrow pure @safe unittest
{
    int i = 5;
    assert(((ref e) => e)(Option!int().or(i)) == 5);
}

// Implements toHash() for nothing
@nogc nothrow pure @safe unittest
{
    alias OptionT = Option!Hashable;
    assert(OptionT().toHash() == 0U);
    assert(OptionT(Hashable(1U)).toHash() == 1U);
}

// Can assign Option that is nothing
@nogc nothrow pure @safe unittest
{
    auto option1 = Option!int(5);
    Option!int option2;
    option1 = option2;
    assert(option1.isNothing);
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
