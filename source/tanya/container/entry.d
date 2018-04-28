/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/*
 * Internal package used by containers that rely on entries/nodes.
 *
 * Copyright: Eugene Wissner 2016-2018.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 * Source: $(LINK2 https://github.com/caraus-ecms/tanya/blob/master/source/tanya/container/entry.d,
 *                 tanya/container/entry.d)
 */
module tanya.container.entry;

import tanya.meta.trait;
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

package enum BucketStatus : byte
{
    deleted = -1,
    empty = 0,
    used = 1,
}

package struct Bucket(K, V = void)
{
    @property void key(ref K key)
    {
        this.key_ = key;
        this.status = BucketStatus.used;
    }

    @property ref inout(K) key() inout
    {
        return this.key_;
    }

    bool opEquals(ref K key)
    {
        if (this.status == BucketStatus.used && this.key == key)
        {
            return true;
        }
        return false;
    }

    bool opEquals(ref const K key) const
    {
        if (this.status == BucketStatus.used && this.key == key)
        {
            return true;
        }
        return false;
    }

    bool opEquals(ref typeof(this) that)
    {
        return key == that.key && this.status == that.status;
    }

    bool opEquals(ref typeof(this) that) const
    {
        return key == that.key && this.status == that.status;
    }

    void remove()
    {
        static if (hasElaborateDestructor!K)
        {
            destroy(key);
        }
        this.status = BucketStatus.deleted;
    }

    private K key_;
    static if (!is(V == void))
    {
        V value;
    }
    BucketStatus status = BucketStatus.empty;
}

// Possible sizes for the hash-based containers.
package static immutable size_t[33] primes = [
    0, 3, 7, 13, 23, 37, 53, 97, 193, 389, 769, 1543, 3079, 6151, 12289,
    24593, 49157, 98317, 196613, 393241, 786433, 1572869, 3145739, 6291469,
    12582917, 25165843, 50331653, 100663319, 201326611, 402653189,
    805306457, 1610612741, 3221225473
];

/*
 * Returns bucket position for `hash`. `0` may mean the 0th position or an
 * empty `buckets` array.
 */
package size_t locateBucket(T)(ref const T buckets, const size_t hash)
{
    return buckets.length == 0 ? 0 : hash % buckets.length;
}

package enum InsertStatus : byte
{
    found = -1,
    failed = 0,
    added = 1,
}
