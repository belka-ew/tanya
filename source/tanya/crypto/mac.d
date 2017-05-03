/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * Message Authentication Codes.
 *
 * Copyright: Eugene Wissner 2017.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 */
module tanya.crypto.mac;

import std.algorithm.mutation;
import std.digest.digest;
import std.traits;
import tanya.container.vector;

version (unittest)
{
    import std.algorithm.comparison;
    import tanya.memory;
}

interface MessageAuthenticationCode
{
    /**
     * (Re)starts the hash.
     *
     * Params:
     *  secret = Secret key.
     */
    void start(ref const Vector!ubyte secret) @nogc;

    /**
     * Updates a hash with additional input.
     *
     * Params:
     *  data = Input.
     */
    void put(Range!(const ubyte) data) @nogc;

    /**
     * Computes the hash of the current message.
     *
     * Returns: The hash of the current message.
     */
    Vector!ubyte finish() @nogc;

    /**
     * Returns: Digest size of the hash.
     */
    @property uint digestLength() const pure nothrow @safe @nogc;
}

/**
 * Hash Message Authentication Code.
 *
 * Params:
 *  H = Hash type.
 */
final class HMAC(H) : MessageAuthenticationCode
    if (hasBlockSize!H)
{
    private H idigest;
    private H odigest;

    /**
     * (Re)starts the hash.
     *
     * Params:
     *  secret = Secret key.
     */
    void start(ref const Vector!ubyte secret) pure nothrow @trusted
    {
        ubyte[H.blockSize / 8] ipad = 0x36;
        ubyte[H.blockSize / 8] opad = 0x5c;
        const(ubyte)[] buffer;
        ReturnType!(H.finish) key = void;

        if (secret.length > H.blockSize / 8)
        {
            auto digest = makeDigest!H;
            digest.put(secret.get());
            key = digest.finish();
            buffer = key;
        }
        else
        {
            buffer = secret.get();
        }

        foreach (ref const i, ref const v; buffer)
        {
            ipad[i] ^= v;
            opad[i] ^= v;
        }

        this.idigest.start();
        this.idigest.put(ipad);

        this.odigest.start();
        this.odigest.put(opad);
    }

    /**
     * Updates a hash with additional input.
     *
     * Params:
     *  data = Input.
     */
    void put(Range!(const ubyte) data) pure nothrow @safe
    {
        this.idigest.put(data.get());
    }

    /**
     * Computes the hash of the current message.
     *
     * Returns: The hash of the current message.
     */
    Vector!ubyte finish() nothrow @safe
    {
        this.odigest.put(this.idigest.finish());

        return Vector!ubyte(odigest.finish());
    }

    /**
     * Returns: Digest size of the hash.
     */
    @property uint digestLength() const pure nothrow @safe
    {
        return ReturnType!(H.finish).length;
    }
}

///
nothrow @nogc unittest
{
    import std.digest.md;

    auto hmac = defaultAllocator.make!(HMAC!MD5);

    auto key = Vector!ubyte(16, 0x0b);
    auto text = const Vector!ubyte(['H', 'i', ' ', 'T', 'h', 'e', 'r', 'e']);
    ubyte[16] expected = [ 0x92, 0x94, 0x72, 0x7a, 0x36, 0x38, 0xbb, 0x1c,
                           0x13, 0xf4, 0x8e, 0xf8, 0x15, 0x8b, 0xfc, 0x9d ];

    hmac.start(key);
    hmac.put(text[]);
    assert(equal(hmac.finish()[], expected[]));

    defaultAllocator.dispose(hmac);
}

// Test vectors from RFC 2202. MD5.
private nothrow @nogc unittest
{
    import std.digest.md;

    auto hmac = defaultAllocator.make!(HMAC!MD5);
    { // 2
        auto key = Vector!ubyte(['J', 'e', 'f', 'e']);
        auto text = const Vector!ubyte(['w', 'h', 'a', 't', ' ', 'd', 'o', ' ', 'y', 'a', ' ',
            'w', 'a', 'n', 't', ' ', 'f', 'o', 'r', ' ', 'n', 'o', 't', 'h', 'i', 'n', 'g', '?']);
        ubyte[16] expected = [ 0x75, 0x0c, 0x78, 0x3e, 0x6a, 0xb0, 0xb5, 0x03,
                               0xea, 0xa8, 0x6e, 0x31, 0x0a, 0x5d, 0xb7, 0x38 ];

        hmac.start(key);
        hmac.put(text[]);
        assert(equal(hmac.finish()[], expected[]));
    }
    { // 3
        auto key = Vector!ubyte(16, 0xaa);
        auto text = const Vector!ubyte(50, 0xdd);
        ubyte[16] expected = [ 0x56, 0xbe, 0x34, 0x52, 0x1d, 0x14, 0x4c, 0x88,
                               0xdb, 0xb8, 0xc7, 0x33 ,0xf0, 0xe8, 0xb3, 0xf6 ];

        hmac.start(key);
        hmac.put(text[]);
        assert(equal(hmac.finish()[], expected[]));
    }
    { // 4
        auto key = Vector!ubyte(cast(ubyte[25])
                                [ 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09,
                                  0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f, 0x10, 0x11, 0x12,
                                  0x13, 0x14, 0x15, 0x16, 0x17, 0x18, 0x19, ]);
        auto text = const Vector!ubyte(50, 0xcd);
        ubyte[16] expected = [ 0x69, 0x7e, 0xaf, 0x0a, 0xca, 0x3a, 0x3a, 0xea,
                               0x3a, 0x75, 0x16, 0x47, 0x46, 0xff, 0xaa, 0x79 ];

        hmac.start(key);
        hmac.put(text[]);
        assert(equal(hmac.finish()[], expected[]));
    }
    { // 5
        auto key = Vector!ubyte(16, 0x0c);
        auto text = const Vector!ubyte([ 'T', 'e', 's', 't', ' ', 'W', 'i', 't', 'h', ' ',
                                   'T', 'r', 'u', 'n', 'c', 'a', 't', 'i', 'o', 'n' ]);
        ubyte[16] expected = [ 0x56, 0x46, 0x1e, 0xf2, 0x34, 0x2e, 0xdc, 0x00,
                               0xf9, 0xba, 0xb9, 0x95, 0x69, 0x0e, 0xfd, 0x4c ];

        hmac.start(key);
        hmac.put(text[]);
        assert(equal(hmac.finish()[], expected[]));
    }
    { // 6
        auto key = Vector!ubyte(80, 0xaa);
        auto text = const Vector!ubyte([ 'T', 'e', 's', 't', ' ', 'U', 's', 'i', 'n', 'g', ' ',
                                   'L', 'a', 'r', 'g', 'e', 'r', ' ', 'T', 'h', 'a', 'n', ' ',
                                   'B', 'l', 'o', 'c', 'k', '-', 'S', 'i', 'z', 'e', ' ',
                                   'K', 'e', 'y', ' ', '-', ' ', 'H', 'a', 's', 'h', ' ',
                                   'K', 'e', 'y', ' ', 'F', 'i', 'r', 's', 't' ]);
        ubyte[16] expected = [ 0x6b, 0x1a, 0xb7, 0xfe, 0x4b, 0xd7, 0xbf, 0x8f,
                               0x0b, 0x62, 0xe6, 0xce, 0x61, 0xb9, 0xd0, 0xcd ];

        hmac.start(key);
        hmac.put(text[]);
        assert(equal(hmac.finish()[], expected[]));
    }
    { // 7
        auto key = Vector!ubyte(80, 0xaa);
        auto text = const Vector!ubyte([ 'T', 'e', 's', 't', ' ', 'U', 's', 'i', 'n', 'g', ' ',
                                   'L', 'a', 'r', 'g', 'e', 'r', ' ', 'T', 'h', 'a', 'n', ' ',
                                   'B', 'l', 'o', 'c', 'k', '-', 'S', 'i', 'z', 'e', ' ',
                                   'K', 'e', 'y', ' ', 'a', 'n', 'd', ' ',
                                   'L', 'a', 'r', 'g', 'e', 'r', ' ', 'T', 'h', 'a', 'n', ' ',
                                   'O', 'n', 'e', ' ', 'B', 'l', 'o', 'c', 'k', '-', 'S', 'i', 'z', 'e', ' ',
                                   'D', 'a', 't', 'a' ]);
        ubyte[16] expected = [ 0x6f, 0x63, 0x0f, 0xad, 0x67, 0xcd, 0xa0, 0xee,
                               0x1f, 0xb1, 0xf5, 0x62, 0xdb, 0x3a, 0xa5, 0x3e ];

        hmac.start(key);
        hmac.put(text[]);
        assert(equal(hmac.finish()[], expected[]));
    }
    defaultAllocator.dispose(hmac);
}

// Test vectors from RFC 2202. SHA1.
private nothrow @nogc unittest
{
    import std.digest.sha;

    auto hmac = defaultAllocator.make!(HMAC!SHA1);
    { // 1
        auto key = Vector!ubyte(20, 0x0b);
        auto text = const Vector!ubyte(['H', 'i', ' ', 'T', 'h', 'e', 'r', 'e']);
        ubyte[20] expected = [ 0xb6, 0x17, 0x31, 0x86, 0x55, 0x05, 0x72, 0x64, 0xe2, 0x8b,
                               0xc0, 0xb6, 0xfb, 0x37, 0x8c, 0x8e, 0xf1, 0x46, 0xbe, 0x00 ];

        hmac.start(key);
        hmac.put(text[]);
        assert(equal(hmac.finish()[], expected[]));
    }
    { // 2
        auto key = Vector!ubyte(['J', 'e', 'f', 'e']);
        auto text = const Vector!ubyte(['w', 'h', 'a', 't', ' ', 'd', 'o', ' ', 'y', 'a', ' ',
            'w', 'a', 'n', 't', ' ', 'f', 'o', 'r', ' ', 'n', 'o', 't', 'h', 'i', 'n', 'g', '?']);
        ubyte[20] expected = [ 0xef, 0xfc, 0xdf, 0x6a, 0xe5, 0xeb, 0x2f, 0xa2, 0xd2, 0x74,
                               0x16, 0xd5, 0xf1, 0x84, 0xdf, 0x9c, 0x25, 0x9a, 0x7c, 0x79 ];

        hmac.start(key);
        hmac.put(text[]);
        assert(equal(hmac.finish()[], expected[]));
    }
    { // 3
        auto key = Vector!ubyte(20, 0xaa);
        auto text = const Vector!ubyte(50, 0xdd);
        ubyte[20] expected = [ 0x12, 0x5d, 0x73, 0x42, 0xb9, 0xac, 0x11, 0xcd, 0x91, 0xa3,
                               0x9a, 0xf4, 0x8a, 0xa1, 0x7b, 0x4f, 0x63, 0xf1, 0x75, 0xd3 ];

        hmac.start(key);
        hmac.put(text[]);
        assert(equal(hmac.finish()[], expected[]));
    }
    { // 4
        auto key = Vector!ubyte(cast(ubyte[25])
                                [ 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09,
                                  0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f, 0x10, 0x11, 0x12,
                                  0x13, 0x14, 0x15, 0x16, 0x17, 0x18, 0x19, ]);
        auto text = const Vector!ubyte(50, 0xcd);
        ubyte[20] expected = [ 0x4c, 0x90, 0x07, 0xf4, 0x02, 0x62, 0x50, 0xc6, 0xbc, 0x84,
                               0x14, 0xf9, 0xbf, 0x50, 0xc8, 0x6c, 0x2d, 0x72, 0x35, 0xda ];

        hmac.start(key);
        hmac.put(text[]);
        assert(equal(hmac.finish()[], expected[]));
    }
    { // 5
        auto key = Vector!ubyte(20, 0x0c);
        auto text = const Vector!ubyte([ 'T', 'e', 's', 't', ' ', 'W', 'i', 't', 'h', ' ',
                                   'T', 'r', 'u', 'n', 'c', 'a', 't', 'i', 'o', 'n' ]);
        ubyte[20] expected = [ 0x4c, 0x1a, 0x03, 0x42, 0x4b, 0x55, 0xe0, 0x7f, 0xe7, 0xf2,
                               0x7b, 0xe1, 0xd5, 0x8b, 0xb9, 0x32, 0x4a, 0x9a, 0x5a, 0x04 ];

        hmac.start(key);
        hmac.put(text[]);
        assert(equal(hmac.finish()[], expected[]));
    }
    { // 6
        auto key = Vector!ubyte(80, 0xaa);
        auto text = const Vector!ubyte([ 'T', 'e', 's', 't', ' ', 'U', 's', 'i', 'n', 'g', ' ',
                                   'L', 'a', 'r', 'g', 'e', 'r', ' ', 'T', 'h', 'a', 'n', ' ',
                                   'B', 'l', 'o', 'c', 'k', '-', 'S', 'i', 'z', 'e', ' ',
                                   'K', 'e', 'y', ' ', '-', ' ', 'H', 'a', 's', 'h', ' ',
                                   'K', 'e', 'y', ' ', 'F', 'i', 'r', 's', 't' ]);
        ubyte[20] expected = [ 0xaa, 0x4a, 0xe5, 0xe1, 0x52, 0x72, 0xd0, 0x0e, 0x95, 0x70,
                               0x56, 0x37, 0xce, 0x8a, 0x3b, 0x55, 0xed, 0x40, 0x21, 0x12 ];

        hmac.start(key);
        hmac.put(text[]);
        assert(equal(hmac.finish()[], expected[]));
    }
    { // 7
        auto key = Vector!ubyte(80, 0xaa);
        auto text = const Vector!ubyte([ 'T', 'e', 's', 't', ' ', 'U', 's', 'i', 'n', 'g', ' ',
                                   'L', 'a', 'r', 'g', 'e', 'r', ' ', 'T', 'h', 'a', 'n', ' ',
                                   'B', 'l', 'o', 'c', 'k', '-', 'S', 'i', 'z', 'e', ' ',
                                   'K', 'e', 'y', ' ', 'a', 'n', 'd', ' ',
                                   'L', 'a', 'r', 'g', 'e', 'r', ' ', 'T', 'h', 'a', 'n', ' ',
                                   'O', 'n', 'e', ' ', 'B', 'l', 'o', 'c', 'k', '-', 'S', 'i', 'z', 'e', ' ',
                                   'D', 'a', 't', 'a' ]);
        ubyte[20] expected = [ 0xe8, 0xe9, 0x9d, 0x0f, 0x45, 0x23, 0x7d, 0x78, 0x6d, 0x6b,
                               0xba, 0xa7, 0x96, 0x5c, 0x78, 0x08, 0xbb, 0xff, 0x1a, 0x91 ];

        hmac.start(key);
        hmac.put(text[]);
        assert(equal(hmac.finish()[], expected[]));
    }
    defaultAllocator.dispose(hmac);
}
