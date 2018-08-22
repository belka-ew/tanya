/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/*
 * Copyright: Eugene Wissner 2018.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 * Source: $(LINK2 https://github.com/caraus-ecms/tanya/blob/master/source/tanya/sys/posix/net/if_.d,
 *                 tanya/sys/posix/net/if_.d)
 */
module tanya.sys.posix.net.if_;

version (TanyaNative):

enum size_t IF_NAMESIZE = 16;

struct ifreq
{
    char[IF_NAMESIZE] ifr_name;

    union
    {
        int ifr_ifindex;
    }
}
