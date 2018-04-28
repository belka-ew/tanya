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

    private Array!(Bucket!(Key, Value)) buckets;

    private size_t length_;

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
        this.buckets = typeof(this.buckets)(size, allocator);
    }

    /// ditto
    this(shared Allocator allocator)
    in
    {
        assert(allocator !is null);
    }
    do
    {
        this.buckets = typeof(this.buckets)(allocator);
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
        this.buckets.clear();
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
        return this.buckets.allocator;
    }

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
        const code = locateBucket(this.buckets, hasher(key));

        foreach (ref e; this.buckets[code .. $])
        {
            if (e == key)
            {
                return e.value = value;
            }
            else if (e.status != BucketStatus.used) // Insert the value.
            {
                ++this.length_;
                e.key = key;
                e.value = value;
                return e.value;
            }
        }
        ++this.length_;
        this.buckets.length = this.buckets.length + 1;
        this.buckets[$ - 1] = Bucket!(Key, Value)(key, value);
        return this.buckets[$ - 1].value;
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
        const code = locateBucket(this.buckets, hasher(key));

        for (auto range = this.buckets[code .. $]; !range.empty; range.popFront())
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
        const code = locateBucket(this.buckets, hasher(key));

        for (auto range = this.buckets[code .. $]; !range.empty; range.popFront())
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
        const code = locateBucket(this.buckets, hasher(key));

        foreach (ref const e; this.buckets[code .. $])
        {
            if (key == e.key)
            {
                return true;
            }
        }
        return false;
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
