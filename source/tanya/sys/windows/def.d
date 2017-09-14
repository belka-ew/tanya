/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * Copyright: Eugene Wissner 2017.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 * Source: $(LINK2 https://github.com/caraus-ecms/tanya/blob/master/source/tanya/sys/windows/def.d,
 *                 tanya/sys/windows/def.d)
 */
module tanya.sys.windows.def;

version (Windows):

alias BYTE = ubyte;
alias TBYTE = wchar; // If Unicode, otherwise char.
alias CHAR = char; // Signed or unsigned char.
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

enum TRUE = 1;
enum FALSE = 0;