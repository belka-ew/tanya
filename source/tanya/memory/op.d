/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * Set of operations on memory blocks.
 *
 * Copyright: Eugene Wissner 2017.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 * Source: $(LINK2 https://github.com/caraus-ecms/tanya/blob/master/source/tanya/memory/op.d,
 *                 tanya/memory/op.d)
 */
module tanya.memory.op;

version (TanyaPhobos)
{
    import core.stdc.string;
}
else
{
    static import tanya.memory.arch.x86_64;
}

private enum alignMask = size_t.sizeof - 1;

/**
 * Copies $(D_PARAM source) into $(D_PARAM target).
 *
 * $(D_PARAM source) and $(D_PARAM target) shall not overlap so that
 * $(D_PARAM source) points ahead of $(D_PARAM target).
 *
 * $(D_PARAM target) shall have enough space for $(D_INLINECODE source.length)
 * elements.
 *
 * Params:
 *  source = Memory to copy from.
 *  target = Destination memory.
 *
 * See_Also: $(D_PSYMBOL copyBackward).
 *
 * Precondition: $(D_INLINECODE source.length <= target.length).
 */
void copy(const void[] source, void[] target) pure nothrow @trusted @nogc
in
{
    assert(source.length <= target.length);
}
body
{
    version (TanyaPhobos)
    {
        memcpy(target.ptr, source.ptr, source.length);
    }
    else
    {
        tanya.memory.arch.x86_64.copy(source, target);
    }
}

///
pure nothrow @safe @nogc unittest
{
    ubyte[9] source = [1, 2, 3, 4, 5, 6, 7, 8, 9];
    ubyte[9] target;
    source.copy(target);
    assert(cmp(source, target) == 0);
}

private pure nothrow @safe @nogc unittest
{
    {
        ubyte[0] source, target;
        source.copy(target);
    }
    {
        ubyte[1] source = [1];
        ubyte[1] target;
        source.copy(target);
        assert(target[0] == 1);
    }
    {
        ubyte[8] source = [1, 2, 3, 4, 5, 6, 7, 8];
        ubyte[8] target;
        source.copy(target);
        assert(cmp(source, target) == 0);
    }
}

/*
 * size_t value each of which bytes is set to `Byte`.
 */
private template filledBytes(ubyte Byte, ubyte I = 0)
{
    static if (I == size_t.sizeof)
    {
        enum size_t filledBytes = Byte;
    }
    else
    {
        enum size_t filledBytes = (filledBytes!(Byte, I + 1) << 8) | Byte;
    }
}

/**
 * Fills $(D_PARAM memory) with the single byte $(D_PARAM c).
 *
 * Param:
 *  c      = The value to fill $(D_PARAM memory) with.
 *  memory = Memory block.
 */
void fill(ubyte c = 0)(void[] memory) @trusted
{
    version (TanyaPhobos)
    {
        memset(memory.ptr, c, memory.length);
    }
    else
    {
        tanya.memory.arch.x86_64.fill(memory, filledBytes!c);
    }
}

///
pure nothrow @safe @nogc unittest
{
    ubyte[9] memory = [1, 2, 3, 4, 5, 6, 7, 8, 9];
    memory.fill!0();
    foreach (ubyte v; memory)
    {
        assert(v == 0);
    }
}

// Stress test. Checks that `fill` can handle unaligned pointers and different
// lengths.
pure nothrow @safe @nogc private unittest
{
    ubyte[192] memory;

    foreach (j; 0 .. 192)
    {
        foreach (ubyte i, ref ubyte v; memory[j .. $])
        {
            v = i;
        }
        fill(memory[j .. $]);
        foreach (ubyte v; memory[j .. $])
        {
            assert(v == 0);
        }
        fill!1(memory[j .. $]);
        foreach (ubyte v; memory[j .. $])
        {
            assert(v == 1);
        }
    }
}

/**
 * Copies starting from the end of $(D_PARAM source) into the end of
 * $(D_PARAM target).
 *
 * $(D_PSYMBOL copyBackward) copies the elements in reverse order, but the
 * order of elements in the $(D_PARAM target) is exactly the same as in the
 * $(D_PARAM source).
 *
 * $(D_PARAM source) and $(D_PARAM target) shall not overlap so that
 * $(D_PARAM target) points ahead of $(D_PARAM source).
 *
 * $(D_PARAM target) shall have enough space for $(D_INLINECODE source.length)
 * elements.
 *
 * Params:
 *  source = Memory to copy from.
 *  target = Destination memory.
 *
 * See_Also: $(D_PSYMBOL copy).
 *
 * Precondition: $(D_INLINECODE source.length <= target.length).
 */
void copyBackward(const void[] source, void[] target) pure nothrow @trusted @nogc
in
{
    assert(source.length <= target.length);
}
body
{
    version (TanyaPhobos)
    {
        memmove(target.ptr, source.ptr, source.length);
    }
    else
    {
        tanya.memory.arch.x86_64.copyBackward(source, target);
    }
}

///
pure nothrow @safe @nogc unittest
{
    ubyte[6] mem = [ 'a', 'a', 'b', 'b', 'c', 'c' ];
    ubyte[6] expected = [ 'a', 'a', 'a', 'a', 'b', 'b' ];

    copyBackward(mem[0 .. 4], mem[2 .. $]);
    assert(cmp(expected, mem) == 0);
}

private nothrow @safe @nogc unittest
{
    ubyte[9] r1 = [ 'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i' ];
    ubyte[9] r2;

    copyBackward(r1, r2);
    assert(cmp(r1, r2) == 0);
}

/**
 * Compares two memory areas $(D_PARAM r1) and $(D_PARAM r2).
 *
 * $(D_PSYMBOL cmp) returns a positive integer if
 * $(D_INLINECODE r1.length > r2.length) or the first `n` compared bytes of
 * $(D_PARAM r1) found to be greater than the first `n` bytes of $(D_PARAM r2),
 *
 * $(D_PSYMBOL cmp) returns a negative integer if
 * $(D_INLINECODE r2.length > r1.length) or the first `n` compared bytes of
 * $(D_PARAM r1) found to be less than the first `n` bytes of $(D_PARAM r2),
 *
 * `0` is returned otherwise.
 *
 * Returns: Positive integer if $(D_INLINECODE r1 > r2),
 *          negative integer if $(D_INLINECODE r2 > r1),
 *          `0` if $(D_INLINECODE r1 == r2).
 */
int cmp(const void[] r1, const void[] r2) pure nothrow @trusted @nogc
{
    version (TanyaPhobos)
    {
        if (r1.length > r2.length)
        {
            return 1;
        }
        return r1.length < r2.length ? -1 : memcmp(r1.ptr, r2.ptr, r1.length);
    }
    else
    {
        return tanya.memory.arch.x86_64.cmp(r1, r2);
    }
}

///
pure nothrow @safe @nogc unittest
{
    ubyte[4] r1 = [ 'a', 'b', 'c', 'd' ];
    ubyte[3] r2 = [ 'c', 'a', 'b' ];

    assert(cmp(r1[0 .. 3], r2[]) < 0);
    assert(cmp(r2[], r1[0 .. 3]) > 0);

    assert(cmp(r1, r2) > 0);
    assert(cmp(r2, r1) < 0);
}

private pure nothrow @safe @nogc unittest
{
    ubyte[16] r1 = [
        'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h',
        'i', 'j', 'k', 'l', 'm', 'n', 'o', 'p',
    ];
    ubyte[16] r2 = [
        'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h',
        'i', 'j', 'k', 'l', 'm', 'n', 'o', 'p',
    ];

    assert(cmp(r1, r2) == 0);
    assert(cmp(r1[1 .. $], r2[1 .. $]) == 0);
    assert(cmp(r1[0 .. $ - 1], r2[0 .. $ - 1]) == 0);
    assert(cmp(r1[0 .. 8], r2[0 .. 8]) == 0);
}
