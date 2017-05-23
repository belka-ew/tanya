/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * Hash table.
 *
 * Copyright: Eugene Wissner 2017.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 */
module tanya.container.hashtable;

import std.algorithm.comparison;
import std.traits;
import tanya.container.entry;
import tanya.memory;

private int compare(const(char)[] key1, const(char)[] key2)
{
    return cmp(key1, key2);
}

private int compare(K)(K key1, K key2)
    if (isIntegral!K)
{
    return cast(int) (key1 - key2);
}

struct Range(K, V)
{
    private HashEntry!(K, V)*[] table;
    private size_t begin, end;

    invariant
    {
        assert(this.begin <= this.end);
    }

    private this(HashEntry!(K, V)*[] table)
    {
        this.table = table;
    }

    @property bool empty() const
    {
        for (size_t i = this.begin; i < this.begin; ++i)
        {
            if (this.table[i] !is null)
            {
                return false;
            }
        }
        return true;
    }
}

struct HashTable(K, V)
{
    /**
     * Create a new hashtable.
     *
     * Params:
     *  size      = Minimum number of initial buckets.
     *  allocator = Allocator.
     */
    this(const size_t size, shared Allocator allocator = defaultAllocator)
    in
    {
        assert(size >= 1);
    }
    body
    {
        this(allocator);
        this.table = new HashEntry!(K, V)*[size];
    }

    /// Ditto.
    this(shared Allocator allocator)
    in
    {
        assert(allocator !is null);
    }
    body
    {
        this.allocator_ = allocator;
    }

    private size_t calculateHash(const(char)[] key)
    {
        size_t hashval;

        for (int i; hashval < size_t.max && i < key.length; ++i)
        {
            hashval = hashval << 8;
            hashval += key[i];
        }

        return hashval % this.table.length;
    }

    private size_t calculateHash()(K key)
        if (isIntegral!K)
    {
        return key % this.table.length;
    }

    /**
     * Retrieve a key-value pair from a hash table.
     */
    V opIndex(K key)
    {
        auto bin = calculateHash(key);
        auto pair = this.table[bin];

        while (pair !is null && compare(key, pair.pair[0]) > 0)
        {
            pair = pair.next;
        }

        // Did we actually find anything?
        if (pair is null || compare(key, pair.pair[0]) != 0)
        {
            return null;
        }
        else
        {
            return pair.pair[1];
        }
    }

    /**
     * Insert a key-value pair into a hash table.
     */
    bool insert(K key, V value)
    {
        HashEntry!(K, V)* last;
        auto bin = calculateHash(key);
        auto next = this.table[bin];

        while (next !is null && compare(key, next.pair[0]) > 0)
        {
            last = next;
            next = next.next;
        }

        // There's already a pair.
        if (next !is null && compare(key, next.pair[0]) == 0)
        {
            next.pair[1] = value;
            return false;
        }
        else // Nope, could't find it.  Time to grow a pair.
        {
            auto newpair = new HashEntry!(K, V)(key, value);

            // We're at the start of the linked list in this bin.
            if (next == this.table[bin])
            {
                newpair.next = next;
                this.table[bin] = newpair;
            }
            else if (next is null)
            {
                // We're at the end of the linked list in this bin.
                last.next = newpair;
            }
            else
            {
                // We're in the middle of the list.
                newpair.next = next;
                last.next = newpair;
            }
            return true;
        }
    }

    void opIndexAssign(V value, K key)
    {
        insert(key, value);
    }

    Range!(K, V) opIndex()
    {
        return typeof(return)(this.table);
    }

    @property bool empty() const
    {
        foreach (entry; this.table)
        {
            if (entry !is null)
            {
                return false;
            }
        }
        return true;
    }

    private HashEntry!(K, V)*[] table;

    mixin DefaultAllocator;
}

unittest
{
    auto ht = HashTable!(string, string)(65536);
    assert(ht.empty);

    ht["key1"] = "inky";
    ht["key2"] = "pinky";
    ht["key3"] = "blinky";
    ht["key4"] = "floyd";

    assert(!ht.empty);
    assert("inky" == ht["key1"]);
    assert("pinky" == ht["key2"]);
    assert("blinky" == ht["key3"]);
    assert("floyd" == ht["key4"]);
}
