/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * Non-cryptographic, lookup hash functions.
 *
 * Copyright: Eugene Wissner 2018.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 * Source: $(LINK2 https://github.com/caraus-ecms/tanya/blob/master/source/tanya/hash/lookup.d,
 *                 tanya/hash/lookup.d)
 */
module tanya.hash.lookup;

import tanya.meta.trait;

/**
 * FNV-1a (Fowler-Noll-Vo) hash function.
 *
 * See_Also: $(LINK http://www.isthe.com/chongo/tech/comp/fnv/).
 */
size_t fnv(const ubyte[] key) @nogc nothrow pure @safe
{
    static if (size_t.sizeof == 4)
    {
        enum uint offsetBasis = 2166136261;
        enum uint fnvPrime = 16777619;
    }
    else static if (size_t.sizeof == 8)
    {
        enum ulong offsetBasis = 14695981039346656037UL;
        enum ulong fnvPrime = 1099511628211UL;
    }
    else
    {
        static assert(false, "FNV requires at least 32-bit hash length");
    }

    size_t h = offsetBasis;

    foreach (c; key)
    {
        h = (h ^ c) * fnvPrime;
    }

    return h;
}

static if (size_t.sizeof == 4) @nogc nothrow pure @safe unittest
{
    assert(fnv(null) == 2166136261);

    ubyte[1] given = [0];
    assert(fnv(given) == 84696351);
}

static if (size_t.sizeof == 8) @nogc nothrow pure @safe unittest
{
    assert(fnv(null) == 14695981039346656037UL);

    ubyte[1] given = [0];
    assert(fnv(given) == (14695981039346656037UL * 1099511628211UL));
}

size_t hash(T)(auto ref const T key)
{
    static if (isScalarType!T)
    {
        return (() @trusted => fnv(cast(const ubyte[]) (&key)[0 .. T.sizeof]))();
    }
}
