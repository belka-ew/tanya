module tanya.memory.tests.op;

import tanya.memory.op;

@nogc nothrow pure @system unittest
{
    ubyte[2] buffer = 1;
    fill!0(buffer[1 .. $]);
    assert(buffer[0] == 1 && buffer[1] == 0);
}

@nogc nothrow pure @safe unittest
{
    assert(equal(null, null));
}

@nogc nothrow pure @safe unittest
{
    ubyte[0] source, target;
    source.copy(target);
}

@nogc nothrow pure @safe unittest
{
    ubyte[1] source = [1];
    ubyte[1] target;
    source.copy(target);
    assert(target[0] == 1);
}

@nogc nothrow pure @safe unittest
{
    ubyte[8] source = [1, 2, 3, 4, 5, 6, 7, 8];
    ubyte[8] target;
    source.copy(target);
    assert(equal(source, target));
}

@nogc nothrow pure @safe unittest
{
    ubyte[9] r1 = [ 'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i' ];
    ubyte[9] r2;

    copyBackward(r1, r2);
    assert(equal(r1, r2));
}

// Compares unanligned memory
@nogc nothrow pure @safe unittest
{
    ubyte[16] r1 = [
        'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h',
        'i', 'j', 'k', 'l', 'm', 'n', 'o', 'p',
    ];
    ubyte[16] r2 = [
        'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h',
        'i', 'j', 'k', 'l', 'm', 'n', 'o', 'p',
    ];

    assert(equal(r1, r2));
    assert(equal(r1[1 .. $], r2[1 .. $]));
    assert(equal(r1[0 .. $ - 1], r2[0 .. $ - 1]));
    assert(equal(r1[0 .. 8], r2[0 .. 8]));
}
