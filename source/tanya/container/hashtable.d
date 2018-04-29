/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * Hash table.
 *
 * Copyright: Eugene Wissner 2018.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 * Source: $(LINK2 https://github.com/caraus-ecms/tanya/blob/master/source/tanya/container/hashtable.d,
 *                 tanya/container/hashtable.d)
 */
module tanya.container.hashtable;

import tanya.container.array;
import tanya.container.entry;
import tanya.hash.lookup;
import tanya.memory;
import tanya.range.primitive;
import tanya.typecons;

/*struct Range(T)
{
    static if (is(T == const))
    {
        private alias Buckets = T.buckets.ConstRange;
        private alias Bucket = typeof(T.buckets[0]).ConstRange;
    }
    else
    {
        private alias Buckets = T.buckets.Range;
        private alias Bucket = typeof(T.buckets[0]).Range;
    }
    private alias E = ElementType!Bucket;

    private Buckets buckets;
    private Bucket bucket;

    private bool findNextBucket()
    {
        while (!this.buckets.empty)
        {
            if (!this.buckets.front.empty)
            {
                return true;
            }
            this.buckets.popFront();
        }
        return false;
    }

    private this(Buckets buckets)
    {
        this.buckets = buckets;
        this.bucket = findNextBucket() ? this.buckets.front[] : Bucket.init;
    }

    @property Range save()
    {
        return this;
    }

    @property bool empty() const
    {
        return this.buckets.empty;
    }

    @property ref inout(E) front() inout
    in
    {
        assert(!empty);
    }
    do
    {
        return this.bucket.front;
    }

    void popFront()
    in
    {
        assert(!empty);
    }
    do
    {
        this.bucket = findNextBucket() ? this.buckets.front[] : Bucket.init;
    }
}

@nogc nothrow pure @safe unittest
{
    static assert(is(HashTable!(string, int)));
    static assert(is(const HashTable!(string, int)));
    static assert(isForwardRange!(Range!(HashTable!(string, int))));
}*/

/**
 * Hash table.
 *
 * Params:
 *  Key    = Key type.
 *  Value  = Value type.
 *  hasher = Hash function for $(D_PARAM Key).
 */
struct HashTable(Key, Value, alias hasher = hash)
if (is(typeof(hasher(Key.init)) == size_t))
{
    /* Forward range for $(D_PSYMBOL HashTable).
    alias Range = .Range!HashTable;

    /// ditto
    alias ConstRange = .Range!(const HashTable);*/

    private HashArray!(hasher, Key, Value) data;
    private size_t length_;

    private alias Buckets = typeof(this.data).Buckets;

    /**
     * Constructs a new hash table.
     *
     * Params:
     *  size      = Initial, approximate hash table size.
     *  allocator = Allocator.
     *
     * Precondition: `allocator !is null`.
     */
    this(size_t size, shared Allocator allocator = defaultAllocator)
    in
    {
        assert(allocator !is null);
    }
    do
    {
        this.data = typeof(this.data)(Buckets(size, allocator));
    }

    /// ditto
    this(shared Allocator allocator)
    in
    {
        assert(allocator !is null);
    }
    do
    {
        this.data = typeof(this.data)(Buckets(allocator));
    }

    /**
     * Returns the number of elements in the container.
     *
     * Returns: The number of elements in the container.
     */
    @property size_t length() const
    {
        return this.length_;
    }

    /**
     * Tells whether the container contains any elements.
     *
     * Returns: Whether the container is empty.
     */
    @property bool empty() const
    {
        return this.length_ == 0;
    }

    /**
     * Removes all elements.
     */
    void clear()
    {
        this.data.array.clear();
        this.length_ = 0;
    }

    /**
     * Returns: Used allocator.
     *
     * Postcondition: $(D_INLINECODE allocator !is null)
     */
    @property shared(Allocator) allocator() const
    out (allocator)
    {
        assert(allocator !is null);
    }
    do
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

    /// The maximum number of buckets the container can have.
    enum size_t maxBucketCount = primes[$ - 1];

    /**
     * Inserts a new value at $(D_PARAM key) or reassigns the element if
     * $(D_PARAM key) already exists in the hash table.
     *
     * Params:
     *  key   = The key to insert the value at.
     *  value = The value to be inserted.
     *
     * Returns: Just inserted element.
     */
    ref Value opIndexAssign(Value value, Key key)
    {
        auto e = ((ref v) @trusted => &this.data.insert(v))(key);
        if (e.status != BucketStatus.used)
        {
            e.key = key;
            ++this.length_;
        }
        e.value = value;
        return e.value;
    }

    /**
     * Find the element with the key $(D_PARAM key).
     *
     * Params:
     *  key = The key to be find.
     *
     * Returns: The value associated with $(D_PARAM key).
     *
     * Precondition: Element with $(D_PARAM key) is in this hash table.
     */
    ref Value opIndex(Key key)
    {
        const code = this.data.locateBucket(key);

        for (auto range = this.data.array[code .. $]; !range.empty; range.popFront())
        {
            if (key == range.front.key)
            {
                return range.front.value;
            }
        }
        assert(false, "Range violation");
    }

    /**
     * Removes the element with the key $(D_PARAM key).
     *
     * The method returns the number of elements removed. Since
     * the hash table contains only unique keys, $(D_PARAM remove) always
     * returns `1` if an element with the $(D_PARAM key) was found, `0`
     * otherwise.
     *
     * Params:
     *  key = The key to be removed.
     *
     * Returns: Number of the removed elements.
     */
    size_t remove(Key key)
    {
        const code = this.data.locateBucket(key);

        for (auto range = this.data.array[code .. $]; !range.empty; range.popFront())
        {
            if (key == range.front.key)
            {
                range.front.status = BucketStatus.deleted;
                --this.length_;
                return 1;
            }
        }
        return 0;
    }

    /**
     * Looks for $(D_PARAM key) in this hash table.
     *
     * Params:
     *  key = The key to look for.
     *
     * Returns: $(D_KEYWORD true) if $(D_PARAM key) exists in the hash table,
     *          $(D_KEYWORD false) otherwise.
     */
    bool opBinaryRight(string op : "in")(Key key)
    {
        const code = this.data.locateBucket(key);

        foreach (ref const e; this.data.array[code .. $])
        {
            if (key == e.key)
            {
                return true;
            }
        }
        return false;
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
     *
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
    void rehash(size_t n)
    {
        this.data.rehash(n);
    }
}

@nogc nothrow pure @safe unittest
{
    auto dinos = HashTable!(string, int)(17);
    assert(dinos.empty);

    dinos["Euoplocephalus"] = 6;
    dinos["Triceratops"] = 7;
    dinos["Pachycephalosaurus"] = 6;
    dinos["Shantungosaurus"] = 15;
    dinos["Ornithominus"] = 4;
    dinos["Tyrannosaurus"] = 12;
    dinos["Deinonychus"] = 3;
    dinos["Iguanodon"] = 9;
    dinos["Stegosaurus"] = 6;
    dinos["Brachiosaurus"] = 25;

    assert(dinos.length == 10);
    assert(dinos["Iguanodon"] == 9);
    assert(dinos["Ornithominus"] == 4);
    assert(dinos["Stegosaurus"] == 6);
    assert(dinos["Euoplocephalus"] == 6);
    assert(dinos["Deinonychus"] == 3);
    assert(dinos["Tyrannosaurus"] == 12);
    assert(dinos["Pachycephalosaurus"] == 6);
    assert(dinos["Shantungosaurus"] == 15);
    assert(dinos["Triceratops"] == 7);
    assert(dinos["Brachiosaurus"] == 25);

    assert("Shantungosaurus" in dinos);
    assert("Ceratopsia" !in dinos);

    dinos.clear();
    assert(dinos.empty);
}
