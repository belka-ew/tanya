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

import tanya.algorithm.mutation;
import tanya.container.array;
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
    private alias Key = K;
    private alias Value = V;

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

package struct HashArray(alias hasher, K, V = void)
{
    alias Bucket = .Bucket!(K, V);
    alias Buckets = Array!Bucket;

    Array!Bucket array;
    size_t lengthIndex;
    size_t length;

    /*
     * Returns bucket position for `hash`. `0` may mean the 0th position or an
     * empty `buckets` array.
     */
    size_t locateBucket(ref const K key) const
    {
        return this.array.length == 0 ? 0 : hasher(key) % this.array.length;
    }

    /*
     * Inserts the value in an empty or deleted bucket. If the value is
     * already in there, does nothing and returns InsertStatus.found. If the
     * hash array is full returns InsertStatus.failed. Otherwise,
     * InsertStatus.added is returned.
     */
    ref Bucket insert(ref K key)
    {
        while (true)
        {
            auto bucketPosition = locateBucket(key);

            foreach (ref e; this.array[bucketPosition .. $])
            {
                if (e == key)
                {
                    return e;
                }
                else if (e.status != BucketStatus.used)
                {
                    ++this.length;
                    return e;
                }
            }

            if (primes.length == (this.lengthIndex + 1))
            {
                this.array.insertBack(Bucket(key));
                return this.array[$ - 1];
            }
            if (this.rehashToSize(this.lengthIndex + 1))
            {
                ++this.lengthIndex;
            }
        }
    }

    // Takes an index in the primes array.
    bool rehashToSize(const size_t n)
    {
        auto storage = typeof(this.array)(primes[n], this.array.allocator);
        DataLoop: foreach (ref e1; this.array[])
        {
            if (e1.status == BucketStatus.used)
            {
                auto bucketPosition = hasher(e1.key) % storage.length;

                foreach (ref e2; storage[bucketPosition .. $])
                {
                    if (e2.status != BucketStatus.used) // Insert the value.
                    {
                        e2 = e1;
                        continue DataLoop;
                    }
                }
                return false; // Rehashing failed.
            }
        }
        move(storage, this.array);
        return true;
    }

    void rehash(const size_t n)
    {
        size_t lengthIndex;
        for (; lengthIndex < primes.length; ++lengthIndex)
        {
            if (primes[lengthIndex] >= n)
            {
                break;
            }
        }
        if (this.rehashToSize(lengthIndex))
        {
            this.lengthIndex = lengthIndex;
        }
    }

    @property size_t capacity() const
    {
        return this.array.length;
    }

    void clear()
    {
        this.array.clear();
        this.length = 0;
    }

    size_t remove(ref K value)
    {
        auto bucketPosition = locateBucket(value);
        foreach (ref e; this.array[bucketPosition .. $])
        {
            if (e == value) // Found.
            {
                e.remove();
                --this.length;
                return 1;
            }
            else if (e.status == BucketStatus.empty)
            {
                break;
            }
        }
        return 0;
    }

    bool find(ref const K value) const
    {
        auto bucketPosition = locateBucket(value);
        foreach (ref e; this.array[bucketPosition .. $])
        {
            if (e == value) // Found.
            {
                return true;
            }
            else if (e.status == BucketStatus.empty)
            {
                break;
            }
        }
        return false;
    }
}
