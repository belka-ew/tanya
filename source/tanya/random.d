/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * Copyright: Eugene Wissner 2016.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:belka@caraus.de, Eugene Wissner)
 */  
module tanya.random;

import tanya.memory;
import std.digest.sha;
import std.typecons;

/// Block size of entropy accumulator (SHA-512).
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
	 * 	msg  = Message to output.
	 * 	file = The file where the exception occurred.
	 * 	line = The line number where the exception occurred.
	 * 	next = The previous exception in the chain of exceptions, if any.
	 */
	this(string msg,
	     string file = __FILE__,
	     size_t line = __LINE__,
	     Throwable next = null) pure @safe nothrow const @nogc
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
	@property immutable(ubyte) threshold() const @safe pure nothrow;

	/**
	 * Returns: Whether this entropy source is strong.
	 */
	@property immutable(bool) strong() const @safe pure nothrow;

	/**
	 * Returns: Amount of already generated entropy.
	 */
	@property ushort size() const @safe pure nothrow
	{
		return size_;
	}

	/**
	 * Params:
	 * 	size = Amount of already generated entropy. Cannot be smaller than the
	 * 	       already set value.
	 */
	@property void size(ushort size) @safe pure nothrow
	{
		size_ = size;
	}

	/**
	 * Poll the entropy source.
	 *
	 * Params:
	 * 	output = Buffer to save the generate random sequence (the method will
	 * 	         to fill the buffer).
	 *
	 * Returns: Number of bytes that were copied to the $(D_PARAM output)
	 *          or $(D_PSYMBOL Nullable!ubyte.init) on error.
	 */
	Nullable!ubyte poll(out ubyte[maxGather] output);
}

version (linux)
{
	extern (C) long syscall(long number, ...) nothrow;

	/**
	 * Uses getrandom system call.
	 */
	class PlatformEntropySource : EntropySource
	{
		/**
		 * Returns: Minimum bytes required from the entropy source.
		 */
		override @property immutable(ubyte) threshold() const @safe pure nothrow
		{
			return 32;
		}

		/**
		 * Returns: Whether this entropy source is strong.
		 */
		override @property immutable(bool) strong() const @safe pure nothrow
		{
			return true;
		}

		/**
		 * Poll the entropy source.
		 *
		 * Params:
		 * 	output = Buffer to save the generate random sequence (the method will
		 * 	         to fill the buffer).
		 *
		 * Returns: Number of bytes that were copied to the $(D_PARAM output)
		 *          or $(D_PSYMBOL Nullable!ubyte.init) on error.
		 */
		override Nullable!ubyte poll(out ubyte[maxGather] output) nothrow
		out (length)
		{
			assert(length <= maxGather);
		}
		body
		{
			// int getrandom(void *buf, size_t buflen, unsigned int flags);
			auto length = syscall(318, output.ptr, output.length, 0);
			Nullable!ubyte ret;

			if (length >= 0)
			{
				ret = cast(ubyte) length;
			}
			return ret;
		}
	}
}

/**
 * Pseudorandom number generator.
 * ---
 * auto entropy = defaultAllocator.make!Entropy;
 *
 * ubyte[blockSize] output;
 *
 * output = entropy.random;
 *
 * defaultAllocator.finalize(entropy);
 * ---
 */
class Entropy
{
	/// Entropy sources.
	protected EntropySource[] sources;

	private ubyte sourceCount_;

	private shared Allocator allocator;

	/// Entropy accumulator.
	protected SHA!(maxGather * 8, 512) accumulator;

	/**
	 * Params:
	 *  maxSources = Maximum amount of entropy sources can be set.
	 * 	allocator  = Allocator to allocate entropy sources available on the
	 * 	             system.
	 */
	this(size_t maxSources = 20, shared Allocator allocator = defaultAllocator)
	in
	{
		assert(maxSources > 0 && maxSources <= ubyte.max);
		assert(allocator !is null);
	}
	body
	{
		allocator.resizeArray(sources, maxSources);

		version (linux)
		{
			this ~= allocator.make!PlatformEntropySource;
		}
	}

	/**
	 * Returns: Amount of the registered entropy sources.
	 */
	@property ubyte sourceCount() const @safe pure nothrow
	{
		return sourceCount_;
	}

	/**
	 * Add an entropy source.
	 *
	 * Params:
	 * 	source = Entropy source.
	 *
	 * Returns: $(D_PSYMBOL this).
	 *
	 * See_Also:
	 * 	$(D_PSYMBOL EntropySource)
	 */
	Entropy opOpAssign(string Op)(EntropySource source) @safe pure nothrow
		if (Op == "~")
	in
	{
		assert(sourceCount_ <= sources.length);
	}
	body
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
	@property ubyte[blockSize] random()
	in
	{
		assert(sourceCount_ > 0, "No entropy sources defined.");
	}
	body
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

				if (!outputLength.isNull)
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
			throw allocator.make!EntropyException("No strong entropy source defined.");
		}

		output = accumulator.finish();

		// Reset accumulator and counters and recycle existing entropy
		accumulator.start();

		// Perform second SHA-512 on entropy
		output = sha512Of(output);

		for (ubyte i = 0; i < sourceCount; ++i)
		{
			sources[i].size = 0;
		}
		return output;
	}

	/**
	 * Update entropy accumulator.
	 *
	 * Params:
	 * 	sourceId = Entropy source index in $(D_PSYMBOL sources).
	 * 	data     = Data got from the entropy source.
	 * 	length   = Length of the received data.
	 */
	protected void update(in ubyte sourceId,
	                      ref ubyte[maxGather] data,
	                      ubyte length) @safe pure nothrow
	{
		ubyte[2] header;

		if (length > blockSize)
		{
			data[0..64] = sha512Of(data);
			length = blockSize;
		}

		header[0] = sourceId;
		header[1] = length;

		accumulator.put(header);
		accumulator.put(data[0..length]);
	}
}
