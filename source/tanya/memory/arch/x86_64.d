/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/*
 * Implementions of functions found in $(D_PSYMBOL tanya.memory.op) for x64.
 *
 * Copyright: Eugene Wissner 2017.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 * Source: $(LINK2 https://github.com/caraus-ecms/tanya/blob/master/source/tanya/memory/arch/x86_64.d,
 *                 tanya/memory/arch/x86_64.d)
 */
module tanya.memory.arch.x86_64;

import tanya.memory.op;

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

        // RDX - source length.
        // RCX - source data.
        // RDI - target length
        // RSI - target data.

        mov RDI, RSI;
        mov RSI, RCX;

        cmp RDX, 0x08;
        jc aligned_1;
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

    aligned_1:
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
package (tanya.memory) void fill(void[], ulong) pure nothrow @system @nogc
{
    asm pure nothrow @nogc
    {
        naked;

        // Check for zero length.
        test      RSI,           RSI;
        jz        end;

        /*
         * RDX - pointer.
         * RSI - length.
         * RDI - value filled with a byte.
         */
        mov       RAX,          RSI;
        mov       R8,           RDX;

        movq      XMM0,         RDI;
        movlhps   XMM0,         XMM0;

        // Check if the pointer is aligned to a 16-byte boundary.
        and       R8,           -0x10;

        // Compute the number of misaligned bytes.
        mov       R9,           RDX;
        sub       R9,           R8;

        test      R9,           R9;
        jz aligned;

        // Get the number of bytes to be written until we are aligned.
        mov       RCX,          0x10;
        sub       RCX,          R9;

        mov       R8,           RDX;

    naligned:
        mov       [ R8 ],       DIL; // Write a byte.

        // Advance the pointer. Decrease the total number of bytes
        // and the misaligned ones.
        inc       R8;
        dec       RCX;
        dec       RAX;

        // Checks if we are aligned.
        test      RCX,          RCX;
        jnz naligned;

    aligned:
        // Checks if we're done writing bytes.
        test      RAX,          RAX;
        jz end;

        // Write 1 byte at a time.
        cmp       RAX,          8;
        jl aligned_1;

        // Write 8 bytes at a time.
        cmp       RAX,          16;
        jl aligned_8;

        // Write 16 bytes at a time.
        cmp       RAX,          32;
        jl aligned_16;

        // Write 32 bytes at a time.
        cmp       RAX,          64;
        jl aligned_32;

    aligned_64:
        movdqa    [ R8 ],        XMM0;
        movdqa    [ R8 + 16 ],   XMM0;
        movdqa    [ R8 + 32 ],   XMM0;
        movdqa    [ R8 + 48 ],   XMM0;

        add       R8,            64;
        sub       RAX,           64;

        cmp       RAX,           64;
        jge aligned_64;

        // Checks if we're done writing bytes.
        test      RAX,           RAX;
        jz end;

        // Write 1 byte at a time.
        cmp       RAX,           8;
        jl aligned_1;

        // Write 8 bytes at a time.
        cmp       RAX,           16;
        jl aligned_8;

        // Write 16 bytes at a time.
        cmp       RAX,           32;
        jl aligned_16;

    aligned_32:
        movdqa    [ R8 ],        XMM0;
        movdqa    [ R8 + 16 ],   XMM0;

        add       R8,            32;
        sub       RAX,           32;

        // Checks if we're done writing bytes.
        test      RAX,           RAX;
        jz end;

        // Write 1 byte at a time.
        cmp       RAX,           8;
        jl aligned_1;

        // Write 8 bytes at a time.
        cmp       RAX,           16;
        jl aligned_8;

    aligned_16:
        movdqa    [ R8 ],        XMM0;

        add       R8,            16;
        sub       RAX,           16;

        // Checks if we're done writing bytes.
        test      RAX,           RAX;
        jz end;

        // Write 1 byte at a time.
        cmp       RAX,           8;
        jl aligned_1;

    aligned_8:
        mov       [ R8 ],        RDI;

        add       R8,            8;
        sub       RAX,           8;

        // Checks if we're done writing bytes.
        test      RAX,           RAX;
        jz end;

    aligned_1:
        mov       [ R8 ],        DIL;

        inc       R8;
        dec       RAX;

        test      RAX,            RAX;
        jnz aligned_1;

    end:
        ret;
    }
}

pragma(inline, true)
package (tanya.memory) void copyBackward(const void[] source, void[] target)
pure nothrow @system  @nogc
{
    asm pure nothrow @nogc
    {
        naked;

        // Save the registers should be restored.
        mov R8, RSI;
        mov R9, RDI;

        // RDX - source length.
        // RCX - source data.
        // RDI - target length
        // RSI - target data.

        lea RDI, [ RSI + RDX - 1 ];
        lea RSI, [ RCX + RDX - 1 ];
        mov RCX, RDX;

        std; // Set the direction flag.

        rep;
        movsb;

        cld; // Clear the direction flag.

        // Restore registers.
        mov RDI, R9;
        mov RSI, R8;

        ret;
    }
}

pragma(inline, true)
package (tanya.memory) int cmp(const void[] r1, const void[] r2)
pure nothrow @system @nogc
{
    asm pure nothrow @nogc
    {
        naked;

        // RDI and RSI should be preserved.
        mov R9, RDI;
        mov R8, RSI;

        // RDX - r1 length.
        // RCX - r1 data.
        // RDI - r2 length
        // RSI - r2 data.

        mov RSI, RCX;
        mov RCX, RDI;
        mov RDI, R8;

        // Compare the lengths.
        cmp RDX, RCX;
        jl  less;
        jg  greater;

        // Check if we're aligned.
        cmp RDX, 0x08;
        jc aligned_1;
        test EDI, 0x07;
        jz aligned_8;

    naligned:
        cmpsb;
        jl less;
        jg greater;

        dec RDX;
        test EDI, 0x07;
        jnz naligned;

    aligned_8:
        mov RCX, RDX;
        shr RCX, 0x03;

        repe;
        cmpsq;
        jl less;
        jg greater;

        and EDX, 0x07;
        jz equal;

    aligned_1: // Compare the remaining bytes.
        mov RCX, RDX;

        repe;
        cmpsb;
        jl less;
        jg greater;

    equal:
        xor RAX, RAX; // Return 0.
        jmp end;

    greater:
        mov RAX, 1;
        jmp end;

    less:
        mov RAX, -1;
        jmp end;

    end: // Restore registers.
        mov RSI, R8;
        mov RDI, R9;

        ret;
    }
}
