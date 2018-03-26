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
import tanya.range.primitive;

private struct FNV
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
            (() @trusted => add((cast(const ubyte*) &key)[0 .. T.sizeof]))();
        }
        else static if (isArray!T && isScalarType!(ElementType!T))
        {
            add(cast(const ubyte[]) key);
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

    void add(const ubyte[] key) @nogc nothrow pure @safe
    {
        foreach (c; key)
        {
            this.hash = (this.hash ^ c) * prime;
        }
    }
}

/**
 * Takes an a argument of an arbitrary type $(D_PARAM T) and calculates the hash value.
 *
 * Hash calculation is supported for all scalar types. Aggregate types, like
 *$(D_KEYWORD struct)s should implement `toHash`-function:
 * ---
 * size_t toHash() const
 * {
 *  return hash;
 * }
 * ---
 *
 * For scalar types FNV-1a (Fowler-Noll-Vo) hash function is used internally.
 * If the type provides a `toHash`-function, only `toHash()` is called and its
 * result is returned.
 *
 * This function also accepts input ranges that contain hashable elements.
 * Individual values are combined then and the resulting hash is returned.
 *
 * Params:
 *  T = Hashable type.
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
    else
    {
        FNV fnv;
        fnv(key);
        return fnv.hash;
    }
}

version (unittest)
{
    enum string r10(string x) = x ~ x ~ x ~ x ~ x ~ x ~ x ~ x ~ x ~ x;
    enum string r100(string x) = r10!x ~ r10!x ~ r10!x ~ r10!x ~ r10!x
                               ~ r10!x ~ r10!x ~ r10!x ~ r10!x ~ r10!x;
    enum string r500(string x) = r100!x ~ r100!x ~ r100!x ~ r100!x ~ r100!x;

    private struct ToHash
    {
        size_t toHash() const @nogc nothrow pure @safe
        {
            return 0;
        }
    }

    private struct HashRange
    {
        string fo = "fo";

        @property ubyte front() const @nogc nothrow pure @safe
        {
            return this.fo[0];
        }

        void popFront() @nogc nothrow pure @safe
        {
            this.fo = this.fo[1 .. $];
        }

        @property bool empty() const @nogc nothrow pure @safe
        {
            return this.fo.length == 0;
        }
    }

    private struct ToHashRange
    {
        bool empty_;

        @property ToHash front() const @nogc nothrow pure @safe
        {
            return ToHash();
        }

        void popFront() @nogc nothrow pure @safe
        {
            this.empty_ = true;
        }

         @property bool empty() const @nogc nothrow pure @safe
         {
             return this.empty_;
         }
    }
}

// Tests that work for any hash size
@nogc nothrow pure @safe unittest
{
    assert(hash(null) == FNV.offsetBasis);
    assert(hash(ToHash()) == 0U);
}

static if (size_t.sizeof == 4) @nogc nothrow pure @safe unittest
{
    assert(hash('a') == 0xe40c292cU);
    assert(hash(HashRange()) == 0x6222e842U);
    assert(hash(ToHashRange()) == 1268118805U);
}
static if (size_t.sizeof == 8) @nogc nothrow pure @safe unittest
{
    assert(hash('a') == 0xaf63dc4c8601ec8cUL);
    assert(hash(HashRange()) == 0x08985907b541d342UL);
    assert(hash(ToHashRange()) == 12161962213042174405UL);
}

static if (size_t.sizeof == 4) @nogc nothrow pure @system unittest
{
    assert(hash(cast(void*) 0x6e6f6863) == 0xac297727U);
}
static if (size_t.sizeof == 8) @nogc nothrow pure @system unittest
{
    assert(hash(cast(void*) 0x77206f676e6f6863) == 0xd1edd10b507344d0UL);
}

/*
 * These are official FNV-1a test vectors and they are in the public domain.
 */
// FNV-1a 32 bit test vectors
static if (size_t.sizeof == 4) @nogc nothrow pure @safe unittest
{
    assert(hash("") == 0x811c9dc5U);
    assert(hash("a") == 0xe40c292cU);
    assert(hash("b") == 0xe70c2de5U);
    assert(hash("c") == 0xe60c2c52U);
    assert(hash("d") == 0xe10c2473U);
    assert(hash("e") == 0xe00c22e0U);
    assert(hash("f") == 0xe30c2799U);
    assert(hash("fo") == 0x6222e842U);
    assert(hash("foo") == 0xa9f37ed7U);
    assert(hash("foob") == 0x3f5076efU);
    assert(hash("fooba") == 0x39aaa18aU);
    assert(hash("foobar") == 0xbf9cf968U);
    assert(hash("\0") == 0x050c5d1fU);
    assert(hash("a\0") == 0x2b24d044U);
    assert(hash("b\0") == 0x9d2c3f7fU);
    assert(hash("c\0") == 0x7729c516U);
    assert(hash("d\0") == 0xb91d6109U);
    assert(hash("e\0") == 0x931ae6a0U);
    assert(hash("f\0") == 0x052255dbU);
    assert(hash("fo\0") == 0xbef39fe6U);
    assert(hash("foo\0") == 0x6150ac75U);
    assert(hash("foob\0") == 0x9aab3a3dU);
    assert(hash("fooba\0") == 0x519c4c3eU);
    assert(hash("foobar\0") == 0x0c1c9eb8U);
    assert(hash("ch") == 0x5f299f4eU);
    assert(hash("cho") == 0xef8580f3U);
    assert(hash("chon") == 0xac297727U);
    assert(hash("chong") == 0x4546b9c0U);
    assert(hash("chongo") == 0xbd564e7dU);
    assert(hash("chongo ") == 0x6bdd5c67U);
    assert(hash("chongo w") == 0xdd77ed30U);
    assert(hash("chongo wa") == 0xf4ca9683U);
    assert(hash("chongo was") == 0x4aeb9bd0U);
    assert(hash("chongo was ") == 0xe0e67ad0U);
    assert(hash("chongo was h") == 0xc2d32fa8U);
    assert(hash("chongo was he") == 0x7f743fb7U);
    assert(hash("chongo was her") == 0x6900631fU);
    assert(hash("chongo was here") == 0xc59c990eU);
    assert(hash("chongo was here!") == 0x448524fdU);
    assert(hash("chongo was here!\n") == 0xd49930d5U);
    assert(hash("ch\0") == 0x1c85c7caU);
    assert(hash("cho\0") == 0x0229fe89U);
    assert(hash("chon\0") == 0x2c469265U);
    assert(hash("chong\0") == 0xce566940U);
    assert(hash("chongo\0") == 0x8bdd8ec7U);
    assert(hash("chongo \0") == 0x34787625U);
    assert(hash("chongo w\0") == 0xd3ca6290U);
    assert(hash("chongo wa\0") == 0xddeaf039U);
    assert(hash("chongo was\0") == 0xc0e64870U);
    assert(hash("chongo was \0") == 0xdad35570U);
    assert(hash("chongo was h\0") == 0x5a740578U);
    assert(hash("chongo was he\0") == 0x5b004d15U);
    assert(hash("chongo was her\0") == 0x6a9c09cdU);
    assert(hash("chongo was here\0") == 0x2384f10aU);
    assert(hash("chongo was here!\0") == 0xda993a47U);
    assert(hash("chongo was here!\n\0") == 0x8227df4fU);
    assert(hash("cu") == 0x4c298165U);
    assert(hash("cur") == 0xfc563735U);
    assert(hash("curd") == 0x8cb91483U);
    assert(hash("curds") == 0x775bf5d0U);
    assert(hash("curds ") == 0xd5c428d0U);
    assert(hash("curds a") == 0x34cc0ea3U);
    assert(hash("curds an") == 0xea3b4cb7U);
    assert(hash("curds and") == 0x8e59f029U);
    assert(hash("curds and ") == 0x2094de2bU);
    assert(hash("curds and w") == 0xa65a0ad4U);
    assert(hash("curds and wh") == 0x9bbee5f4U);
    assert(hash("curds and whe") == 0xbe836343U);
    assert(hash("curds and whey") == 0x22d5344eU);
    assert(hash("curds and whey\n") == 0x19a1470cU);
    assert(hash("cu\0") == 0x4a56b1ffU);
    assert(hash("cur\0") == 0x70b8e86fU);
    assert(hash("curd\0") == 0x0a5b4a39U);
    assert(hash("curds\0") == 0xb5c3f670U);
    assert(hash("curds \0") == 0x53cc3f70U);
    assert(hash("curds a\0") == 0xc03b0a99U);
    assert(hash("curds an\0") == 0x7259c415U);
    assert(hash("curds and\0") == 0x4095108bU);
    assert(hash("curds and \0") == 0x7559bdb1U);
    assert(hash("curds and w\0") == 0xb3bf0bbcU);
    assert(hash("curds and wh\0") == 0x2183ff1cU);
    assert(hash("curds and whe\0") == 0x2bd54279U);
    assert(hash("curds and whey\0") == 0x23a156caU);
    assert(hash("curds and whey\n\0") == 0x64e2d7e4U);
    assert(hash("hi") == 0x683af69aU);
    assert(hash("hi\0") == 0xaed2346eU);
    assert(hash("hello") == 0x4f9f2cabU);
    assert(hash("hello\0") == 0x02935131U);
    assert(hash("\xff\x00\x00\x01") == 0xc48fb86dU);
    assert(hash("\x01\x00\x00\xff") == 0x2269f369U);
    assert(hash("\xff\x00\x00\x02") == 0xc18fb3b4U);
    assert(hash("\x02\x00\x00\xff") == 0x50ef1236U);
    assert(hash("\xff\x00\x00\x03") == 0xc28fb547U);
    assert(hash("\x03\x00\x00\xff") == 0x96c3bf47U);
    assert(hash("\xff\x00\x00\x04") == 0xbf8fb08eU);
    assert(hash("\x04\x00\x00\xff") == 0xf3e4d49cU);
    assert(hash("\x40\x51\x4e\x44") == 0x32179058U);
    assert(hash("\x44\x4e\x51\x40") == 0x280bfee6U);
    assert(hash("\x40\x51\x4e\x4a") == 0x30178d32U);
    assert(hash("\x4a\x4e\x51\x40") == 0x21addaf8U);
    assert(hash("\x40\x51\x4e\x54") == 0x4217a988U);
    assert(hash("\x54\x4e\x51\x40") == 0x772633d6U);
    assert(hash("127.0.0.1") == 0x08a3d11eU);
    assert(hash("127.0.0.1\0") == 0xb7e2323aU);
    assert(hash("127.0.0.2") == 0x07a3cf8bU);
    assert(hash("127.0.0.2\0") == 0x91dfb7d1U);
    assert(hash("127.0.0.3") == 0x06a3cdf8U);
    assert(hash("127.0.0.3\0") == 0x6bdd3d68U);
    assert(hash("64.81.78.68") == 0x1d5636a7U);
    assert(hash("64.81.78.68\0") == 0xd5b808e5U);
    assert(hash("64.81.78.74") == 0x1353e852U);
    assert(hash("64.81.78.74\0") == 0xbf16b916U);
    assert(hash("64.81.78.84") == 0xa55b89edU);
    assert(hash("64.81.78.84\0") == 0x3c1a2017U);
    assert(hash("feedface") == 0x0588b13cU);
    assert(hash("feedface\0") == 0xf22f0174U);
    assert(hash("feedfacedaffdeed") == 0xe83641e1U);
    assert(hash("feedfacedaffdeed\0") == 0x6e69b533U);
    assert(hash("feedfacedeadbeef") == 0xf1760448U);
    assert(hash("feedfacedeadbeef\0") == 0x64c8bd58U);
    assert(hash("line 1\nline 2\nline 3") == 0x97b4ea23U);
    assert(hash("chongo <Landon Curt Noll> /\\../\\") == 0x9a4e92e6U);
    assert(hash("chongo <Landon Curt Noll> /\\../\\\0") == 0xcfb14012U);
    assert(hash("chongo (Landon Curt Noll) /\\../\\") == 0xf01b2511U);
    assert(hash("chongo (Landon Curt Noll) /\\../\\\0") == 0x0bbb59c3U);
    assert(hash("http://antwrp.gsfc.nasa.gov/apod/astropix.html") == 0xce524afaU);
    assert(hash("http://en.wikipedia.org/wiki/Fowler_Noll_Vo_hash") == 0xdd16ef45U);
    assert(hash("http://epod.usra.edu/") == 0x60648bb3U);
    assert(hash("http://exoplanet.eu/") == 0x7fa4bcfcU);
    assert(hash("http://hvo.wr.usgs.gov/cam3/") == 0x5053ae17U);
    assert(hash("http://hvo.wr.usgs.gov/cams/HMcam/") == 0xc9302890U);
    assert(hash("http://hvo.wr.usgs.gov/kilauea/update/deformation.html") == 0x956ded32U);
    assert(hash("http://hvo.wr.usgs.gov/kilauea/update/images.html") == 0x9136db84U);
    assert(hash("http://hvo.wr.usgs.gov/kilauea/update/maps.html") == 0xdf9d3323U);
    assert(hash("http://hvo.wr.usgs.gov/volcanowatch/current_issue.html") == 0x32bb6cd0U);
    assert(hash("http://neo.jpl.nasa.gov/risk/") == 0xc8f8385bU);
    assert(hash("http://norvig.com/21-days.html") == 0xeb08bfbaU);
    assert(hash("http://primes.utm.edu/curios/home.php") == 0x62cc8e3dU);
    assert(hash("http://slashdot.org/") == 0xc3e20f5cU);
    assert(hash("http://tux.wr.usgs.gov/Maps/155.25-19.5.html") == 0x39e97f17U);
    assert(hash("http://volcano.wr.usgs.gov/kilaueastatus.php") == 0x7837b203U);
    assert(hash("http://www.avo.alaska.edu/activity/Redoubt.php") == 0x319e877bU);
    assert(hash("http://www.dilbert.com/fast/") == 0xd3e63f89U);
    assert(hash("http://www.fourmilab.ch/gravitation/orbits/") == 0x29b50b38U);
    assert(hash("http://www.fpoa.net/") == 0x5ed678b8U);
    assert(hash("http://www.ioccc.org/index.html") == 0xb0d5b793U);
    assert(hash("http://www.isthe.com/cgi-bin/number.cgi") == 0x52450be5U);
    assert(hash("http://www.isthe.com/chongo/bio.html") == 0xfa72d767U);
    assert(hash("http://www.isthe.com/chongo/index.html") == 0x95066709U);
    assert(hash("http://www.isthe.com/chongo/src/calc/lucas-calc") == 0x7f52e123U);
    assert(hash("http://www.isthe.com/chongo/tech/astro/venus2004.html") == 0x76966481U);
    assert(hash("http://www.isthe.com/chongo/tech/astro/vita.html") == 0x063258b0U);
    assert(hash("http://www.isthe.com/chongo/tech/comp/c/expert.html") == 0x2ded6e8aU);
    assert(hash("http://www.isthe.com/chongo/tech/comp/calc/index.html") == 0xb07d7c52U);
    assert(hash("http://www.isthe.com/chongo/tech/comp/fnv/index.html") == 0xd0c71b71U);
    assert(hash("http://www.isthe.com/chongo/tech/math/number/howhigh.html") == 0xf684f1bdU);
    assert(hash("http://www.isthe.com/chongo/tech/math/number/number.html") == 0x868ecfa8U);
    assert(hash("http://www.isthe.com/chongo/tech/math/prime/mersenne.html") == 0xf794f684U);
    assert(hash("http://www.isthe.com/chongo/tech/math/prime/mersenne.html#largest") == 0xd19701c3U);
    assert(hash("http://www.lavarnd.org/cgi-bin/corpspeak.cgi") == 0x346e171eU);
    assert(hash("http://www.lavarnd.org/cgi-bin/haiku.cgi") == 0x91f8f676U);
    assert(hash("http://www.lavarnd.org/cgi-bin/rand-none.cgi") == 0x0bf58848U);
    assert(hash("http://www.lavarnd.org/cgi-bin/randdist.cgi") == 0x6317b6d1U);
    assert(hash("http://www.lavarnd.org/index.html") == 0xafad4c54U);
    assert(hash("http://www.lavarnd.org/what/nist-test.html") == 0x0f25681eU);
    assert(hash("http://www.macosxhints.com/") == 0x91b18d49U);
    assert(hash("http://www.mellis.com/") == 0x7d61c12eU);
    assert(hash("http://www.nature.nps.gov/air/webcams/parks/havoso2alert/havoalert.cfm") == 0x5147d25cU);
    assert(hash("http://www.nature.nps.gov/air/webcams/parks/havoso2alert/timelines_24.cfm") == 0x9a8b6805U);
    assert(hash("http://www.paulnoll.com/") == 0x4cd2a447U);
    assert(hash("http://www.pepysdiary.com/") == 0x1e549b14U);
    assert(hash("http://www.sciencenews.org/index/home/activity/view") == 0x2fe1b574U);
    assert(hash("http://www.skyandtelescope.com/") == 0xcf0cd31eU);
    assert(hash("http://www.sput.nl/~rob/sirius.html") == 0x6c471669U);
    assert(hash("http://www.systemexperts.com/") == 0x0e5eef1eU);
    assert(hash("http://www.tq-international.com/phpBB3/index.php") == 0x2bed3602U);
    assert(hash("http://www.travelquesttours.com/index.htm") == 0xb26249e0U);
    assert(hash("http://www.wunderground.com/global/stations/89606.html") == 0x2c9b86a4U);
    assert(hash(r10!"21701") == 0xe415e2bbU);
    assert(hash(r10!"M21701") == 0x18a98d1dU);
    assert(hash(r10!"2^21701-1") == 0xb7df8b7bU);
    assert(hash(r10!"\x54\xc5") == 0x241e9075U);
    assert(hash(r10!"\xc5\x54") == 0x063f70ddU);
    assert(hash(r10!"23209") == 0x0295aed9U);
    assert(hash(r10!"M23209") == 0x56a7f781U);
    assert(hash(r10!"2^23209-1") == 0x253bc645U);
    assert(hash(r10!"\x5a\xa9") == 0x46610921U);
    assert(hash(r10!"\xa9\x5a") == 0x7c1577f9U);
    assert(hash(r10!"391581216093") == 0x512b2851U);
    assert(hash(r10!"391581*2^216093-1") == 0x76823999U);
    assert(hash(r10!"\x05\xf9\x9d\x03\x4c\x81") == 0xc0586935U);
    assert(hash(r10!"FEDCBA9876543210") == 0xf3415c85U);
    assert(hash(r10!"\xfe\xdc\xba\x98\x76\x54\x32\x10") == 0x0ae4ff65U);
    assert(hash(r10!"EFCDAB8967452301") == 0x58b79725U);
    assert(hash(r10!"\xef\xcd\xab\x89\x67\x45\x23\x01") == 0xdea43aa5U);
    assert(hash(r10!"0123456789ABCDEF") == 0x2bb3be35U);
    assert(hash(r10!"\x01\x23\x45\x67\x89\xab\xcd\xef") == 0xea777a45U);
    assert(hash(r10!"1032547698BADCFE") == 0x8f21c305U);
    assert(hash(r10!"\x10\x32\x54\x76\x98\xba\xdc\xfe") == 0x5c9d0865U);
    assert(hash(r500!"\x00") == 0xfa823dd5U);
    assert(hash(r500!"\x07") == 0x21a27271U);
    assert(hash(r500!"~") == 0x83c5c6d5U);
    assert(hash(r500!"\x7f") == 0x813b0881U);
}

// FNV-1a 64 bit test vectors
static if (size_t.sizeof == 8) @nogc nothrow pure @safe unittest
{
    assert(hash("") == 0xcbf29ce484222325UL);
    assert(hash("a") == 0xaf63dc4c8601ec8cUL);
    assert(hash("b") == 0xaf63df4c8601f1a5UL);
    assert(hash("c") == 0xaf63de4c8601eff2UL);
    assert(hash("d") == 0xaf63d94c8601e773UL);
    assert(hash("e") == 0xaf63d84c8601e5c0UL);
    assert(hash("f") == 0xaf63db4c8601ead9UL);
    assert(hash("fo") == 0x08985907b541d342UL);
    assert(hash("foo") == 0xdcb27518fed9d577UL);
    assert(hash("foob") == 0xdd120e790c2512afUL);
    assert(hash("fooba") == 0xcac165afa2fef40aUL);
    assert(hash("foobar") == 0x85944171f73967e8UL);
    assert(hash("\0") == 0xaf63bd4c8601b7dfUL);
    assert(hash("a\0") == 0x089be207b544f1e4UL);
    assert(hash("b\0") == 0x08a61407b54d9b5fUL);
    assert(hash("c\0") == 0x08a2ae07b54ab836UL);
    assert(hash("d\0") == 0x0891b007b53c4869UL);
    assert(hash("e\0") == 0x088e4a07b5396540UL);
    assert(hash("f\0") == 0x08987c07b5420ebbUL);
    assert(hash("fo\0") == 0xdcb28a18fed9f926UL);
    assert(hash("foo\0") == 0xdd1270790c25b935UL);
    assert(hash("foob\0") == 0xcac146afa2febf5dUL);
    assert(hash("fooba\0") == 0x8593d371f738acfeUL);
    assert(hash("foobar\0") == 0x34531ca7168b8f38UL);
    assert(hash("ch") == 0x08a25607b54a22aeUL);
    assert(hash("cho") == 0xf5faf0190cf90df3UL);
    assert(hash("chon") == 0xf27397910b3221c7UL);
    assert(hash("chong") == 0x2c8c2b76062f22e0UL);
    assert(hash("chongo") == 0xe150688c8217b8fdUL);
    assert(hash("chongo ") == 0xf35a83c10e4f1f87UL);
    assert(hash("chongo w") == 0xd1edd10b507344d0UL);
    assert(hash("chongo wa") == 0x2a5ee739b3ddb8c3UL);
    assert(hash("chongo was") == 0xdcfb970ca1c0d310UL);
    assert(hash("chongo was ") == 0x4054da76daa6da90UL);
    assert(hash("chongo was h") == 0xf70a2ff589861368UL);
    assert(hash("chongo was he") == 0x4c628b38aed25f17UL);
    assert(hash("chongo was her") == 0x9dd1f6510f78189fUL);
    assert(hash("chongo was here") == 0xa3de85bd491270ceUL);
    assert(hash("chongo was here!") == 0x858e2fa32a55e61dUL);
    assert(hash("chongo was here!\n") == 0x46810940eff5f915UL);
    assert(hash("ch\0") == 0xf5fadd190cf8edaaUL);
    assert(hash("cho\0") == 0xf273ed910b32b3e9UL);
    assert(hash("chon\0") == 0x2c8c5276062f6525UL);
    assert(hash("chong\0") == 0xe150b98c821842a0UL);
    assert(hash("chongo\0") == 0xf35aa3c10e4f55e7UL);
    assert(hash("chongo \0") == 0xd1ed680b50729265UL);
    assert(hash("chongo w\0") == 0x2a5f0639b3dded70UL);
    assert(hash("chongo wa\0") == 0xdcfbaa0ca1c0f359UL);
    assert(hash("chongo was\0") == 0x4054ba76daa6a430UL);
    assert(hash("chongo was \0") == 0xf709c7f5898562b0UL);
    assert(hash("chongo was h\0") == 0x4c62e638aed2f9b8UL);
    assert(hash("chongo was he\0") == 0x9dd1a8510f779415UL);
    assert(hash("chongo was her\0") == 0xa3de2abd4911d62dUL);
    assert(hash("chongo was here\0") == 0x858e0ea32a55ae0aUL);
    assert(hash("chongo was here!\0") == 0x46810f40eff60347UL);
    assert(hash("chongo was here!\n\0") == 0xc33bce57bef63eafUL);
    assert(hash("cu") == 0x08a24307b54a0265UL);
    assert(hash("cur") == 0xf5b9fd190cc18d15UL);
    assert(hash("curd") == 0x4c968290ace35703UL);
    assert(hash("curds") == 0x07174bd5c64d9350UL);
    assert(hash("curds ") == 0x5a294c3ff5d18750UL);
    assert(hash("curds a") == 0x05b3c1aeb308b843UL);
    assert(hash("curds an") == 0xb92a48da37d0f477UL);
    assert(hash("curds and") == 0x73cdddccd80ebc49UL);
    assert(hash("curds and ") == 0xd58c4c13210a266bUL);
    assert(hash("curds and w") == 0xe78b6081243ec194UL);
    assert(hash("curds and wh") == 0xb096f77096a39f34UL);
    assert(hash("curds and whe") == 0xb425c54ff807b6a3UL);
    assert(hash("curds and whey") == 0x23e520e2751bb46eUL);
    assert(hash("curds and whey\n") == 0x1a0b44ccfe1385ecUL);
    assert(hash("cu\0") == 0xf5ba4b190cc2119fUL);
    assert(hash("cur\0") == 0x4c962690ace2baafUL);
    assert(hash("curd\0") == 0x0716ded5c64cda19UL);
    assert(hash("curds\0") == 0x5a292c3ff5d150f0UL);
    assert(hash("curds \0") == 0x05b3e0aeb308ecf0UL);
    assert(hash("curds a\0") == 0xb92a5eda37d119d9UL);
    assert(hash("curds an\0") == 0x73ce41ccd80f6635UL);
    assert(hash("curds and\0") == 0xd58c2c132109f00bUL);
    assert(hash("curds and \0") == 0xe78baf81243f47d1UL);
    assert(hash("curds and w\0") == 0xb0968f7096a2ee7cUL);
    assert(hash("curds and wh\0") == 0xb425a84ff807855cUL);
    assert(hash("curds and whe\0") == 0x23e4e9e2751b56f9UL);
    assert(hash("curds and whey\0") == 0x1a0b4eccfe1396eaUL);
    assert(hash("curds and whey\n\0") == 0x54abd453bb2c9004UL);
    assert(hash("hi") == 0x08ba5f07b55ec3daUL);
    assert(hash("hi\0") == 0x337354193006cb6eUL);
    assert(hash("hello") == 0xa430d84680aabd0bUL);
    assert(hash("hello\0") == 0xa9bc8acca21f39b1UL);
    assert(hash("\xff\x00\x00\x01") == 0x6961196491cc682dUL);
    assert(hash("\x01\x00\x00\xff") == 0xad2bb1774799dfe9UL);
    assert(hash("\xff\x00\x00\x02") == 0x6961166491cc6314UL);
    assert(hash("\x02\x00\x00\xff") == 0x8d1bb3904a3b1236UL);
    assert(hash("\xff\x00\x00\x03") == 0x6961176491cc64c7UL);
    assert(hash("\x03\x00\x00\xff") == 0xed205d87f40434c7UL);
    assert(hash("\xff\x00\x00\x04") == 0x6961146491cc5faeUL);
    assert(hash("\x04\x00\x00\xff") == 0xcd3baf5e44f8ad9cUL);
    assert(hash("\x40\x51\x4e\x44") == 0xe3b36596127cd6d8UL);
    assert(hash("\x44\x4e\x51\x40") == 0xf77f1072c8e8a646UL);
    assert(hash("\x40\x51\x4e\x4a") == 0xe3b36396127cd372UL);
    assert(hash("\x4a\x4e\x51\x40") == 0x6067dce9932ad458UL);
    assert(hash("\x40\x51\x4e\x54") == 0xe3b37596127cf208UL);
    assert(hash("\x54\x4e\x51\x40") == 0x4b7b10fa9fe83936UL);
    assert(hash("127.0.0.1") == 0xaabafe7104d914beUL);
    assert(hash("127.0.0.1\0") == 0xf4d3180b3cde3edaUL);
    assert(hash("127.0.0.2") == 0xaabafd7104d9130bUL);
    assert(hash("127.0.0.2\0") == 0xf4cfb20b3cdb5bb1UL);
    assert(hash("127.0.0.3") == 0xaabafc7104d91158UL);
    assert(hash("127.0.0.3\0") == 0xf4cc4c0b3cd87888UL);
    assert(hash("64.81.78.68") == 0xe729bac5d2a8d3a7UL);
    assert(hash("64.81.78.68\0") == 0x74bc0524f4dfa4c5UL);
    assert(hash("64.81.78.74") == 0xe72630c5d2a5b352UL);
    assert(hash("64.81.78.74\0") == 0x6b983224ef8fb456UL);
    assert(hash("64.81.78.84") == 0xe73042c5d2ae266dUL);
    assert(hash("64.81.78.84\0") == 0x8527e324fdeb4b37UL);
    assert(hash("feedface") == 0x0a83c86fee952abcUL);
    assert(hash("feedface\0") == 0x7318523267779d74UL);
    assert(hash("feedfacedaffdeed") == 0x3e66d3d56b8caca1UL);
    assert(hash("feedfacedaffdeed\0") == 0x956694a5c0095593UL);
    assert(hash("feedfacedeadbeef") == 0xcac54572bb1a6fc8UL);
    assert(hash("feedfacedeadbeef\0") == 0xa7a4c9f3edebf0d8UL);
    assert(hash("line 1\nline 2\nline 3") == 0x7829851fac17b143UL);
    assert(hash("chongo <Landon Curt Noll> /\\../\\") == 0x2c8f4c9af81bcf06UL);
    assert(hash("chongo <Landon Curt Noll> /\\../\\\0") == 0xd34e31539740c732UL);
    assert(hash("chongo (Landon Curt Noll) /\\../\\") == 0x3605a2ac253d2db1UL);
    assert(hash("chongo (Landon Curt Noll) /\\../\\\0") == 0x08c11b8346f4a3c3UL);
    assert(hash("http://antwrp.gsfc.nasa.gov/apod/astropix.html") == 0x6be396289ce8a6daUL);
    assert(hash("http://en.wikipedia.org/wiki/Fowler_Noll_Vo_hash") == 0xd9b957fb7fe794c5UL);
    assert(hash("http://epod.usra.edu/") == 0x05be33da04560a93UL);
    assert(hash("http://exoplanet.eu/") == 0x0957f1577ba9747cUL);
    assert(hash("http://hvo.wr.usgs.gov/cam3/") == 0xda2cc3acc24fba57UL);
    assert(hash("http://hvo.wr.usgs.gov/cams/HMcam/") == 0x74136f185b29e7f0UL);
    assert(hash("http://hvo.wr.usgs.gov/kilauea/update/deformation.html") == 0xb2f2b4590edb93b2UL);
    assert(hash("http://hvo.wr.usgs.gov/kilauea/update/images.html") == 0xb3608fce8b86ae04UL);
    assert(hash("http://hvo.wr.usgs.gov/kilauea/update/maps.html") == 0x4a3a865079359063UL);
    assert(hash("http://hvo.wr.usgs.gov/volcanowatch/current_issue.html") == 0x5b3a7ef496880a50UL);
    assert(hash("http://neo.jpl.nasa.gov/risk/") == 0x48fae3163854c23bUL);
    assert(hash("http://norvig.com/21-days.html") == 0x07aaa640476e0b9aUL);
    assert(hash("http://primes.utm.edu/curios/home.php") == 0x2f653656383a687dUL);
    assert(hash("http://slashdot.org/") == 0xa1031f8e7599d79cUL);
    assert(hash("http://tux.wr.usgs.gov/Maps/155.25-19.5.html") == 0xa31908178ff92477UL);
    assert(hash("http://volcano.wr.usgs.gov/kilaueastatus.php") == 0x097edf3c14c3fb83UL);
    assert(hash("http://www.avo.alaska.edu/activity/Redoubt.php") == 0xb51ca83feaa0971bUL);
    assert(hash("http://www.dilbert.com/fast/") == 0xdd3c0d96d784f2e9UL);
    assert(hash("http://www.fourmilab.ch/gravitation/orbits/") == 0x86cd26a9ea767d78UL);
    assert(hash("http://www.fpoa.net/") == 0xe6b215ff54a30c18UL);
    assert(hash("http://www.ioccc.org/index.html") == 0xec5b06a1c5531093UL);
    assert(hash("http://www.isthe.com/cgi-bin/number.cgi") == 0x45665a929f9ec5e5UL);
    assert(hash("http://www.isthe.com/chongo/bio.html") == 0x8c7609b4a9f10907UL);
    assert(hash("http://www.isthe.com/chongo/index.html") == 0x89aac3a491f0d729UL);
    assert(hash("http://www.isthe.com/chongo/src/calc/lucas-calc") == 0x32ce6b26e0f4a403UL);
    assert(hash("http://www.isthe.com/chongo/tech/astro/venus2004.html") == 0x614ab44e02b53e01UL);
    assert(hash("http://www.isthe.com/chongo/tech/astro/vita.html") == 0xfa6472eb6eef3290UL);
    assert(hash("http://www.isthe.com/chongo/tech/comp/c/expert.html") == 0x9e5d75eb1948eb6aUL);
    assert(hash("http://www.isthe.com/chongo/tech/comp/calc/index.html") == 0xb6d12ad4a8671852UL);
    assert(hash("http://www.isthe.com/chongo/tech/comp/fnv/index.html") == 0x88826f56eba07af1UL);
    assert(hash("http://www.isthe.com/chongo/tech/math/number/howhigh.html") == 0x44535bf2645bc0fdUL);
    assert(hash("http://www.isthe.com/chongo/tech/math/number/number.html") == 0x169388ffc21e3728UL);
    assert(hash("http://www.isthe.com/chongo/tech/math/prime/mersenne.html") == 0xf68aac9e396d8224UL);
    assert(hash("http://www.isthe.com/chongo/tech/math/prime/mersenne.html#largest") == 0x8e87d7e7472b3883UL);
    assert(hash("http://www.lavarnd.org/cgi-bin/corpspeak.cgi") == 0x295c26caa8b423deUL);
    assert(hash("http://www.lavarnd.org/cgi-bin/haiku.cgi") == 0x322c814292e72176UL);
    assert(hash("http://www.lavarnd.org/cgi-bin/rand-none.cgi") == 0x8a06550eb8af7268UL);
    assert(hash("http://www.lavarnd.org/cgi-bin/randdist.cgi") == 0xef86d60e661bcf71UL);
    assert(hash("http://www.lavarnd.org/index.html") == 0x9e5426c87f30ee54UL);
    assert(hash("http://www.lavarnd.org/what/nist-test.html") == 0xf1ea8aa826fd047eUL);
    assert(hash("http://www.macosxhints.com/") == 0x0babaf9a642cb769UL);
    assert(hash("http://www.mellis.com/") == 0x4b3341d4068d012eUL);
    assert(hash("http://www.nature.nps.gov/air/webcams/parks/havoso2alert/havoalert.cfm") == 0xd15605cbc30a335cUL);
    assert(hash("http://www.nature.nps.gov/air/webcams/parks/havoso2alert/timelines_24.cfm") == 0x5b21060aed8412e5UL);
    assert(hash("http://www.paulnoll.com/") == 0x45e2cda1ce6f4227UL);
    assert(hash("http://www.pepysdiary.com/") == 0x50ae3745033ad7d4UL);
    assert(hash("http://www.sciencenews.org/index/home/activity/view") == 0xaa4588ced46bf414UL);
    assert(hash("http://www.skyandtelescope.com/") == 0xc1b0056c4a95467eUL);
    assert(hash("http://www.sput.nl/~rob/sirius.html") == 0x56576a71de8b4089UL);
    assert(hash("http://www.systemexperts.com/") == 0xbf20965fa6dc927eUL);
    assert(hash("http://www.tq-international.com/phpBB3/index.php") == 0x569f8383c2040882UL);
    assert(hash("http://www.travelquesttours.com/index.htm") == 0xe1e772fba08feca0UL);
    assert(hash("http://www.wunderground.com/global/stations/89606.html") == 0x4ced94af97138ac4UL);
    assert(hash(r10!"21701") == 0xc4112ffb337a82fbUL);
    assert(hash(r10!"M21701") == 0xd64a4fd41de38b7dUL);
    assert(hash(r10!"2^21701-1") == 0x4cfc32329edebcbbUL);
    assert(hash(r10!"\x54\xc5") == 0x0803564445050395UL);
    assert(hash(r10!"\xc5\x54") == 0xaa1574ecf4642ffdUL);
    assert(hash(r10!"23209") == 0x694bc4e54cc315f9UL);
    assert(hash(r10!"M23209") == 0xa3d7cb273b011721UL);
    assert(hash(r10!"2^23209-1") == 0x577c2f8b6115bfa5UL);
    assert(hash(r10!"\x5a\xa9") == 0xb7ec8c1a769fb4c1UL);
    assert(hash(r10!"\xa9\x5a") == 0x5d5cfce63359ab19UL);
    assert(hash(r10!"391581216093") == 0x33b96c3cd65b5f71UL);
    assert(hash(r10!"391581*2^216093-1") == 0xd845097780602bb9UL);
    assert(hash(r10!"\x05\xf9\x9d\x03\x4c\x81") == 0x84d47645d02da3d5UL);
    assert(hash(r10!"FEDCBA9876543210") == 0x83544f33b58773a5UL);
    assert(hash(r10!"\xfe\xdc\xba\x98\x76\x54\x32\x10") == 0x9175cbb2160836c5UL);
    assert(hash(r10!"EFCDAB8967452301") == 0xc71b3bc175e72bc5UL);
    assert(hash(r10!"\xef\xcd\xab\x89\x67\x45\x23\x01") == 0x636806ac222ec985UL);
    assert(hash(r10!"0123456789ABCDEF") == 0xb6ef0e6950f52ed5UL);
    assert(hash(r10!"\x01\x23\x45\x67\x89\xab\xcd\xef") == 0xead3d8a0f3dfdaa5UL);
    assert(hash(r10!"1032547698BADCFE") == 0x922908fe9a861ba5UL);
    assert(hash(r10!"\x10\x32\x54\x76\x98\xba\xdc\xfe") == 0x6d4821de275fd5c5UL);
    assert(hash(r500!"\x00") == 0x1fe3fce62bd816b5UL);
    assert(hash(r500!"\x07") == 0xc23e9fccd6f70591UL);
    assert(hash(r500!"~") == 0xc1af12bdfe16b5b5UL);
    assert(hash(r500!"\x7f") == 0x39e9f18f2f85e221UL);
}
