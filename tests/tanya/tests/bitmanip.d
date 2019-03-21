module tanya.tests.bitmanip;

import tanya.bitmanip;

// Casts to a boolean
@nogc nothrow pure @safe unittest
{
    assert(BitFlags!One(One.one));
    assert(!BitFlags!One());
}

// Assigns to and compares with a single value
@nogc nothrow pure @safe unittest
{
    BitFlags!One bitFlags;
    bitFlags = One.one;
    assert(bitFlags == One.one);
}

// Assigns to and compares with the same type
@nogc nothrow pure @safe unittest
{
    auto bitFlags1 = BitFlags!One(One.one);
    BitFlags!One bitFlags2;
    bitFlags2 = bitFlags1;
    assert(bitFlags1 == bitFlags2);
}

@nogc nothrow pure @safe unittest
{
    assert((BitFlags!One() | One.one) == BitFlags!One(One.one));
    assert((BitFlags!One() | BitFlags!One(One.one)) == BitFlags!One(One.one));

    assert(!(BitFlags!One() & BitFlags!One(One.one)));

    assert(!(BitFlags!One(One.one) ^ One.one));
    assert(BitFlags!One() ^ BitFlags!One(One.one));

    assert(~BitFlags!One());

    assert(BitFlags!One().toHash() == 0);
    assert(BitFlags!One(One.one).toHash() != 0);
}

// opBinaryRight is allowed
@nogc nothrow pure @safe unittest
{
    static assert(is(typeof({ One.one | BitFlags!One(); })));
}

private enum One : int
{
    one = 1,
}
