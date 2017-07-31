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
