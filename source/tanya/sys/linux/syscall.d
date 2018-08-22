/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/*
 * Copyright: Eugene Wissner 2018.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 * Source: $(LINK2 https://github.com/caraus-ecms/tanya/blob/master/source/tanya/sys/linux/syscall.d,
 *                 tanya/sys/linux/syscall.d)
 */
module tanya.sys.linux.syscall;

version (TanyaNative):

extern ptrdiff_t syscall(ptrdiff_t, ptrdiff_t, ptrdiff_t)
@nogc nothrow @system;

extern ptrdiff_t syscall(ptrdiff_t, ptrdiff_t, ptrdiff_t, ptrdiff_t)
@nogc nothrow @system;

extern ptrdiff_t syscall(ptrdiff_t,
                         ptrdiff_t,
                         ptrdiff_t,
                         ptrdiff_t,
                         ptrdiff_t,
                         ptrdiff_t,
                         ptrdiff_t) @nogc nothrow @system;

// Same syscalls as above but pure.
private template getOverloadMangling(size_t n)
{
    enum string getOverloadMangling = __traits(getOverloads,
                                               tanya.sys.linux.syscall,
                                               "syscall")[n].mangleof;
}

pragma(mangle, getOverloadMangling!0)
extern ptrdiff_t syscall_(ptrdiff_t, ptrdiff_t, ptrdiff_t)
@nogc nothrow pure @system;

pragma(mangle, getOverloadMangling!1)
extern ptrdiff_t syscall(ptrdiff_t, ptrdiff_t, ptrdiff_t, ptrdiff_t)
@nogc nothrow pure @system;

pragma(mangle, getOverloadMangling!2)
extern ptrdiff_t syscall_(ptrdiff_t,
                          ptrdiff_t,
                          ptrdiff_t,
                          ptrdiff_t,
                          ptrdiff_t,
                          ptrdiff_t,
                          ptrdiff_t) @nogc nothrow pure @system;
