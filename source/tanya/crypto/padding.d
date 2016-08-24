/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * Copyright: Eugene Wissner 2016.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:belka@caraus.de, Eugene Wissner)
 */  
module tanya.crypto.padding;

import tanya.memory;
import std.algorithm.iteration;
import std.typecons;

@nogc:

/**
 * Supported padding mode.
 *
 * See_Also:
 * 	$(D_PSYMBOL applyPadding)
 */
enum Mode
{
	zero,
	pkcs7,
	ansiX923,
}

/**
 * Params:
 * 	allocator = Allocator that should be used if the block should be extended
 * 	            or a new block should be added.
 * 	input     = Sequence that should be padded.
 * 	mode      = Padding mode.
 * 	blockSize = Block size.
 *
 * Returns: The functions modifies the initial array and returns it.
 *
 * See_Also:
 * 	$(D_PSYMBOL Mode)
 */
ubyte[] applyPadding(ref ubyte[] input,
                     in Mode mode,
                     in ushort blockSize,
                     Allocator allocator = defaultAllocator)
in
{
	assert(blockSize > 0 && blockSize <= 256);
	assert(blockSize % 64 == 0);
	assert(input.length > 0);
}
body
{
	immutable rest = cast(ubyte) input.length % blockSize;
	immutable size_t lastBlock = input.length - (rest > 0 ? rest : blockSize);
	immutable needed = cast(ubyte) (rest > 0 ? blockSize - rest : 0);

	final switch (mode) with (Mode)
	{
		case zero:
			allocator.expandArray(input, needed);
			break;
		case pkcs7:
			if (needed)
			{
				allocator.expandArray(input, needed);
				input[input.length - needed ..$].each!((ref e) => e = needed);
			}
			else
			{
				allocator.expandArray(input, blockSize);
			}
			break;
		case ansiX923:
			allocator.expandArray(input, needed ? needed : blockSize);
			input[$ - 1] = needed;
			break;
	}

	return input;
}

///
unittest
{
	{ // Zeros
		auto input = defaultAllocator.makeArray!ubyte(50);

		applyPadding(input, Mode.zero, 64);
		assert(input.length == 64);

		applyPadding(input, Mode.zero, 64);
		assert(input.length == 64);
		assert(input[63] == 0);

		defaultAllocator.finalize(input);
	}
	{ // PKCS#7
		auto input = defaultAllocator.makeArray!ubyte(50);
		for (ubyte i; i < 40; ++i)
		{
			input[i] = i;
		}

		applyPadding(input, Mode.pkcs7, 64);
		assert(input.length == 64);
		for (ubyte i; i < 64; ++i)
		{
			if (i >= 40 && i < 50)
			{
				assert(input[i] == 0);
			}
			else if (i >= 50)
			{
				assert(input[i] == 14);
			}
			else
			{
				assert(input[i] == i);
			}
		}

		applyPadding(input, Mode.pkcs7, 64);
		assert(input.length == 128);
		for (ubyte i; i < 128; ++i)
		{
			if (i >= 64 || (i >= 40 && i < 50))
			{
				assert(input[i] == 0);
			}
			else if (i >= 50 && i < 64)
			{
				assert(input[i] == 14);
			}
			else
			{
				assert(input[i] == i);
			}
		}

		defaultAllocator.finalize(input);
	}
	{ // ANSI X.923
		auto input = defaultAllocator.makeArray!ubyte(50);
		for (ubyte i; i < 40; ++i)
		{
			input[i] = i;
		}

		applyPadding(input, Mode.ansiX923, 64);
		assert(input.length == 64);
		for (ubyte i; i < 64; ++i)
		{
			if (i < 40)
			{
				assert(input[i] == i);
			}
			else if (i == 63)
			{
				assert(input[i] == 14);
			}
			else
			{
				assert(input[i] == 0);
			}
		}

		applyPadding(input, Mode.pkcs7, 64);
		assert(input.length == 128);
		for (ubyte i = 0; i < 128; ++i)
		{
			if (i < 40)
			{
				assert(input[i] == i);
			}
			else if (i == 63)
			{
				assert(input[i] == 14);
			}
			else
			{
				assert(input[i] == 0);
			}
		}

		defaultAllocator.finalize(input);
	}
}
