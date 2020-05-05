/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * Definitions from winbase.h.
 *
 * Copyright: Eugene Wissner 2017-2020.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 */
module tanya.sys.windows.winbase;

version (Windows):

public import tanya.sys.windows.def;

struct OVERLAPPED
{
    size_t Internal;
    size_t InternalHigh;
    union
    {
        struct
        {
            DWORD Offset;
            DWORD OffsetHigh;
        }
        void* Pointer;
    }
    HANDLE hEvent;
}

extern(Windows)
HANDLE CreateIoCompletionPort(HANDLE FileHandle,
                              HANDLE ExistingCompletionPort,
                              size_t CompletionKey,
                              DWORD NumberOfConcurrentThreads)
nothrow @system @nogc;

extern(Windows)
BOOL GetQueuedCompletionStatus(HANDLE CompletionPort,
                               DWORD* lpNumberOfBytes,
                               size_t* lpCompletionKey,
                               OVERLAPPED** lpOverlapped,
                               DWORD dwMilliseconds) nothrow @system @nogc;

extern(Windows)
BOOL GetOverlappedResult(HANDLE hFile,
                         OVERLAPPED* lpOverlapped,
                         DWORD* lpNumberOfBytesTransferred,
                         BOOL bWait) nothrow @system @nogc;
