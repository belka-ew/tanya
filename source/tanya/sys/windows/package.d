/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * Copyright: Eugene Wissner 2017.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 * Source: $(LINK2 https://github.com/caraus-ecms/tanya/blob/master/source/tanya/sys/windows/package.d,
 *                 tanya/sys/windows/package.d)
 */
module tanya.sys.windows;

version (Windows):

public import tanya.sys.windows.def;
public import tanya.sys.windows.error;
public import tanya.sys.windows.wdm;
public import tanya.sys.windows.winsock2;