/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */
module tanya.container.tests.hashtable;

import tanya.container.hashtable;
import tanya.test.stub;

@nogc nothrow pure @safe unittest
{
    import tanya.range.primitive : isForwardRange;
    static assert(is(HashTable!(string, int) a));
    static assert(is(const HashTable!(string, int)));
    static assert(isForwardRange!(HashTable!(string, int).Range));

    static assert(is(HashTable!(int, int, (ref const int) => size_t.init)));
    static assert(is(HashTable!(int, int, (int) => size_t.init)));
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

// Issue 53: https://github.com/caraus-ecms/tanya/issues/53
@nogc nothrow pure @safe unittest
{
    {
        HashTable!(uint, uint) hashTable;
        foreach (uint i; 0 .. 14)
        {
            hashTable[i + 1] = i;
        }
        assert(hashTable.length == 14);
    }
    {
        HashTable!(int, int) hashtable;

        hashtable[1194250162] = 3;
        hashtable[-1131293824] = 6;
        hashtable[838100082] = 9;

        hashtable.rehash(11);

        assert(hashtable[-1131293824] == 6);
    }
}

@nogc nothrow pure @safe unittest
{
    static struct String
    {
        bool opEquals(string) const @nogc nothrow pure @safe
        {
            return true;
        }

        bool opEquals(ref const string) const @nogc nothrow pure @safe
        {
            return true;
        }

        bool opEquals(String) const @nogc nothrow pure @safe
        {
            return true;
        }

        bool opEquals(ref const String) const @nogc nothrow pure @safe
        {
            return true;
        }

        size_t toHash() const @nogc nothrow pure @safe
        {
            return 0;
        }
    }
    static assert(is(typeof("asdf" in HashTable!(String, int)())));
    static assert(is(typeof(HashTable!(String, int)()["asdf"])));
}

// Can have non-copyable keys and elements
@nogc nothrow pure @safe unittest
{
    @NonCopyable @Hashable
    static struct S
    {
        mixin StructStub;
    }
    static assert(is(HashTable!(S, int)));
    static assert(is(HashTable!(int, S)));
    static assert(is(HashTable!(S, S)));
}
