/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * Base type definitions and aliases.
 *
 * This module doesn't provide aliases for all types used by Windows, but only
 * for types that can vary on different platforms. For example there is no
 * need to define `INT32` alias for D, since $(D_KEYWORD int) is always a
 * 32-bit signed integer. But `int` and its Windows alias `INT` is not the
 * same on all platforms in C, so its size can be something differen than
 * 32 bit, therefore an $(D_PSYMBOL INT) alias is available in this module.
 * $(D_PARAM TCHAR) can be a $(D_KEYWORD char) if Unicode isn't supported or
 * $(D_KEYWORD wchar) if Unicode is supported, so $(D_PSYMBOL TCHAR) is
 * defined here.
 * Also aliases for specific types like $(D_PSYMBOL SOCKET) are defined here.
 *
 * Copyright: Eugene Wissner 2017-2019.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 */
module tanya.sys.windows.def;

version (Windows):

alias BYTE = ubyte;
alias TBYTE = wchar; // If Unicode, otherwise char.
alias CHAR = char; // Signed or unsigned char.
alias WCHAR = wchar;
alias TCHAR = wchar; // If Unicode, otherwise char.
alias SHORT = short;
alias USHORT = ushort;
alias WORD = ushort;
alias INT = int;
alias UINT = uint;
alias LONG = int;
alias ULONG = uint;
alias DWORD = uint;
alias LONGLONG = long; // Or double.
alias ULONGLONG = ulong; // Or double.
alias DWORDLONG = ulong;
alias FLOAT = float;
alias BOOL = int;
alias BOOLEAN = BYTE;

alias HANDLE = void*;
enum HANDLE INVALID_HANDLE_VALUE = cast(HANDLE) -1;

enum TRUE = 1;
enum FALSE = 0;

alias PSTR = CHAR*;
alias PWSTR = WCHAR*;
alias PTSTR = TCHAR*;

align(1) struct GUID
{
    uint Data1;
    ushort Data2;
    ushort Data3;
    char[8] Data4;
}
