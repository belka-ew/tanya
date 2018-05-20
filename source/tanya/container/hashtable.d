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
import tanya.meta.trait;
import tanya.meta.transform;

/**
 * Bidirectional range whose element type is a tuple of a key and the
 * respective value.
 *
 * Params:
 *  T = Type of the internal hash storage.
 */
struct Range(T)
{
    private alias KV = CopyConstness!(T, T.Bucket.KV);
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

    @property void popFront()
    in
    {
        assert(!empty);
        assert(this.dataRange.front.status == BucketStatus.used);
    }
    out
    {
        assert(empty || this.dataRange.back.status == BucketStatus.used);
    }
    do
    {
        do
        {
            this.dataRange.popFront();
        }
        while (!empty && dataRange.front.status != BucketStatus.used);
    }

    @property void popBack()
    in
    {
        assert(!empty);
        assert(this.dataRange.back.status == BucketStatus.used);
    }
    out
    {
        assert(empty || this.dataRange.back.status == BucketStatus.used);
    }
    do
    {
        do
        {
            this.dataRange.popBack();
        }
        while (!empty && dataRange.back.status != BucketStatus.used);
    }

    @property ref inout(KV) front() inout
    in
    {
        assert(!empty);
        assert(this.dataRange.front.status == BucketStatus.used);
    }
    do
    {
        return this.dataRange.front.kv;
    }

    @property ref inout(KV) back() inout
    in
    {
        assert(!empty);
        assert(this.dataRange.back.status == BucketStatus.used);
    }
    do
    {
        return this.dataRange.back.kv;
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
 * Hash table is a data structure that stores pairs of keys and values without
 * any particular order.
 *
 * This $(D_PSYMBOL HashTable) is implemented using closed hashing. Hash
 * collisions are resolved with linear probing.
 *
 * $(D_PARAM Key) should be hashable with $(D_PARAM hasher). $(D_PARAM hasher)
 * is a callable that accepts an argument of type $(D_PARAM Key) and returns a
 * hash value for it ($(D_KEYWORD size_t)).
 *
 * Params:
 *  Key    = Key type.
 *  Value  = Value type.
 *  hasher = Hash function for $(D_PARAM Key).
 */
struct HashTable(Key, Value, alias hasher = hash)
if (is(typeof(hasher(Key.init)) == size_t))
{
    private alias HashArray = .HashArray!(hasher, Key, Value);
    private alias Buckets = HashArray.Buckets;

    private HashArray data;

    /// Type of the key-value pair stored in the hash table.
    alias KeyValue = HashArray.Bucket.KV;

    /// The range types for $(D_PSYMBOL HashTable).
    alias Range = .Range!HashArray;

    /// ditto
    alias ConstRange = .Range!(const HashArray);

    invariant
    {
        assert(this.data.lengthIndex < primes.length);
        assert(this.data.array.length == 0
            || this.data.array.length == primes[this.data.lengthIndex]);
    }

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
    in
    {
        assert(allocator !is null);
    }
    do
    {
        this(allocator);
        this.data.rehash(n);
    }

    ///
    @nogc nothrow pure @safe unittest
    {
        auto hashTable = HashTable!(string, int)(5);
        assert(hashTable.capacity == 7);
    }

    /// ditto
    this(shared Allocator allocator)
    in
    {
        assert(allocator !is null);
    }
    do
    {
        this.data = HashArray(allocator);
    }

    /**
     * Initializes this $(D_PARAM HashTable) from another one.
     *
     * If $(D_PARAM init) is passed by reference, it will be copied.
     * If $(D_PARAM init) is passed by value, it will be moved.
     *
     * Params:
     *  S         = Source set type.
     *  init      = Source set.
     *  allocator = Allocator.
     */
    this(S)(ref S init, shared Allocator allocator = defaultAllocator)
    if (is(Unqual!S == HashTable))
    in
    {
        assert(allocator !is null);
    }
    do
    {
        this.data = HashArray(init.data, allocator);
    }

    /// ditto
    this(S)(S init, shared Allocator allocator = defaultAllocator)
    if (is(S == HashTable))
    in
    {
        assert(allocator !is null);
    }
    do
    {
        this.data.move(init.data, allocator);
    }

    /**
     * Assigns another hash table.
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
    if (is(Unqual!S == HashTable))
    {
        this.data = that.data;
        return this;
    }

    /// ditto
    ref typeof(this) opAssign(S)(S that) @trusted
    if (is(S == HashTable))
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
    out (allocator)
    {
        assert(allocator !is null);
    }
    do
    {
        return this.data.array.allocator;
    }

    /**
     * Maximum amount of elements this $(D_PSYMBOL HashTable) can hold without
     * resizing and rehashing. Note that it doesn't mean that the
     * $(D_PSYMBOL Set) will hold $(I exactly) $(D_PSYMBOL capacity) elements.
     * $(D_PSYMBOL capacity) tells the size of the container under a best-case
     * distribution of elements.
     *
     * Returns: $(D_PSYMBOL HashTable) capacity.
     */
    @property size_t capacity() const
    {
        return this.data.capacity;
    }

    ///
    @nogc nothrow pure @safe unittest
    {
        HashTable!(string, int) hashTable;
        assert(hashTable.capacity == 0);

        hashTable["eight"] = 8;
        assert(hashTable.capacity == 3);
    }

    /**
     * Returns the number of elements in the container.
     *
     * Returns: The number of elements in the container.
     */
    @property size_t length() const
    {
        return this.data.length;
    }

    ///
    @nogc nothrow pure @safe unittest
    {
        HashTable!(string, int) hashTable;
        assert(hashTable.length == 0);

        hashTable["eight"] = 8;
        assert(hashTable.length == 1);
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
        HashTable!(string, int) hashTable;
        assert(hashTable.empty);
        hashTable["five"] = 5;
        assert(!hashTable.empty);
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
        HashTable!(string, int) hashTable;
        hashTable["five"] = 5;
        assert(!hashTable.empty);
        hashTable.clear();
        assert(hashTable.empty);
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
        }
        e.kv.value = value;
        return e.kv.value;
    }

    ///
    @nogc nothrow pure @safe unittest
    {
        HashTable!(string, int) hashTable;
        assert("Pachycephalosaurus" !in hashTable);

        hashTable["Pachycephalosaurus"] = 6;
        assert(hashTable.length == 1);
        assert("Pachycephalosaurus" in hashTable);

        hashTable["Pachycephalosaurus"] = 6;
        assert(hashTable.length == 1);
        assert("Pachycephalosaurus" in hashTable);
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
                return range.front.kv.value;
            }
        }
        assert(false, "Range violation");
    }

    ///
    @nogc nothrow pure @safe unittest
    {
        HashTable!(string, int) hashTable;
        hashTable["Triceratops"] = 7;
        assert(hashTable["Triceratops"] == 7);
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
        return this.data.remove(key);
    }

    ///
    @nogc nothrow pure @safe unittest
    {
        HashTable!(string, int) hashTable;
        hashTable["Euoplocephalus"] = 6;

        assert("Euoplocephalus" in hashTable);
        assert(hashTable.remove("Euoplocephalus") == 1);
        assert(hashTable.remove("Euoplocephalus") == 0);
        assert("Euoplocephalus" !in hashTable);
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
    bool opBinaryRight(string op : "in")(auto ref inout(Key) key) inout
    {
        return key in this.data;
    }

    ///
    @nogc nothrow pure @safe unittest
    {
        HashTable!(string, int) hashTable;

        assert("Shantungosaurus" !in hashTable);
        hashTable["Shantungosaurus"] = 15;
        assert("Shantungosaurus" in hashTable);

        assert("Ceratopsia" !in hashTable);
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

    /**
     * Returns a bidirectional range whose element type is a tuple of a key and
     * the respective value.
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
        HashTable!(string, int) hashTable;
        assert(hashTable[].empty);

        hashTable["Iguanodon"] = 9;
        assert(!hashTable[].empty);
        assert(hashTable[].front == hashTable.KeyValue("Iguanodon", 9));
        assert(hashTable[].back == hashTable.KeyValue("Iguanodon", 9));
    }
}

@nogc nothrow pure @safe unittest
{
    auto dinos = HashTable!(string, int)(17);
    assert(dinos.empty);

    dinos["Ornithominus"] = 4;
    dinos["Tyrannosaurus"] = 12;
    dinos["Deinonychus"] = 3;
    dinos["Stegosaurus"] = 6;
    dinos["Brachiosaurus"] = 25;

    assert(dinos.length == 5);
    assert(dinos["Ornithominus"] == 4);
    assert(dinos["Stegosaurus"] == 6);
    assert(dinos["Deinonychus"] == 3);
    assert(dinos["Tyrannosaurus"] == 12);
    assert(dinos["Brachiosaurus"] == 25);

    dinos.clear();
    assert(dinos.empty);
}

@nogc nothrow pure @safe unittest
{
    import tanya.range.primitive : isForwardRange;
    static assert(is(HashTable!(string, int) a));
    static assert(is(const HashTable!(string, int)));
    static assert(isForwardRange!(HashTable!(string, int).Range));
}

// Constructs by reference
@nogc nothrow pure @safe unittest
{
    auto hashTable1 = HashTable!(string, int)(7);
    auto hashTable2 = HashTable!(string, int)(hashTable1);
    assert(hashTable1.length == hashTable2.length);
    assert(hashTable1.capacity == hashTable2.capacity);
}

// Constructs by value
@nogc nothrow pure @safe unittest
{
    auto hashTable = HashTable!(string, int)(HashTable!(string, int)(7));
    assert(hashTable.capacity == 7);
}

// Assigns by reference
@nogc nothrow pure @safe unittest
{
    auto hashTable1 = HashTable!(string, int)(7);
    HashTable!(string, int) hashTable2;
    hashTable1 = hashTable2;
    assert(hashTable1.length == hashTable2.length);
    assert(hashTable1.capacity == hashTable2.capacity);
}

// Assigns by value
@nogc nothrow pure @safe unittest
{
    HashTable!(string, int) hashTable;
    hashTable = HashTable!(string, int)(7);
    assert(hashTable.capacity == 7);
}

// Postblit copies
@nogc nothrow pure @safe unittest
{
    auto hashTable = HashTable!(string, int)(7);
    void testFunc(HashTable!(string, int) hashTable)
    {
        assert(hashTable.capacity == 7);
    }
    testFunc(hashTable);
}
