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
import tanya.memory.allocator;
import tanya.meta.trait;
import tanya.meta.transform;
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
    static if (is(V == void))
    {
        K key_;
    }
    else
    {
        alias KV = Tuple!(K, "key", V, "value");
        KV kv;
    }
    BucketStatus status = BucketStatus.empty;

    this(ref K key)
    {
        this.key = key;
    }

    @property void key(ref K key)
    {
        this.key() = key;
        this.status = BucketStatus.used;
    }

    @property ref inout(K) key() inout
    {
        static if (is(V == void))
        {
            return this.key_;
        }
        else
        {
            return this.kv.key;
        }
    }

    void moveKey(ref K key)
    {
        move(key, this.key());
        this.status = BucketStatus.used;
    }

    bool opEquals(T)(ref const T key) const
    {
        return this.status == BucketStatus.used && this.key == key;
    }

    bool opEquals(ref const(typeof(this)) that) const
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
    alias Key = K;
    alias Value = V;
    alias Bucket = .Bucket!(Key, Value);
    alias Buckets = Array!Bucket;

    Buckets array;
    size_t lengthIndex;
    size_t length;

    this(shared Allocator allocator)
    in
    {
        assert(allocator !is null);
    }
    do
    {
        this.array = Buckets(allocator);
    }

    this(T)(ref T data, shared Allocator allocator)
    if (is(Unqual!T == HashArray))
    in
    {
        assert(allocator !is null);
    }
    do
    {
        this.array = Buckets(data.array, allocator);
        this.lengthIndex = data.lengthIndex;
        this.length = data.length;
    }

    // Move constructor
    void move(ref HashArray data, shared Allocator allocator)
    in
    {
        assert(allocator !is null);
    }
    do
    {
        this.array = Buckets(.move(data.array), allocator);
        this.lengthIndex = data.lengthIndex;
        this.length = data.length;
    }

    void swap(ref HashArray data)
    {
        .swap(this.array, data.array);
        .swap(this.lengthIndex, data.lengthIndex);
        .swap(this.length, data.length);
    }

    void opAssign(ref typeof(this) that)
    {
        this.array = that.array;
        this.lengthIndex = that.lengthIndex;
        this.length = that.length;
    }

    @property size_t bucketCount() const
    {
        return primes[this.lengthIndex];
    }

    /*
     * Returns bucket position for `hash`. `0` may mean the 0th position or an
     * empty `buckets` array.
     */
    size_t locateBucket(T)(ref const T key) const
    {
        return this.array.length == 0 ? 0 : hasher(key) % bucketCount;
    }

    /*
     * If the key doesn't already exists, returns an empty bucket the key can
     * be inserted in and adjusts the element count. Otherwise returns the
     * bucket containing the key.
     */
    ref Bucket insert(ref Key key)
    {
        const newLengthIndex = this.lengthIndex + 1;
        if (newLengthIndex != primes.length)
        {
            foreach (ref e; this.array[locateBucket(key) .. $])
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

            this.rehashToSize(newLengthIndex);
        }

        foreach (ref e; this.array[locateBucket(key) .. $])
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

        this.array.length = this.array.length + 1;
        ++this.length;
        return this.array[$ - 1];
    }

    // Takes an index in the primes array.
    void rehashToSize(const size_t n)
    in
    {
        assert(n < primes.length);
    }
    do
    {
        auto storage = typeof(this.array)(primes[n], this.array.allocator);
        DataLoop: foreach (ref e1; this.array[])
        {
            if (e1.status == BucketStatus.used)
            {
                auto bucketPosition = hasher(e1.key) % primes[n];

                foreach (ref e2; storage[bucketPosition .. $])
                {
                    if (e2.status != BucketStatus.used) // Insert the key
                    {
                        .move(e1, e2);
                        continue DataLoop;
                    }
                }
                storage.insertBack(.move(e1));
            }
        }
        .move(storage, this.array);
        this.lengthIndex = n;
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
        if (lengthIndex > this.lengthIndex)
        {
            this.rehashToSize(lengthIndex);
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

    size_t remove(ref Key key)
    {
        foreach (ref e; this.array[locateBucket(key) .. $])
        {
            if (e == key) // Found.
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

    bool opBinaryRight(string op : "in", T)(ref const T key) const
    {
        foreach (ref e; this.array[locateBucket(key) .. $])
        {
            if (e == key) // Found.
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
