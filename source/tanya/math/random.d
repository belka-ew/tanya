/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * Random number generator.
 *
 * Copyright: Eugene Wissner 2016-2018.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 * Source: $(LINK2 https://github.com/caraus-ecms/tanya/blob/master/source/tanya/math/random.d,
 *                 tanya/math/random.d)
 */
module tanya.math.random;

import std.digest.sha;
import tanya.memory;
import tanya.typecons;

/// Block size of entropy accumulator (SHA-512).
deprecated
enum blockSize = 64;

/// Maximum amount gathered from the entropy sources.
enum maxGather = 128;

/**
 * Exception thrown if random number generating fails.
 */
class EntropyException : Exception
{
    /**
     * Params:
     *  msg  = Message to output.
     *  file = The file where the exception occurred.
     *  line = The line number where the exception occurred.
     *  next = The previous exception in the chain of exceptions, if any.
     */
    this(string msg,
         string file = __FILE__,
         size_t line = __LINE__,
         Throwable next = null) const @nogc nothrow pure @safe
    {
        super(msg, file, line, next);
    }
}

/**
 * Interface for implementing entropy sources.
 */
abstract class EntropySource
{
    /// Amount of already generated entropy.
    protected ushort size_;

    /**
     * Returns: Minimum bytes required from the entropy source.
     */
    @property ubyte threshold() const @nogc nothrow pure @safe;

    /**
     * Returns: Whether this entropy source is strong.
     */
    @property bool strong() const @nogc nothrow pure @safe;

    /**
     * Returns: Amount of already generated entropy.
     */
    @property ushort size() const @nogc nothrow pure @safe
    {
        return size_;
    }

    /**
     * Params:
     *  size = Amount of already generated entropy. Cannot be smaller than the
     *         already set value.
     */
    @property void size(ushort size) @nogc nothrow pure @safe
    {
        size_ = size;
    }

    /**
     * Poll the entropy source.
     *
     * Params:
     *  output = Buffer to save the generate random sequence (the method will
     *           to fill the buffer).
     *
     * Returns: Number of bytes that were copied to the $(D_PARAM output)
     *          or nothing on error.
     *
     * Postcondition: Returned length is less than or equal to
     *                $(D_PARAM output) length.
     */
    Option!ubyte poll(out ubyte[maxGather] output) @nogc
    out (length; length.isNothing || length.get <= maxGather);
}

version (CRuntime_Bionic)
{
    version = SecureARC4Random;
}
else version (OSX)
{
    version = SecureARC4Random;
}
else version (OpenBSD)
{
    version = SecureARC4Random;
}
else version (NetBSD)
{
    version = SecureARC4Random;
}
else version (Solaris)
{
    version = SecureARC4Random;
}

version (linux)
{
    import core.stdc.config : c_long;
    private extern(C) c_long syscall(c_long number, ...) @nogc nothrow @system;

    /**
     * Uses getrandom system call.
     */
    class PlatformEntropySource : EntropySource
    {
        /**
         * Returns: Minimum bytes required from the entropy source.
         */
        override @property ubyte threshold() const @nogc nothrow pure @safe
        {
            return 32;
        }

        /**
         * Returns: Whether this entropy source is strong.
         */
        override @property bool strong() const @nogc nothrow pure @safe
        {
            return true;
        }

        /**
         * Poll the entropy source.
         *
         * Params:
         *  output = Buffer to save the generate random sequence (the method will
         *           to fill the buffer).
         *
         * Returns: Number of bytes that were copied to the $(D_PARAM output)
         *          or nothing on error.
         */
        override Option!ubyte poll(out ubyte[maxGather] output) @nogc nothrow
        {
            // int getrandom(void *buf, size_t buflen, unsigned int flags);
            import mir.linux._asm.unistd : NR_getrandom;
            auto length = syscall(NR_getrandom, output.ptr, output.length, 0);
            Option!ubyte ret;

            if (length >= 0)
            {
                ret = cast(ubyte) length;
            }
            return ret;
        }
    }
}
else version (SecureARC4Random)
{
    private extern(C) void arc4random_buf(scope void* buf, size_t nbytes)
    @nogc nothrow @system;

    /**
     * Uses arc4random_buf.
     */
    class PlatformEntropySource : EntropySource
    {
        /**
         * Returns: Minimum bytes required from the entropy source.
         */
        override @property ubyte threshold() const @nogc nothrow pure @safe
        {
            return 32;
        }

        /**
         * Returns: Whether this entropy source is strong.
         */
        override @property bool strong() const @nogc nothrow pure @safe
        {
            return true;
        }

        /**
         * Poll the entropy source.
         *
         * Params:
         *  output = Buffer to save the generate random sequence (the method will
         *           to fill the buffer).
         *
         * Returns: Number of bytes that were copied to the $(D_PARAM output)
         *          or nothing on error.
         */
        override Option!ubyte poll(out ubyte[maxGather] output)
        @nogc nothrow @safe
        {
            (() @trusted => arc4random_buf(output.ptr, output.length))();
            return Option!ubyte(cast(ubyte) (output.length));
        }
    }
}
else version (Windows)
{
    import core.sys.windows.basetsd : ULONG_PTR;
    import core.sys.windows.winbase : GetLastError;
    import core.sys.windows.wincrypt;
    import core.sys.windows.windef : BOOL, DWORD, PBYTE;
    import core.sys.windows.winerror : NTE_BAD_KEYSET;
    import core.sys.windows.winnt : LPCSTR, LPCWSTR;

    private extern(Windows) @nogc nothrow
    {
        BOOL CryptGenRandom(HCRYPTPROV, DWORD, PBYTE);
        BOOL CryptAcquireContextA(HCRYPTPROV*, LPCSTR, LPCSTR, DWORD, DWORD);
        BOOL CryptAcquireContextW(HCRYPTPROV*, LPCWSTR, LPCWSTR, DWORD, DWORD);
        BOOL CryptReleaseContext(HCRYPTPROV, ULONG_PTR);
    }

    private bool initCryptGenRandom(scope ref HCRYPTPROV hProvider)
    @nogc nothrow @trusted
    {
        // https://msdn.microsoft.com/en-us/library/windows/desktop/aa379886(v=vs.85).aspx
        // For performance reasons, we recommend that you set the pszContainer
        // parameter to NULL and the dwFlags parameter to CRYPT_VERIFYCONTEXT
        // in all situations where you do not require a persisted key.
        // CRYPT_SILENT is intended for use with applications for which the UI
        // cannot be displayed by the CSP.
        if (!CryptAcquireContextW(&hProvider,
                                  null,
                                  null,
                                  PROV_RSA_FULL,
                                  CRYPT_VERIFYCONTEXT | CRYPT_SILENT))
        {
            if (GetLastError() != NTE_BAD_KEYSET)
            {
                return false;
            }
            // Attempt to create default container
            if (!CryptAcquireContextA(&hProvider,
                                      null,
                                      null,
                                      PROV_RSA_FULL,
                                      CRYPT_NEWKEYSET | CRYPT_SILENT))
            {
                return false;
            }
        }

        return true;
    }

    class PlatformEntropySource : EntropySource
    {
        private HCRYPTPROV hProvider;

        /**
         * Uses CryptGenRandom.
         */
        this() @nogc
        {
            if (!initCryptGenRandom(hProvider))
            {
                throw defaultAllocator.make!EntropyException("CryptAcquireContextW failed.");
            }
            assert(hProvider > 0, "hProvider not properly initialized.");
        }

        ~this() @nogc nothrow @safe
        {
            if (hProvider > 0)
            {
                (() @trusted => CryptReleaseContext(hProvider, 0))();
            }
        }

        /**
         * Returns: Minimum bytes required from the entropy source.
         */
        override @property ubyte threshold() const @nogc nothrow pure @safe
        {
            return 32;
        }

        /**
         * Returns: Whether this entropy source is strong.
         */
        override @property bool strong() const @nogc nothrow pure @safe
        {
            return true;
        }

        /**
         * Poll the entropy source.
         *
         * Params:
         *  output = Buffer to save the generate random sequence (the method will
         *           to fill the buffer).
         *
         * Returns: Number of bytes that were copied to the $(D_PARAM output)
         *          or nothing on error.
         */
        override Option!ubyte poll(out ubyte[maxGather] output)
        @nogc nothrow @safe
        {
            Option!ubyte ret;

            assert(hProvider > 0, "hProvider not properly initialized");
            if ((() @trusted => CryptGenRandom(hProvider, output.length, cast(PBYTE) output.ptr))())
            {
                ret = cast(ubyte) (output.length);
            }
            return ret;
        }
    }
}

static if (is(PlatformEntropySource)) @nogc @system unittest
{
    import tanya.memory.smartref : unique;

    auto source = defaultAllocator.unique!PlatformEntropySource();

    assert(source.threshold == 32);
    assert(source.strong);
}

/**
 * Pseudorandom number generator.
 * ---
 * auto entropy = defaultAllocator.make!Entropy();
 *
 * ubyte[blockSize] output;
 *
 * output = entropy.random;
 *
 * defaultAllocator.dispose(entropy);
 * ---
 */
deprecated
class Entropy
{
    /// Entropy sources.
    protected EntropySource[] sources;

    private ubyte sourceCount_;

    /// Entropy accumulator.
    protected SHA!(maxGather * 8, 512) accumulator;

    /**
     * Params:
     *  maxSources = Maximum amount of entropy sources can be set.
     *  allocator  = Allocator to allocate entropy sources available on the
     *               system.
     */
    this(const size_t maxSources = 20,
         shared Allocator allocator = defaultAllocator) @nogc
    in
    {
        assert(maxSources > 0 && maxSources <= ubyte.max);
        assert(allocator !is null);
    }
    do
    {
        allocator.resize(sources, maxSources);

        static if (is(PlatformEntropySource))
        {
            this ~= allocator.make!PlatformEntropySource;
        }
    }

    /**
     * Returns: Amount of the registered entropy sources.
     */
    @property ubyte sourceCount() const @nogc nothrow pure @safe
    {
        return sourceCount_;
    }

    /**
     * Add an entropy source.
     *
     * Params:
     *  source = Entropy source.
     *
     * Returns: $(D_PSYMBOL this).
     *
     * See_Also:
     *  $(D_PSYMBOL EntropySource)
     */
    Entropy opOpAssign(string op)(EntropySource source)
    @nogc nothrow pure @safe
    if (op == "~")
    in
    {
        assert(sourceCount_ <= sources.length);
    }
    do
    {
        sources[sourceCount_++] = source;
        return this;
    }

    /**
     * Returns: Generated random sequence.
     *
     * Throws: $(D_PSYMBOL EntropyException) if no strong entropy source was
     *         registered or it failed.
     */
    @property ubyte[blockSize] random() @nogc
    in
    {
        assert(sourceCount_ > 0, "No entropy sources defined.");
    }
    do
    {
        bool haveStrong;
        ushort done;
        ubyte[blockSize] output;

        do
        {
            ubyte[maxGather] buffer;

            // Run through our entropy sources
            for (ubyte i; i < sourceCount; ++i)
            {
                auto outputLength = sources[i].poll(buffer);

                if (!outputLength.isNothing)
                {
                    if (outputLength > 0)
                    {
                        update(i, buffer, outputLength);
                        sources[i].size = cast(ushort) (sources[i].size + outputLength);
                    }
                    if (sources[i].size < sources[i].threshold)
                    {
                        continue;
                    }
                    else if (sources[i].strong)
                    {
                        haveStrong = true;
                    }
                }
                done = 257;
            }
        }
        while (++done < 256);

        if (!haveStrong)
        {
            throw defaultAllocator.make!EntropyException("No strong entropy source defined.");
        }

        output = accumulator.finish();

        // Reset accumulator and counters and recycle existing entropy
        accumulator.start();

        // Perform second SHA-512 on entropy
        output = sha512Of(output);

        for (ubyte i; i < sourceCount; ++i)
        {
            sources[i].size = 0;
        }
        return output;
    }

    /**
     * Update entropy accumulator.
     *
     * Params:
     *  sourceId = Entropy source index in $(D_PSYMBOL sources).
     *  data     = Data got from the entropy source.
     *  length   = Length of the received data.
     */
    protected void update(in ubyte sourceId,
                          ref ubyte[maxGather] data,
                          ubyte length) @nogc nothrow pure @safe
    {
        ubyte[2] header;

        if (length > blockSize)
        {
            data[0 .. 64] = sha512Of(data);
            length = blockSize;
        }

        header[0] = sourceId;
        header[1] = length;

        accumulator.put(header);
        accumulator.put(data[0 .. length]);
    }
}
