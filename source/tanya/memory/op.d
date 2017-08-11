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
 */
module tanya.memory.op;

version (D_InlineAsm_X86_64)
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
    version (D_InlineAsm_X86_64)
    {
        tanya.memory.arch.x86_64.copy(source, target);
    }
    else // Naive implementation.
    {
        auto source1 = cast(const(ubyte)*) source;
        auto target1 = cast(ubyte*) target;
        auto count = source.length;

        // Check if the pointers are aligned or at least can be aligned
        // properly.
        ushort naligned = (cast(size_t) source.ptr) & alignMask;
        if (naligned == ((cast(size_t) target.ptr) & alignMask))
        {
            // Align the pointers if possible.
            if (naligned != 0)
            {
                count -= naligned;
                while (naligned--)
                {
                    *target1++ = *source1++;
                }
            }
            // Copy size_t.sizeof bytes at once.
            auto longSource = cast(const(size_t)*) source1;
            auto longTarget = cast(size_t*) target1;
            for (; count >= size_t.sizeof; count -= size_t.sizeof)
            {
                *longTarget++ = *longSource++;
            }
            // Adjust the original pointers.
            source1 = cast(const(ubyte)*) longSource;
            target1 = cast(ubyte*) longTarget;
        }
        // Copy the remaining bytes by one.
        while (count--)
        {
            *target1++ = *source1++;
        }
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
package template FilledBytes(ubyte Byte, ubyte I = 0)
{
    static if (I == size_t.sizeof)
    {
        enum size_t FilledBytes = Byte;
    }
    else
    {
        enum size_t FilledBytes = (FilledBytes!(Byte, I + 1) << 8) | Byte;
    }
}

/**
 * Fills $(D_PARAM memory) with single $(D_PARAM Byte)s.
 *
 * Param:
 *  Byte   = The value to fill $(D_PARAM memory) with.
 *  memory = Memory block.
 */
void fill(ubyte Byte = 0)(void[] memory) @trusted
{
    version (D_InlineAsm_X86_64)
    {
        tanya.memory.arch.x86_64.fill!Byte(memory);
    }
    else // Naive implementation.
    {
        auto n = memory.length;
        ubyte* vp = cast(ubyte*) memory.ptr;

        // Align.
        while (((cast(size_t) vp) & alignMask) != 0)
        {
            *vp++ = Byte;
            --n;
        }

        // Set size_t.sizeof bytes at ones.
        auto sp = cast(size_t*) vp;
        while (n / size_t.sizeof > 0)
        {
            *sp++ = FilledBytes!Byte;
            n -= size_t.sizeof;
        }

        // Write the remaining bytes.
        vp = cast(ubyte*) sp;
        while (n--)
        {
            *vp = Byte;
            ++vp;
        }
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
    version (D_InlineAsm_X86_64)
    {
        tanya.memory.arch.x86_64.copyBackward(source, target);
    }
    else // Naive implementation.
    {
        auto count = source.length;

        // Try to align the pointers if possible.
        if (((cast(size_t) source.ptr) & alignMask) == ((cast(size_t) target.ptr) & alignMask))
        {
            while (((cast(size_t) (source.ptr + count)) & alignMask) != 0)
            {
                if (!count--)
                {
                    return;
                }
                (cast(ubyte[]) target)[count]
                    = (cast(const(ubyte)[]) source)[count];
            }
        }

        // Write as long we're aligned.
        for (; count >= size_t.sizeof; count -= size_t.sizeof)
        {
                *(cast(size_t*) (target.ptr + count - size_t.sizeof))
                    = *(cast(const(size_t)*) (source.ptr + count - size_t.sizeof));
        }

        // Write the remaining bytes.
        while (count--)
        {
            (cast(ubyte[]) target)[count]
                = (cast(const(ubyte)[]) source)[count];
        }
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
    version (D_InlineAsm_X86_64)
    {
        return tanya.memory.arch.x86_64.cmp(r1, r2);
    }
    else // Naive implementation.
    {
        if (r1.length > r2.length)
        {
            return 1;
        }
        else if (r1.length < r2.length)
        {
            return -1;
        }
        auto p1 = cast(const(ubyte)*) r1;
        auto p2 = cast(const(ubyte)*) r2;
        auto count = r1.length;

        // Check if the pointers are aligned or at least can be aligned
        // properly.
        if (((cast(size_t) p1) & alignMask) == ((cast(size_t) p2) & alignMask))
        {
            // Align the pointers if possible.
            for (; ((cast(size_t) p1) & alignMask) != 0; ++p1, ++p2, --count)
            {
                if (*p1 != *p2)
                {
                    return *p1 - *p2;
                }
            }
            // Compare size_t.sizeof bytes at once.
            for (; count >= size_t.sizeof; count -= size_t.sizeof)
            {
                if (*(cast(const(size_t)*) p1) > *(cast(const(size_t)*) p2))
                {
                    return 1;
                }
                else if (*(cast(const(size_t)*) p1) < *(cast(const(size_t)*) p2))
                {
                    return -1;
                }
                p1 += size_t.sizeof;
                p2 += size_t.sizeof;
            }
        }
        // Compare the remaining bytes by one.
        for (; count--; ++p1, ++p2)
        {
            if (*p1 != *p2)
            {
                return *p1 - *p2;
            }
        }
        return 0;
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
