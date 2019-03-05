/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/*
 * Copyright: Eugene Wissner 2018-2019.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 * Source: $(LINK2 https://github.com/caraus-ecms/tanya/blob/master/source/tanya/sys/posix/mman.d,
 *                 tanya/sys/posix/mman.d)
 */
module tanya.sys.posix.mman;

version (TanyaNative):

enum
{
    PROT_EXEC = 0x4, // Page can be executed.
    PROT_NONE = 0x0, // Page cannot be accessed.
    PROT_READ = 0x1, // Page can be read.
    PROT_WRITE = 0x2, // Page can be written.
}

enum
{
    MAP_FIXED = 0x10, // Interpret addr exactly.
    MAP_PRIVATE = 0x02, // Changes are private.
    MAP_SHARED = 0x01, // Share changes.
    MAP_ANONYMOUS = 0x20, // Don't use a file.
}
