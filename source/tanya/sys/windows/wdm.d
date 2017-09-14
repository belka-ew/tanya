/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * Copyright: Eugene Wissner 2017.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 * Source: $(LINK2 https://github.com/caraus-ecms/tanya/blob/master/source/tanya/sys/windows/wdm.d,
 *                 tanya/sys/windows/wdm.d)
 */
module tanya.sys.windows.wdm;

version (Windows):

extern(Windows)
void RtlCopyMemory(scope void* Destination, 
                   scope const(void)* Source,
                   size_t Length) pure nothrow @system @nogc;

extern(Windows)
void RtlZeroMemory(scope void* Destination, size_t length)
pure nothrow @system @nogc;

extern(Windows)
void RtlMoveMemory(scope void* Destination,
                   scope const(void)* Source,
                   size_t Length) pure nothrow @system @nogc;

extern(Windows)
void RtlFillMemory(scope void* Destination, size_t length, char Fill)
pure nothrow @system @nogc;

extern(Windows)
void* RtlSecureZeroMemory(return void* ptr, size_t cnt)
pure nothrow @system @nogc;