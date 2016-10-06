/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * Interfaces for implementing secret key algorithms.
 *
 * Copyright: Eugene Wissner 2016.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:belka@caraus.de, Eugene Wissner)
 */
module tanya.crypto.symmetric;

/**
 * Implemented by secret key algorithms.
 */
interface SymmetricCipher
{
    /**
     * Returns: Key length.
     */
    @property inout(uint) keyLength() inout const pure nothrow @safe @nogc;

    /**
     * Returns: Minimum key length.
     */
    @property inout(uint) minKeyLength() inout const pure nothrow @safe @nogc;

    /**
     * Returns: Maximum key length.
     */
    @property inout(uint) maxKeyLength() inout const pure nothrow @safe @nogc;

    /// Cipher direction.
    protected enum Direction : ushort
    {
        encryption,
        decryption,
    }

    /**
     * Params:
     *     key = Key.
     */
    @property void key(ubyte[] key) pure nothrow @safe @nogc
    in
    {
        assert(key.length >= minKeyLength);
        assert(key.length <= maxKeyLength);
    }
}

/**
 * Implemented by block ciphers.
 */
interface BlockCipher : SymmetricCipher
{
    /**
     * Returns: Block size.
     */
    @property inout(uint) blockSize() inout const pure nothrow @safe @nogc;

    /**
     * Encrypts a block.
     *
     * Params:
     *    plain  = Plain text, input.
     *    cipher = Cipher text, output.
     */
    void encrypt(in ubyte[] plain, ubyte[] cipher)
    in
    {
        assert(plain.length == blockSize);
        assert(cipher.length == blockSize);
    }

    /**
     * Decrypts a block.
     *
     * Params:
     *    cipher = Cipher text, input.
     *    plain  = Plain text, output.
     */
    void decrypt(in ubyte[] cipher, ubyte[] plain)
    in
    {
        assert(plain.length == blockSize);
        assert(cipher.length == blockSize);
    }
}

/**
 * Mixed in by algorithms with fixed block size.
 *
 * Params:
 *     N = Block size.
 */
mixin template FixedBlockSize(uint N)
    if (N != 0)
{
    private enum uint blockSize_ = N;

    /**
     * Returns: Fixed block size.
     */
    final @property inout(uint) blockSize() inout const pure nothrow @safe @nogc
    {
        return blockSize_;
    }
}

/**
 * Mixed in by symmetric algorithms.
 * If $(D_PARAM Min) equals $(D_PARAM Max) fixed key length is assumed.
 *
 * Params:
 *     Min = Minimum key length.
 *     Max = Maximum key length.
 */
mixin template KeyLength(uint Min, uint Max = Min)
    if (Min != 0 && Max != 0)
{
    static if (Min == Max)
    {
        private enum uint keyLength_ = Min;

        /**
         * Returns: Key length.
         */
        final @property inout(uint) keyLength() inout const pure nothrow @safe @nogc
        {
            return keyLength_;
        }

        /**
         * Returns: Minimum key length.
         */
        final @property inout(uint) minKeyLength() inout const pure nothrow @safe @nogc
        {
            return keyLength_;
        }

        /**
         * Returns: Maximum key length.
         */
        final @property inout(uint) maxKeyLength() inout const pure nothrow @safe @nogc
        {
            return keyLength_;
        }
    }
    else static if (Min < Max)
    {
        private enum uint minKeyLength_ = Min;
        private enum uint maxKeyLength_ = Max;

        /**
         * Returns: Minimum key length.
         */
        final @property inout(uint) minKeyLength() inout const pure nothrow @safe @nogc
        {
            return minKeyLength_;
        }

        /**
         * Returns: Maximum key length.
         */
        final @property inout(uint) maxKeyLength() inout const pure nothrow @safe @nogc
        {
            return maxKeyLength_;
        }
    }
    else
    {
        static assert(false, "Max should be larger or equal to Min");
    }
}
