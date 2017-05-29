/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/*
 * Internal package used by containers that rely on entries/nodes.
 *
 * Copyright: Eugene Wissner 2016-2017.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 */
module tanya.container.entry;

import tanya.typecons;

package struct SEntry(T)
{
    // Item content.
    T content;

    // Next item.
    SEntry* next;
}

package struct DEntry(T)
{
    // Item content.
    T content;

    // Previous and next item.
    DEntry* next, prev;
}

package struct HashEntry(K, V)
{
    this(ref K key, ref V value)
    {
        this.pair = Pair!(K, V)(key, value);
    }

    Pair!(K, V) pair;
    HashEntry* next;
}

package enum BucketStatus : byte
{
    deleted = -1,
    empty = 0,
    used = 1,
}

package struct Bucket(T)
{
    this(ref T content)
    {
        this.content = content;
    }

    @property void content(ref T content)
    {
        this.content_ = content;
        this.status = BucketStatus.used;
    }

    @property ref T content()
    {
        return this.content_;
    }

    void remove()
    {
        this.content = T.init;
        this.status = BucketStatus.deleted;
    }

    T content_;
    BucketStatus status = BucketStatus.empty;
}
