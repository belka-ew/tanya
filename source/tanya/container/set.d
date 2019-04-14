/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * This module implements a $(D_PSYMBOL Set) container that stores unique
 * values without any particular order.
 *
 * Copyright: Eugene Wissner 2017-2019.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 * Source: $(LINK2 https://github.com/caraus-ecms/tanya/blob/master/source/tanya/container/set.d,
 *                 tanya/container/set.d)
 */
module tanya.container.set;

import tanya.container.array;
import tanya.container.entry;
import tanya.hash.lookup;
import tanya.memory.allocator;
import tanya.memory.lifetime;
import tanya.meta.trait;
import tanya.meta.transform;
import tanya.range.primitive;

/**
 * Bidirectional range that iterates over the $(D_PSYMBOL Set)'s values.
 *
 * Params:
 *  T = Type of the internal hash storage.
 */
struct Range(T)
{
    private alias E = CopyConstness!(T, T.Key);
    static if (isMutable!T)
    {
        private alias DataRange = T.array.Range;
    }
    else
    {
        private alias DataRange = T.array.ConstRange;
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

    void popFront()
    in (!empty)
    in (this.dataRange.front.status == BucketStatus.used)
    out (; empty || this.dataRange.back.status == BucketStatus.used)
    {
        do
        {
            this.dataRange.popFront();
        }
        while (!empty && dataRange.front.status != BucketStatus.used);
    }

    void popBack()
    in (!empty)
    in (this.dataRange.back.status == BucketStatus.used)
    out (; empty || this.dataRange.back.status == BucketStatus.used)
    {
        do
        {
            this.dataRange.popBack();
        }
        while (!empty && dataRange.back.status != BucketStatus.used);
    }

    @property ref inout(E) front() inout
    in (!empty)
    in (this.dataRange.front.status == BucketStatus.used)
    {
        return this.dataRange.front.key;
    }

    @property ref inout(E) back() inout
    in (!empty)
    in (this.dataRange.back.status == BucketStatus.used)
    {
        return this.dataRange.back.key;
    }

    Range opIndex()
    {
        return typeof(return)(this.dataRange[]);
    }

    Range!(const T) opIndex() const
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
 * $(D_PARAM T) should be hashable with $(D_PARAM hasher). $(D_PARAM hasher) is
 * a callable that accepts an argument of type $(D_PARAM T) and returns a hash
 * value for it ($(D_KEYWORD size_t)).
 *
 * Params:
 *  T      = Element type.
 *  hasher = Hash function for $(D_PARAM T).
 */
struct Set(T, alias hasher = hash)
if (isHashFunction!(hasher, T))
{
    private alias HashArray = .HashArray!(hasher, T);
    private alias Buckets = HashArray.Buckets;

    private HashArray data;

    /// The range types for $(D_PSYMBOL Set).
    alias Range = .Range!HashArray;

    /// ditto
    alias ConstRange = .Range!(const HashArray);

    invariant (this.data.lengthIndex < primes.length);
    invariant (this.data.array.length == 0
            || this.data.array.length == primes[this.data.lengthIndex]);

    /**
     * Constructor.
     *
     * Params:
     *  n         = Minimum number of buckets.
     *  allocator = Allocator.
     *
     * Precondition: $(D_INLINECODE allocator !is null).
     */
    this(size_t n, shared Allocator allocator = defaultAllocator)
    in (allocator !is null)
    {
        this(allocator);
        this.data.rehash(n);
    }

    ///
    @nogc nothrow pure @safe unittest
    {
        auto set = Set!int(5);
        assert(set.capacity == 7);
    }

    /// ditto
    this(shared Allocator allocator)
    in (allocator !is null)
    {
        this.data = HashArray(allocator);
    }

    /**
     * Initializes this $(D_PARAM Set) from another one.
     *
     * If $(D_PARAM init) is passed by reference, it will be copied.
     * If $(D_PARAM init) is passed by value, it will be moved.
     *
     * Params:
     *  S         = Source set type.
     *  init      = Source set.
     *  allocator = Allocator.
     *
     * Precondition: $(D_INLINECODE allocator !is null).
     */
    this(S)(ref S init, shared Allocator allocator = defaultAllocator)
    if (is(Unqual!S == Set))
    in (allocator !is null)
    {
        this.data = HashArray(init.data, allocator);
    }

    /// ditto
    this(S)(S init, shared Allocator allocator = defaultAllocator)
    if (is(S == Set))
    in (allocator !is null)
    {
        this.data.move(init.data, allocator);
    }

    /**
     * Initializes the set from a forward range.
     *
     * Params:
     *  R         = Range type.
     *  range     = Forward range.
     *  allocator = Allocator.
     *
     * Precondition: $(D_INLINECODE allocator !is null).
     */
    this(R)(scope R range, shared Allocator allocator = defaultAllocator)
    if (isForwardRange!R
     && isImplicitlyConvertible!(ElementType!R, T)
     && !isInfinite!R)
    in (allocator !is null)
    {
        this(allocator);
        insert(range);
    }

    ///
    @nogc nothrow pure @safe unittest
    {
        int[2] range = [1, 2];
        Set!int set = Set!int(range[]);

        assert(1 in set);
        assert(2 in set);
    }

    /**
     * Initializes the set from a static array.
     *
     * Params:
     *  n         = Array size.
     *  array     = Static array.
     *  allocator = Allocator.
     *
     * Precondition: $(D_INLINECODE allocator !is null).
     */
    this(size_t n)(T[n] array, shared Allocator allocator = defaultAllocator)
    in (allocator !is null)
    {
        this(allocator);
        insert(array[]);
    }

    ///
    @nogc nothrow pure @safe unittest
    {
        Set!int set = Set!int([1, 2]);

        assert(1 in set);
        assert(2 in set);
    }

    /**
     * Assigns another set.
     *
     * If $(D_PARAM that) is passed by reference, it will be copied.
     * If $(D_PARAM that) is passed by value, it will be moved.
     *
     * Params:
     *  S    = Content type.
     *  that = The value should be assigned.
     *
     * Returns: $(D_KEYWORD this).
     */
    ref typeof(this) opAssign(S)(ref S that)
    if (is(Unqual!S == Set))
    {
        this.data = that.data;
        return this;
    }

    /// ditto
    ref typeof(this) opAssign(S)(S that) @trusted
    if (is(S == Set))
    {
        this.data.swap(that.data);
        return this;
    }

    /**
     * Returns: Used allocator.
     *
     * Postcondition: $(D_INLINECODE allocator !is null)
     */
    @property shared(Allocator) allocator() const
    out (allocator; allocator !is null)
    {
        return this.data.array.allocator;
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
        return this.data.capacity;
    }

    ///
    @nogc nothrow pure @safe unittest
    {
        Set!int set;
        assert(set.capacity == 0);

        set.insert(8);
        assert(set.capacity == 3);
    }

    /**
     * Iterates over the $(D_PSYMBOL Set) and counts the elements.
     *
     * Returns: Count of elements within the $(D_PSYMBOL Set).
     */
    @property size_t length() const
    {
        return this.data.length;
    }

    ///
    @nogc nothrow pure @safe unittest
    {
        Set!int set;
        assert(set.length == 0);

        set.insert(8);
        assert(set.length == 1);
    }

    /**
     * Tells whether the container contains any elements.
     *
     * Returns: Whether the container is empty.
     */
    @property bool empty() const
    {
        return length == 0;
    }

    ///
    @nogc nothrow pure @safe unittest
    {
        Set!int set;
        assert(set.empty);
        set.insert(5);
        assert(!set.empty);
    }

    /**
     * Removes all elements.
     */
    void clear()
    {
        this.data.clear();
    }

    ///
    @nogc nothrow pure @safe unittest
    {
        Set!int set;
        set.insert(5);
        assert(!set.empty);
        set.clear();
        assert(set.empty);
    }

    /**
     * Returns current bucket count in the container.
     *
     * Bucket count equals to the number of the elements can be saved in the
     * container in the best case scenario for key distribution, i.d. every key
     * has a unique hash value. In a worse case the bucket count can be less
     * than the number of elements stored in the container.
     *
     * Returns: Current bucket count.
     *
     * See_Also: $(D_PSYMBOL rehash).
     */
    @property size_t bucketCount() const
    {
        return this.data.bucketCount;
    }

    /// The maximum number of buckets the container can have.
    enum size_t maxBucketCount = primes[$ - 1];

    /**
     * Inserts a new element.
     *
     * Params:
     *  value = Element value.
     *
     * Returns: Amount of new elements inserted.
     */
    size_t insert()(ref T value)
    {
        auto e = ((ref v) @trusted => &this.data.insert(v))(value);
        if (e.status != BucketStatus.used)
        {
            e.moveKey(value);
            return 1;
        }
        return 0;
    }

    size_t insert()(T value)
    {
        auto e = ((ref v) @trusted => &this.data.insert(v))(value);
        if (e.status != BucketStatus.used)
        {
            e.key = value;
            return 1;
        }
        return 0;
    }

    ///
    @nogc nothrow pure @safe unittest
    {
        Set!int set;
        assert(8 !in set);

        assert(set.insert(8) == 1);
        assert(set.length == 1);
        assert(8 in set);

        assert(set.insert(8) == 0);
        assert(set.length == 1);
        assert(8 in set);

        assert(set.remove(8));
        assert(set.insert(8) == 1);
    }

    /**
     * Inserts the value from a forward range into the set.
     *
     * Params:
     *  R     = Range type.
     *  range = Forward range.
     *
     * Returns: The number of new elements inserted.
     */
    size_t insert(R)(scope R range)
    if (isForwardRange!R
     && isImplicitlyConvertible!(ElementType!R, T)
     && !isInfinite!R)
    {
        size_t count;
        foreach (e; range)
        {
            count += insert(e);
        }
        return count;
    }

    ///
    @nogc nothrow pure @safe unittest
    {
        Set!int set;

        int[3] range = [2, 1, 2];

        assert(set.insert(range[]) == 2);
        assert(1 in set);
        assert(2 in set);
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
        return this.data.remove(value);
    }

    ///
    @nogc nothrow pure @safe unittest
    {
        Set!int set;
        set.insert(8);

        assert(8 in set);
        assert(set.remove(8) == 1);
        assert(set.remove(8) == 0);
        assert(8 !in set);
    }

    /**
     * $(D_KEYWORD in) operator.
     *
     * Params:
     *  U     = Type comparable with the element type, used for the lookup.
     *  value = Element to be searched for.
     *
     * Returns: $(D_KEYWORD true) if the given element exists in the container,
     *          $(D_KEYWORD false) otherwise.
     */
    bool opBinaryRight(string op : "in", U)(auto ref const U value) const
    if (ifTestable!(U, a => T.init == a))
    {
        return value in this.data;
    }

    ///
    @nogc nothrow pure @safe unittest
    {
        Set!int set;

        assert(5 !in set);
        set.insert(5);
        assert(5 in set);
        assert(8 !in set);
    }

    /**
     * Sets the number of buckets in the container to at least $(D_PARAM n)
     * and rearranges all the elements according to their hash values.
     *
     * If $(D_PARAM n) is greater than the current $(D_PSYMBOL bucketCount)
     * and lower than or equal to $(D_PSYMBOL maxBucketCount), a rehash is
     * forced.
     *
     * If $(D_PARAM n) is greater than $(D_PSYMBOL maxBucketCount),
     * $(D_PSYMBOL maxBucketCount) is used instead as a new number of buckets.
     *
     * If $(D_PARAM n) is less than or equal to the current
     * $(D_PSYMBOL bucketCount), the function may have no effect.
     *
     * Rehashing is automatically performed whenever the container needs space
     * to insert new elements.
     *
     * Params:
     *  n = Minimum number of buckets.
     */
    void rehash(size_t n)
    {
        this.data.rehash(n);
    }

    /**
     * Returns a bidirectional range over the container.
     *
     * Returns: A bidirectional range that iterates over the container.
     */
    Range opIndex()
    {
        return typeof(return)(this.data.array[]);
    }

    /// ditto
    ConstRange opIndex() const
    {
        return typeof(return)(this.data.array[]);
    }

    ///
    @nogc nothrow pure @safe unittest
    {
        Set!int set;
        assert(set[].empty);

        set.insert(8);
        assert(!set[].empty);
        assert(set[].front == 8);
        assert(set[].back == 8);
    }
}
