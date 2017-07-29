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

/**
 * Copies $(D_PARAM source) into $(D_PARAM target).
 *
 * $(D_PARAM source) and $(D_PARAM target) shall not overlap so that an element
 * of $(D_PARAM target) points to an element of $(D_PARAM source).
 *
 * $(D_PARAM target) shall have enough space $(D_INLINECODE source.length)
 * elements. 
 *
 * Params:
 *  source = Memory to copy from.
 *  target = Destination memory.
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
        enum alignmentMask = size_t.sizeof - 1;

        // Check if the pointers are aligned or at least can be aligned
        // properly.
        ushort naligned = (cast(size_t) source.ptr) & alignmentMask;
        if (naligned == ((cast(size_t) target.ptr) & alignmentMask))
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
    {
        ubyte[9] source = [1, 2, 3, 4, 5, 6, 7, 8, 9];
        ubyte[9] target;
        source.copy(target);
        assert(source == target);
    }
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
