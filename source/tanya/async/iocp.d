/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * Copyright: Eugene Wissner 2016-2017.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 */
module tanya.async.iocp;

version (Windows):

import core.sys.windows.winbase;
import core.sys.windows.windef;

/**
 * Provides an extendable representation of a Win32 $(D_PSYMBOL OVERLAPPED)
 * structure.
 */
class State
{
    /// For internal use by Windows API.
    align(1) OVERLAPPED overlapped;

    /// File/socket handle.
    HANDLE handle;

    /// For keeping events or event masks.
    int event;
}
