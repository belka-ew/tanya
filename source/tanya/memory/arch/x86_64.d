/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/*
 * Implementions of functions found in $(D_PSYMBOL tanya.memory.op) for X86-64.
 *
 * Copyright: Eugene Wissner 2017.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 */
module tanya.memory.arch.x86_64;

version (D_InlineAsm_X86_64):

pragma(inline, true)
package (tanya.memory) void copy(const void[] source, void[] target)
pure nothrow @system @nogc
{
    asm pure nothrow @nogc
    {
        naked;

        // RDI and RSI should be preserved.
        mov RAX, RDI;
        mov R8, RSI;
    }
    // Set the registers for movsb/movsq.
    version (Windows) asm pure nothrow @nogc
    {
        // RDX - source.
        // RCX - target.

        mov RDI, [ RCX + 8 ];
        mov RSI, [ RDX + 8 ];
        mov RDX, [ RDX ];
    }
    else asm pure nothrow @nogc
    {
        // RDX - source length.
        // RCX - source data.
        // RDI - target length
        // RSI - target data.

        mov RDI, RSI;
        mov RSI, RCX;
    }
    asm pure nothrow @nogc
    {
        cmp RDX, 0x08;
        jc aligned_8;
        test EDI, 0x07;
        jz aligned_8;

    naligned:
        movsb;
        dec RDX;
        test EDI, 0x07;
        jnz naligned;

    aligned_8:
        mov RCX, RDX;
        shr RCX, 0x03;
        rep;
        movsq;
        and EDX, 0x07;
        jz end;

        // Write the remaining bytes.
        mov RCX, RDX;
        rep;
        movsb;

    end: // Restore registers.
        mov RSI, R8;
        mov RDI, RAX;

        ret;
    }
}

pragma(inline, true)
package (tanya.memory) void zero(void[] memory)
pure nothrow @system @nogc
{
    asm pure nothrow @nogc
    {
        naked;
    }
    version (Windows) asm pure nothrow @nogc
    {
        /*
         * RCX - array.
         */
        mov       R8,           [ RCX ];
        mov       R9,           [ RCX + 8 ];
    }
    else asm pure nothrow @nogc
    {
        /*
         * RSI - pointer.
         * RDI - length.
         */
        mov       R8,           RDI;
        mov       R9,           RSI;
    }
    asm pure nothrow @nogc
    {
        // Check for zero length.
        test      R8,           R8;
        jz        end;

        // Set to 0.
        pxor      XMM0,         XMM0;

        // Check if the pointer is aligned to a 16-byte boundary.
        and       R9,           -0x10;
    }
    // Compute the number of misaligned bytes.
    version (Windows) asm pure nothrow @nogc
    {
        mov       RAX,          [ RCX + 8 ];
    }
    else asm pure nothrow @nogc
    {
        mov       RAX,          RSI;
    }
    asm pure nothrow @nogc
    {
        sub       RAX,          R9;

        test      RAX,          RAX;
        jz aligned;

        // Get the number of bytes to be written until we are aligned.
        mov       RDX,          0x10;
        sub       RDX,          RAX;
    }
    version (Windows) asm pure nothrow @nogc
    {
        mov       R9,           [ RCX + 8 ];
    }
    else asm pure nothrow @nogc
    {
        mov       R9,           RSI;
    }
    asm pure nothrow @nogc
    {
        // Set RAX to zero, so we can set bytes and dwords.
        xor       RAX,          RAX;

    naligned:
        mov       [ R9 ],       AL; // Write a byte.

        // Advance the pointer. Decrease the total number of bytes
        // and the misaligned ones.
        inc       R9;
        dec       RDX;
        dec       R8;

        // Checks if we are aligned.
        test      RDX,          RDX;
        jnz naligned;

    aligned:
        // Checks if we're done writing bytes.
        test      R8,           R8;
        jz end;

        // Write 1 byte at a time.
        cmp       R8,           8;
        jl aligned_1;

        // Write 8 bytes at a time.
        cmp       R8,           16;
        jl aligned_8;

        // Write 16 bytes at a time.
        cmp       R8,           32;
        jl aligned_16;

        // Write 32 bytes at a time.
        cmp       R8,           64;
        jl aligned_32;

    aligned_64:
        movdqa    [ R9 ],        XMM0;
        movdqa    [ R9 + 16 ],   XMM0;
        movdqa    [ R9 + 32 ],   XMM0;
        movdqa    [ R9 + 48 ],   XMM0;

        add       R9,            64;
        sub       R8,            64;

        cmp       R8,            64;
        jge aligned_64;

        // Checks if we're done writing bytes.
        test      R8,            R8;
        jz end;

        // Write 1 byte at a time.
        cmp       R8,            8;
        jl aligned_1;

        // Write 8 bytes at a time.
        cmp       R8,            16;
        jl aligned_8;

        // Write 16 bytes at a time.
        cmp       R8,            32;
        jl aligned_16;

    aligned_32:
        movdqa    [ R9 ],        XMM0;
        movdqa    [ R9 + 16 ],   XMM0;

        add       R9,            32;
        sub       R8,            32;

        // Checks if we're done writing bytes.
        test      R8,            R8;
        jz end;

        // Write 1 byte at a time.
        cmp       R8,            8;
        jl aligned_1;

        // Write 8 bytes at a time.
        cmp       R8,            16;
        jl aligned_8;

    aligned_16:
        movdqa    [ R9 ],        XMM0;

        add       R9,            16;
        sub       R8,            16;

        // Checks if we're done writing bytes.
        test      R8,            R8;
        jz end;

        // Write 1 byte at a time.
        cmp       R8,            8;
        jl aligned_1;

    aligned_8:
        mov       [ R9 ],        RAX;

        add       R9,            8;
        sub       R8,            8;

        // Checks if we're done writing bytes.
        test      R8,            R8;
        jz end;

    aligned_1:
        mov       [ R9 ],        AL;

        inc       R9;
        dec       R8;

        test      R8,            R8;
        jnz aligned_1;

    end:
        ret;
    }
}
