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
    assert(source == target);
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
        assert(source == target);
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
    assert(expected == mem);
}
