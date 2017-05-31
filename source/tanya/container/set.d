/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * This module implements a $(D_PSYMBOL Set) container that stores unique
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
    static if (isMutable!E)
    {
        private alias DataRange = Array!(Bucket!(Unqual!E)).Range;
    }
    else
    {
        private alias DataRange = Array!(Bucket!(Unqual!E)).ConstRange;
    }
    private DataRange dataRange;

    @disable this();

    private this(DataRange dataRange)
    {
        while (!dataRange.empty && dataRange.front.status != BucketStatus.used)
        {
            dataRange.popFront();
        }
        while (!dataRange.empty && dataRange.back.status != BucketStatus.used)
        {
            dataRange.popBack();
        }
        this.dataRange = dataRange;
    }

    @property Range save()
    {
        return this;
    }

    @property bool empty() const
    {
        return this.dataRange.empty();
    }

    @property void popFront()
    in
    {
        assert(!this.dataRange.empty);
        assert(this.dataRange.front.status == BucketStatus.used);
    }
    out
    {
        assert(this.dataRange.empty
            || this.dataRange.back.status == BucketStatus.used);
    }
    body
    {
        do
        {
            dataRange.popFront();
        }
        while (!dataRange.empty && dataRange.front.status != BucketStatus.used);
    }

    @property void popBack()
    in
    {
        assert(!this.dataRange.empty);
        assert(this.dataRange.back.status == BucketStatus.used);
    }
    out
    {
        assert(this.dataRange.empty
            || this.dataRange.back.status == BucketStatus.used);
    }
    body
    {
        do
        {
            dataRange.popBack();
        }
        while (!dataRange.empty && dataRange.back.status != BucketStatus.used);
    }

    @property ref inout(E) front() inout
    in
    {
        assert(!this.dataRange.empty);
        assert(this.dataRange.front.status == BucketStatus.used);
    }
    body
    {
        return dataRange.front.content;
    }

    @property ref inout(E) back() inout
    in
    {
        assert(!this.dataRange.empty);
        assert(this.dataRange.back.status == BucketStatus.used);
    }
    body
    {
        return dataRange.back.content;
    }

    Range opIndex()
    {
        return typeof(return)(this.dataRange[]);
    }

    Range!(const E) opIndex() const
    {
        return typeof(return)(this.dataRange[]);
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
    /// The range types for $(D_PSYMBOL Set).
    alias Range = .Range!T;

    /// Ditto.
    alias ConstRange = .Range!(const T);

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

    /**
     * Iterates over the $(D_PSYMBOL Set) and counts the elements.
     *
     * Returns: Count of elements within the $(D_PSYMBOL Set).
     */
    @property size_t length() const
    {
        size_t count;
        foreach (ref e; this.data[])
        {
            if (e.status == BucketStatus.used)
            {
                ++count;
            }
        }
        return count;
    }

    private static const size_t[41] primes = [
        3, 7, 13, 23, 29, 37, 53, 71, 97, 131, 163, 193, 239, 293, 389, 521,
        769, 919, 1103, 1327, 1543, 2333, 3079, 4861, 6151, 12289, 24593,
        49157, 98317, 196613, 393241, 786433, 1572869, 3145739, 6291469,
        12582917, 25165843, 139022417, 282312799, 573292817, 1164186217,
    ];

    /// The maximum number of buckets the container can have.
    enum size_t maxBucketCount = primes[$ - 1];

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

    static private size_t locateBucket(ref const DataType buckets, size_t hash)
    {
        return hash % buckets.length;
    }

    private enum InsertStatus : byte
    {
        found = -1,
        failed = 0,
        added = 1,
    }

    /*
     * Inserts the value in an empty or deleted bucket. If the value is
     * already in there, does nothing and returns true. If the hash array
     * is full returns false.
     */
    private InsertStatus insertInUnusedBucket(ref T value)
    {
        auto bucketPosition = locateBucket(this.data, calculateHash(value));

        foreach (ref e; this.data[bucketPosition .. $])
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

        InsertStatus status = insertInUnusedBucket(value);
        for (; !status; status = insertInUnusedBucket(value))
        {
            if ((this.primes.length - 1) == this.lengthIndex)
            {
                throw make!HashContainerFullException(defaultAllocator,
                                                      "Set is full");
            }
            rehashToSize(this.lengthIndex + 1);
        }
        return status == InsertStatus.added;
    }

    /**
     * Removes an element.
     *
     * Params:
     *  value = Element value.
     *
     * Returns: Number of elements removed, which is in the container with
     *          unique values `1` if an element existed, and `0` otherwise.
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
            else if (e.status == BucketStatus.empty)
            {
                break;
            }
        }
        return 0;
    }

    /**
     * $(D_KEYWORD in) operator.
     *
     * Params:
     *  value = Element to be searched for.
     *
     * Returns: $(D_KEYWORD true) if the given element exists in the container,
     *          $(D_KEYWORD false) otherwise.
     */
    bool opBinaryRight(string op : "in")(auto ref T value)
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
                return true;
            }
            else if (e.status == BucketStatus.empty)
            {
                break;
            }
        }
        return false;
    }

    /// Ditto.
    bool opBinaryRight(string op : "in")(auto ref const T value) const
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
                return true;
            }
            else if (e.status == BucketStatus.empty)
            {
                break;
            }
        }
        return false;
    }


    ///
    unittest
    {
        Set!int set;

        assert(5 !in set);
        set.insert(5);
        assert(5 in set);
    }

    /**
     * Sets the number of buckets in the container to at least $(D_PARAM n)
     * and rearranges all the elements according to their hash values.
     *
     * If $(D_PARAM n) is greater than the current $(D_PSYMBOL capacity)
     * and lower than or equal to $(D_PSYMBOL maxBucketCount), a rehash is
     * forced.
     *
     * If $(D_PARAM n) is greater than $(D_PSYMBOL maxBucketCount),
     * $(D_PSYMBOL maxBucketCount) is used instead as a new number of buckets.
i    *
     * If $(D_PARAM n) is equal to the current $(D_PSYMBOL capacity), rehashing
     * is forced without resizing the container.
     *
     * If $(D_PARAM n) is lower than the current $(D_PSYMBOL capacity), the
     * function may have no effect.
     *
     * Rehashing is automatically performed whenever the container needs space
     * to insert new elements.
     *
     * Params:
     *  n = Minimum number of buckets.
     */
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
        rehashToSize(lengthIndex);
    }

    // Takes an index in the primes array.
    private void rehashToSize(const size_t n)
    {
        auto storage = DataType(primes[n], allocator);
        DataLoop: foreach (ref e1; this.data[])
        {
            if (e1.status == BucketStatus.used)
            {
                auto bucketPosition = locateBucket(storage,
                                                   calculateHash(e1.content));

                foreach (ref e2; storage[bucketPosition .. $])
                {
                    if (e2.status != BucketStatus.used) // Insert the value.
                    {
                        e2.content = e1.content;
                        continue DataLoop;
                    }
                }
                return; // Rehashing failed.
            }
        }
        move(storage, this.data);
        this.lengthIndex = n;
    }

    /**
     * Returns: A bidirectional range that iterates over the $(D_PSYMBOL Set)'s
     *          elements.
     */
    Range opIndex()
    {
        return typeof(return)(this.data[]);
    }

    /// Ditto.
    ConstRange opIndex() const
    {
        return typeof(return)(this.data[]);
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

// Static checks.
private unittest
{
    import std.range.primitives;

    static assert(isBidirectionalRange!(Set!int.ConstRange));
    static assert(isBidirectionalRange!(Set!int.Range));

    static assert(!isInfinite!(Set!int.Range));
    static assert(!hasLength!(Set!int.Range));
}
