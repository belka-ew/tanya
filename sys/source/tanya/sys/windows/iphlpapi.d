/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * Copyright: Eugene Wissner 2018-2019.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 * Source: $(LINK2 https://github.com/caraus-ecms/tanya/blob/master/source/tanya/sys/windows/iphlpapi.d,
 *                 tanya/sys/windows/iphlpapi.d)
 */
module tanya.sys.windows.iphlpapi;

version (Windows):

import tanya.sys.windows.def;
import tanya.sys.windows.ifdef;

extern(Windows)
DWORD ConvertInterfaceNameToLuidA(const(CHAR)* InterfaceName,
                                  NET_LUID* InterfaceLuid)
@nogc nothrow @system;

extern(Windows)
DWORD ConvertInterfaceLuidToIndex(const(NET_LUID)* InterfaceLuid,
                                  NET_IFINDEX* InterfaceIndex)
@nogc nothrow @system;

extern(Windows)
DWORD ConvertInterfaceIndexToLuid(NET_IFINDEX InterfaceIndex,
                                  NET_LUID* InterfaceLuid)
@nogc nothrow @system;

extern(Windows)
DWORD ConvertInterfaceLuidToNameA(const(NET_LUID)* InterfaceLuid,
                                  PSTR InterfaceName,
                                  size_t Length)
@nogc nothrow @system;
