/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * This module implements a $(D_PSymbol Set) container that stores unique
 * values without any particular order.
 *
 * Copyright: Eugene Wissner 2017.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 */
module tanya.container.set;

import std.algorithm.mutation;
import std.traits;
import tanya.container;
import tanya.container.entry;
import tanya.memory;

/**
 * Bidirectional range that iterates over the $(D_PSYMBOL Set)'s values.
 *
 * Params:
 *  E = Element type.
 */
struct Range(E)
{
    @disable this();

    @property Range save()
    {
        return this;
    }
}

/**
 * Set is a data structure that stores unique values without any particular
 * order.
 *
 * This $(D_PSYMBOL Set) is implemented using closed hashing. Hash collisions
 * are resolved with linear probing.
 *
 * Params:
 *  T = Element type.
 */
struct Set(T)
{
    invariant
    {
        assert(this.lengthIndex < primes.length);
        assert(this.data.length == 0
            || this.data.length == primes[this.lengthIndex]);
    }

    /**
     * Constructor.
     *
     * Params:
     *  allocator = Allocator.
     *
     * Precondition: $(D_INLINECODE allocator !is null).
     */
    this(shared Allocator allocator)
    in
    {
        assert(allocator !is null);
    }
    body
    {
        this.allocator_ = allocator;
    }

    /**
     * Maximum amount of elements this $(D_PSYMBOL Set) can hold without
     * resizing and rehashing. Note that it doesn't mean that the
     * $(D_PSYMBOL Set) will hold $(I exactly) $(D_PSYMBOL capacity) elements.
     * $(D_PSYMBOL capacity) tells the size of the container under a best-case
     * distribution of elements.
     *
     * Returns: $(D_PSYMBOL Set) capacity.
     */
    @property size_t capacity() const
    {
        return this.data.length;
    }

    private static const size_t[41] primes = [
        3, 7, 13, 23, 29, 37, 53, 71, 97, 131, 163, 193, 239, 293, 389, 521,
        769, 919, 1103, 1327, 1543, 2333, 3079, 4861, 6151, 12289, 24593,
        49157, 98317, 196613, 393241, 786433, 1572869, 3145739, 6291469,
        12582917, 25165843, 139022417, 282312799, 573292817, 1164186217,
    ];

    static private size_t calculateHash(ref T value)
    {
        static if (isIntegral!T || isSomeChar!T || is(T == bool))
        {
            return (cast(size_t) value);
        }
        else
        {
            static assert(false);
        }
    }

    static private size_t locateBucket(ref DataType buckets, size_t hash)
    {
        return hash % buckets.length;
    }

    private enum InsertStatus : byte
    {
        found = -1,
        failed = 0,
        added = 1,
    }

    // Inserts the value in an empty or deleted bucket. If the value is
    // already in there, does nothing and returns true. If the hash array
    // is full returns false.
    static private InsertStatus insertInUnusedBucket(ref DataType buckets,
                                                     ref T value)
    {
        auto bucketPosition = locateBucket(buckets, calculateHash(value));

        foreach (ref e; buckets[bucketPosition .. $])
        {
            if (e.content == value) // Already in the set.
            {
                return InsertStatus.found;
            }
            else if (e.status != BucketStatus.used) // Insert the value.
            {
                e.content = value;
                return InsertStatus.added;
            }
        }
        return InsertStatus.failed;
    }

    /**
     * Inserts a new element.
     *
     * Params:
     *  value = Element value.
     *
     * Returns: Amount of new elements inserted.
     *
     * Throws: $(D_PSYMBOL HashContainerFullException) if the insertion failed.
     */
    size_t insert(T value)
    {
        if (this.data.length == 0)
        {
            this.data = DataType(primes[0], allocator);
        }

        InsertStatus status = insertInUnusedBucket(this.data, value);
        for (; !status; status = insertInUnusedBucket(this.data, value))
        {
            rehash();
        }
        return status == InsertStatus.added;
    }

    /**
     * Removes an element.
     *
     * Params:
     *  value = Element value.
     *
     * Returns: Amount of the elements removed.
     */
    size_t remove(T value)
    {
        if (this.data.length == 0)
        {
            return 0;
        }

        auto bucketPosition = locateBucket(this.data, calculateHash(value));
        foreach (ref e; this.data[bucketPosition .. $])
        {
            if (e.content == value) // Found.
            {
                e.remove();
                return 1;
            }
            else if (e.status == BucketStatus.empty) // Insert the value.
            {
                return 0;
            }
        }
        return 0;
    }

    private void rehash()
    {
        if ((this.primes.length - 1) == this.lengthIndex)
        {
            throw make!HashContainerFullException(defaultAllocator,
                                                  "Set is full");
        }

        auto storage = DataType(primes[this.lengthIndex + 1], allocator);
        foreach (ref e; this.data[])
        {
            if (e.status == BucketStatus.used)
            {
                insertInUnusedBucket(storage, e.content);
            }
        }
        move(storage, this.data);
        ++this.lengthIndex;
    }

    private alias DataType = Array!(Bucket!T);
    private DataType data;
    private size_t lengthIndex;

    mixin DefaultAllocator;
}

// Basic insertion logic.
private unittest
{
    Set!int set;

    assert(set.insert(5) == 1);
    assert(set.data[0].status == BucketStatus.empty);
    assert(set.data[1].status == BucketStatus.empty);
    assert(set.data[2].content == 5 && set.data[2].status == BucketStatus.used);
    assert(set.data.length == 3);

    assert(set.insert(5) == 0);
    assert(set.data[0].status == BucketStatus.empty);
    assert(set.data[1].status == BucketStatus.empty);
    assert(set.data[2].content == 5 && set.data[2].status == BucketStatus.used);
    assert(set.data.length == 3);

    assert(set.insert(9) == 1);
    assert(set.data[0].content == 9 && set.data[0].status == BucketStatus.used);
    assert(set.data[1].status == BucketStatus.empty);
    assert(set.data[2].content == 5 && set.data[2].status == BucketStatus.used);
    assert(set.data.length == 3);

    assert(set.insert(7) == 1);
    assert(set.insert(8) == 1);
    assert(set.data[0].content == 7);
    assert(set.data[1].content == 8);
    assert(set.data[2].content == 9);
    assert(set.data[3].status == BucketStatus.empty);
    assert(set.data[5].content == 5);
    assert(set.data.length == 7);

    assert(set.insert(16) == 1);
    assert(set.data[2].content == 9);
    assert(set.data[3].content == 16);
    assert(set.data[4].status == BucketStatus.empty);
}
