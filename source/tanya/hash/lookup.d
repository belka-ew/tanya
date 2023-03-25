/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * Non-cryptographic, lookup hash functions.
 *
 * Copyright: Eugene Wissner 2018-2020.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 * Source: $(LINK2 https://github.com/caraus-ecms/tanya/blob/master/source/tanya/hash/lookup.d,
 *                 tanya/hash/lookup.d)
 */
module tanya.hash.lookup;

import std.traits : isScalarType;
import tanya.meta.trait;
import tanya.range.primitive;

private struct Hasher
{
    static if (size_t.sizeof == 4)
    {
        enum uint offsetBasis = 2166136261;
        enum uint prime = 16777619;
    }
    else static if (size_t.sizeof == 8)
    {
        enum ulong offsetBasis = 14695981039346656037UL;
        enum ulong prime = 1099511628211UL;
    }
    else static if (size_t.sizeof == 16)
    {
        enum size_t offsetBasis = (size_t(0x6c62272e07bb0142UL) << 64) + 0x62b821756295c58dUL;
        enum size_t prime = (size_t(1) << 88) + (1 << 8) + 0x3b;
    }
    else
    {
        static assert(false, "FNV requires at least 32-bit hash length");
    }

    size_t hash = offsetBasis;

    void opCall(T)(auto ref T key)
    {
        static if (is(typeof(key.toHash()) == size_t))
        {
            opCall(key.toHash()); // Combine user-defined hashes
        }
        else static if (isScalarType!T || isPointer!T)
        {
            // Treat as an array of words
            static if (T.sizeof % size_t.sizeof == 0
                    && T.alignof >= size_t.alignof)
                alias CastT = size_t;
            // (64-bit or 128-bit) Treat as an array of ints
            else static if (T.sizeof % uint.sizeof == 0
                    && T.alignof >= uint.alignof)
                alias CastT = uint;
            // Treat as an array of bytes
            else
                alias CastT = ubyte;
            add((() @trusted => (cast(const CastT*) &key)[0 .. T.sizeof / CastT.sizeof])());
        }
        else static if (isArray!T && isScalarType!(ElementType!T))
        {
            // Treat as an array of words
            static if (ElementType!T.sizeof % size_t.sizeof == 0
                    && ElementType!T.alignof >= size_t.alignof)
                alias CastT = size_t;
            // (64-bit or 128-bit) Treat as an array of ints
            else static if (ElementType!T.sizeof % uint.sizeof == 0
                    && ElementType!T.alignof >= uint.alignof)
                alias CastT = uint;
            // Treat as an array of bytes
            else
                alias CastT = ubyte;
            add(cast(const CastT[]) key);
        }
        else static if (is(T == typeof(null)))
        {
            add(key);
        }
        else static if (isInputRange!T && !isInfinite!T)
        {
            foreach (e; key)
            {
                opCall(e);
            }
        }
        else
        {
            static assert(false, "Hash function is not available");
        }
    }

    void add(scope const ubyte[] key) @nogc nothrow pure @safe
    {
        // FNV-1a
        foreach (c; key)
        {
            this.hash = (this.hash ^ c) * prime;
        }
    }

    void add(scope const size_t[] key) @nogc nothrow pure @safe
    {
        static if (size_t.sizeof == 4)
        {
            // Partial MurmurHash3_x86_32 (no finalization)
            enum uint c1 = 0xcc9e2d51;
            enum uint c2 = 0x1b873593;
            alias h1 = hash;
            foreach (x; key)
            {
                auto k1 = x * c1;
                k1 = (k1 << 15) | (k1 >> (32 - 15));
                k1 *= c2;

                h1 ^= k1;
                h1 = (h1 << 13) | (h1 >> (32 - 13));
                h1 = h1 * 5 + 0xe6546b64;
            }
        }
        else static if (size_t.sizeof == 8)
        {
            // Partial 64-bit MurmurHash64A (no finalization)
            alias h = hash;
            enum ulong m = 0xc6a4a7935bd1e995UL;
            foreach (x; key)
            {
                auto k = x * m;
                k ^= k >>> 47;
                k *= m;

                h ^= k;
                h *= m;
            }
        }
        else static if (size_t.sizeof == 16)
        {
            // Partial MurmurHash3_x64_128 (no finalization)
            // treating each size_t as a pair of ulong.
            ulong h1 = cast(ulong) hash;
            ulong h2 = cast(ulong) (hash >> 64);

            enum ulong c1 = 0x87c37b91114253d5UL;
            enum ulong c2 = 0x4cf5ad432745937fUL;

            foreach (x; key)
            {
                auto k1 = cast(ulong) x;
                auto k2 = cast(ulong) (x >> 64);

                k1 *= c1; k1 = (k1 << 32) | (k1 >> (64 - 31)); k1 *= c2; h1 ^= k1;
                h1 = (h1 << 27) | (h1 >> (64 - 27)); h1 += h2; h1 = h1*5+0x52dce729;
                k2 *= c2; k2 = (k2 << 33) | (k2 >> (64 - 33)); k2 *= c1; h2 ^= k2;
                h2 = (h2 << 31) | (h2 >> (64 - 31)); h2 += h1; h2 = h2*5+0x38495ab5;
            }

            hash = cast(size_t) h1 + ((cast(size_t) h2) << 64);
        }
        else
        {
            static assert(0, "Hash length must be either 32, 64, or 128 bits.");
        }
    }

    static if (size_t.sizeof != uint.sizeof)
    void add(scope const uint[] key) @nogc nothrow pure @trusted
    {
        static if (size_t.sizeof == 8)
        {
            // Partial 32-bit MurmurHash64B (no finalization)
            enum uint m = 0x5bd1e995;
            enum r = 24;

            uint h1 = cast(uint) hash;
            uint h2 = cast(uint) (hash >> 32);
            const(uint)* data = key.ptr;
            auto len = key.length;

            for (; len >= 2; data += 2, len -= 2)
            {
                uint k1 = data[0];
                k1 *= m; k1 ^= k1 >> r; k1 *= m;
                h1 *= m; h1 ^= k1;

                uint k2 = data[1];
                k2 *= m; k2 ^= k2 >> r; k2 *= m;
                h2 *= m; h2 ^= k2;
            }
            if (len)
            {
                uint k1 = data[0];
                k1 *= m; k1 ^= k1 >> r; k1 *= m;
                h1 *= m; h1 ^= k1;
            }
            hash = cast(ulong) h1 + ((cast(ulong) h2) << 32);
        }
        else static if (size_t.sizeof == 16)
        {
            // Partial MurmurHash3_x86_128 (no finalization)
            enum uint c1 = 0x239b961b;
            enum uint c2 = 0xab0e9789;
            enum uint c3 = 0x38b34ae5;
            enum uint c4 = 0xa1e38b93;

            uint h1 = cast(uint) hash;
            uint h2 = cast(uint) (hash >> 32);
            uint h3 = cast(uint) (hash >> 64);
            uint h4 = cast(uint) (hash >> 96);
            const(uint)* data = key.ptr;
            auto len = key.length;

            for (; len >= 4; data += 4, len -= 4)
            {
                uint k1 = data[0];
                uint k2 = data[1];
                uint k3 = data[2];
                uint k4 = data[3];

                h1 = (h1 << 19) | (h1 >> (32 - 19)); h1 += h2; h1 = h1*5+0x561ccd1b;
                k2 *= c2; k2 = (k2 << 16) | (k2 >> (32 - 16)); k2 *= c3; h2 ^= k2;
                h2 = (h2 << 17) | (h2 >> (32 - 17)); h2 += h3; h2 = h2*5+0x0bcaa747;
                k3 *= c3; k3 = (k3 << 17) | (k3 >> (32 - 17)); k3 *= c4; h3 ^= k3;
                h3 = (h3 << 15) | (h3 >> (32 - 15)); h3 += h4; h3 = h3*5+0x96cd1c35;
                k4 *= c4; k4 = (k4 << 18) | (k4 >> (32 - 18)); k4 *= c1; h4 ^= k4;
                h4 = (h4 << 13) | (h4 >> (32 - 13)); h4 += h1; h4 = h4*5+0x32ac3b17;
            }
            uint k1, k2, k3;
            switch (len) // 0, 1, 2, 3
            {
                case 3:
                    k3 = data[2];
                    k3 *= c3; k3 = (k3 << 17) | (k3 >> (32 - 17)); k3 *= c4; h3 ^= k3;
                    goto case;
                case 2:
                    k2 = data[1];
                    k2 *= c2; k2 = (k2 << 16) | (k2 >> (32 - 16)); k2 *= c3; h2 ^= k2;
                    goto case;
                case 1:
                    k1 = data[0];
                    k1 *= c1; k1 = (k1 << 15) | (k1 >> (32 - 15)); k1 *= c2; h1 ^= k1;
                    break;
            }
            hash = cast(size_t) h1 +
                   ((cast(size_t) h2) << 32) +
                   ((cast(size_t) h3) << 64) +
                   ((cast(size_t) h4) << 96);
        }
        else
        {
            static assert(0, "Hash length must be either 32, 64, or 128 bits.");
        }
    }
}

/**
 * Takes an argument of an arbitrary type $(D_PARAM T) and calculates the hash
 * value.
 *
 * Hash calculation is supported for all scalar types. Aggregate types, like
 * $(D_KEYWORD struct)s, should implement `toHash`-function:
 * ---
 * size_t toHash() const
 * {
 *  return hash;
 * }
 * ---
 *
 * For pointers and for scalar types implicitly convertible to `size_t` this
 * is an identity operation (i.e. the value is cast to `size_t` and returned
 * unaltered). Integer types wider than `size_t` are XOR folded down to
 * `size_t`. Other scalar types use an architecture-dependent hash function
 * based on their width and alignment.
 * If the type provides a `toHash`-function, only `toHash()` is called and its
 * result is returned.
 *
 * This function also accepts input ranges that contain hashable elements.
 * Individual values are combined then and the resulting hash is returned.
 *
 * Params:
 *  T   = Hashable type.
 *  key = Hashable value.
 *
 * Returns: Calculated hash value.
 *
 * See_Also: $(LINK http://www.isthe.com/chongo/tech/comp/fnv/).
 */
size_t hash(T)(auto ref T key)
{
    static if (is(typeof(key.toHash()) == size_t))
    {
        return key.toHash();
    }
    else static if ((isIntegral!T || isSomeChar!T || isBoolean!T)
            && T.sizeof <= size_t.sizeof)
    {
        return cast(size_t) key;
    }
    else static if (isIntegral!T && T.sizeof > size_t.sizeof)
    {
        return cast(size_t) (key ^ (key >>> (size_t.sizeof * 8)));
    }
    else static if (isPointer!T || is(T : typeof(null)))
    {
        return (() @trusted => cast(size_t) key)();
    }
    else
    {
        Hasher hasher;
        hasher(key);
        return hasher.hash;
    }
}

/**
 * Determines whether $(D_PARAM hasher) is hash function for $(D_PARAM T), i.e.
 * it is callable with a value of type $(D_PARAM T) and returns a
 * $(D_PSYMBOL size_t) value.
 *
 * Params:
 *  hasher = Hash function candidate.
 *  T      = Type to test the hash function with.
 *
 * Returns: $(D_KEYWORD true) if $(D_PARAM hasher) is a hash function for
 *          $(D_PARAM T), $(D_KEYWORD false) otherwise.
 */
template isHashFunction(alias hasher, T)
{
    private alias wrapper = (T x) => hasher(x);
    enum bool isHashFunction = is(typeof(wrapper(T.init)) == size_t);
}

///
@nogc nothrow pure @safe unittest
{
    static assert(isHashFunction!(hash, int));
}
