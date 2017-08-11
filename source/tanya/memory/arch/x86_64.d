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

package (tanya.memory) template fill(ubyte Byte)
{
    private enum const(char[]) MovArrayPointer(string Destination)()
    {
        string asmCode = "asm pure nothrow @nogc { mov ";
        version (Windows)
        {
            asmCode ~= Destination ~ ", [ RCX + 8 ];";
        }
        else
        {
            asmCode ~= Destination ~ ", RSI;";
        }
        return asmCode ~ "}";
    }

    pragma(inline, true)
    void fill(void[] memory)
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
        }
        else asm pure nothrow @nogc
        {
            /*
             * RSI - pointer.
             * RDI - length.
             */
            mov       R8,           RDI;
        }
        mixin(MovArrayPointer!"R9");

        asm pure nothrow @nogc
        {
            // Check for zero length.
            test      R8,           R8;
            jz        end;
        }
        // Set 128- and 64-bit registers to values we want to fill with.
        static if (Byte == 0)
        {
            asm pure nothrow @nogc
            {
                xor  RAX,  RAX;
                pxor XMM0, XMM0;
            }
        }
        else
        {
            enum ulong FilledBytes = FilledBytes!Byte;
            asm pure nothrow @nogc
            {
                mov     RAX,  FilledBytes;
                movq    XMM0, RAX;
                movlhps XMM0, XMM0;
            }
        }
        asm pure nothrow @nogc
        {
            // Check if the pointer is aligned to a 16-byte boundary.
            and       R9,           -0x10;
        }
        // Compute the number of misaligned bytes.
        mixin(MovArrayPointer!"R10");
        asm pure nothrow @nogc
        {
            sub       R10,          R9;

            test      R10,          R10;
            jz aligned;

            // Get the number of bytes to be written until we are aligned.
            mov       RDX,          0x10;
            sub       RDX,          R10;
        }
        mixin(MovArrayPointer!"R9");
        asm pure nothrow @nogc
        {
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
    }
    // Prepare the registers for movsb.
    version (Windows) asm pure nothrow @nogc
    {
        // RDX - source.
        // RCX - target.

        mov RAX, [ RCX + 8 ];
        mov R10, [ RDX + 8 ];
        mov RCX, [ RDX ];

        lea RDI, [ RAX + RCX - 1 ];
        lea RSI, [ R10 + RCX - 1 ];
    }
    else asm pure nothrow @nogc
    {
        // RDX - source length.
        // RCX - source data.
        // RDI - target length
        // RSI - target data.

        lea RDI, [ RSI + RDX - 1 ];
        lea RSI, [ RCX + RDX - 1 ];
        mov RCX, RDX;
    }
    asm pure nothrow @nogc
    {
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
    }
    // Set the registers for cmpsb/cmpsq.
    version (Windows) asm pure nothrow @nogc
    {
        // RDX - r1.
        // RCX - r2.

        mov RDI, [ RCX + 8 ];
        mov RSI, [ RDX + 8 ];
        mov RDX, [ RDX ];
        mov RCX, [ RCX ];
    }
    else asm pure nothrow @nogc
    {
        // RDX - r1 length.
        // RCX - r1 data.
        // RDI - r2 length
        // RSI - r2 data.

        mov RSI, RCX;
        mov RCX, RDI;
        mov RDI, R8;
    }
    asm pure nothrow @nogc
    {
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
