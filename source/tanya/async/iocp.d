/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * This module provides API for Windows I/O Completion Ports.
 *
 * Note: Available only on Windows.
 *
 * Copyright: Eugene Wissner 2016-2020.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 * Source: $(LINK2 https://github.com/caraus-ecms/tanya/blob/master/source/tanya/async/iocp.d,
 *                 tanya/async/iocp.d)
 */
module tanya.async.iocp;

version (Windows)
{
    version = WindowsDoc;
}
else version (D_Ddoc)
{
    version = WindowsDoc;
    version (Windows)
    {
    }
    else
    {
        private struct OVERLAPPED
        {
        }
        private alias HANDLE = void*;
    }
}

version (WindowsDoc):

import tanya.sys.windows.winbase;

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
