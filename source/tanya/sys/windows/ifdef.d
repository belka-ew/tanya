/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * Copyright: Eugene Wissner 2018.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 * Source: $(LINK2 https://github.com/caraus-ecms/tanya/blob/master/source/tanya/sys/windows/ifdef.d,
 *                 tanya/sys/windows/ifdef.d)
 */
module tanya.sys.windows.ifdef;

version (Windows):

import tanya.sys.windows.def;

union NET_LUID_LH
{
    ulong Value;
    ulong Info;
}

alias NET_LUID = NET_LUID_LH;
alias IF_LUID = NET_LUID_LH;

alias NET_IFINDEX = ULONG;

enum size_t IF_MAX_STRING_SIZE = 256;
