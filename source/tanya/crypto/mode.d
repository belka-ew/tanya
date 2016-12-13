/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * Block cipher modes of operation.
 *
 * Copyright: Eugene Wissner 2016.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:belka@caraus.de, Eugene Wissner)
 */
module tanya.crypto.mode;

import tanya.memory;
import std.algorithm.iteration;
import std.typecons;

/**
 * Supported padding mode.
 *
 * See_Also:
 * 	$(D_PSYMBOL pad)
 */
enum PaddingMode
{
	zero,
	pkcs7,
	ansiX923,
}

/**
 * Params:
 * 	input     = Sequence that should be padded.
 * 	mode      = Padding mode.
 * 	blockSize = Block size.
 * 	allocator = Allocator was used to allocate $(D_PARAM input).
 *
 * Returns: The function modifies the initial array and returns it.
 *
 * See_Also:
 * 	$(D_PSYMBOL PaddingMode)
 */
ubyte[] pad(ref ubyte[] input,
            in PaddingMode mode,
            in ushort blockSize,
            shared Allocator allocator = defaultAllocator)
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

	final switch (mode) with (PaddingMode)
	{
		case zero:
			allocator.resizeArray(input, input.length + needed);
			break;
		case pkcs7:
			if (needed)
			{
				allocator.resizeArray(input, input.length + needed);
				input[input.length - needed ..$].each!((ref e) => e = needed);
			}
			else
			{
				allocator.resizeArray(input, input.length + blockSize);
			}
			break;
		case ansiX923:
			allocator.resizeArray(input, input.length + (needed ? needed : blockSize));
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

		pad(input, PaddingMode.zero, 64);
		assert(input.length == 64);

		pad(input, PaddingMode.zero, 64);
		assert(input.length == 64);
		assert(input[63] == 0);

		defaultAllocator.dispose(input);
	}
	{ // PKCS#7
		auto input = defaultAllocator.makeArray!ubyte(50);
		for (ubyte i; i < 40; ++i)
		{
			input[i] = i;
		}

		pad(input, PaddingMode.pkcs7, 64);
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

		pad(input, PaddingMode.pkcs7, 64);
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

		defaultAllocator.dispose(input);
	}
	{ // ANSI X.923
		auto input = defaultAllocator.makeArray!ubyte(50);
		for (ubyte i; i < 40; ++i)
		{
			input[i] = i;
		}

		pad(input, PaddingMode.ansiX923, 64);
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

		pad(input, PaddingMode.pkcs7, 64);
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

		defaultAllocator.dispose(input);
	}
}

/**
 * Params:
 * 	input     = Sequence that should be padded.
 * 	mode      = Padding mode.
 * 	blockSize = Block size.
 * 	allocator = Allocator was used to allocate $(D_PARAM input).
 *
 * Returns: The function modifies the initial array and returns it.
 *
 * See_Also:
 * 	$(D_PSYMBOL pad)
 */
ref ubyte[] unpad(ref ubyte[] input,
                  in PaddingMode mode,
                  in ushort blockSize,
                  shared Allocator allocator = defaultAllocator)
in
{
	assert(input.length != 0);
	assert(input.length % 64 == 0);
}
body
{
	final switch (mode) with (PaddingMode)
	{
		case zero:
			break;
		case pkcs7:
		case ansiX923:
			immutable last = input[$ - 1];

			allocator.resizeArray(input, input.length - (last ? last : blockSize));
			break;
	}

	return input;
}

///
unittest
{
	{ // Zeros
		auto input = defaultAllocator.makeArray!ubyte(50);
		auto inputDup = defaultAllocator.makeArray!ubyte(50);

		pad(input, PaddingMode.zero, 64);
		pad(inputDup, PaddingMode.zero, 64);

		unpad(input, PaddingMode.zero, 64);
		assert(input == inputDup);

		defaultAllocator.dispose(input);
		defaultAllocator.dispose(inputDup);

	}
	{ // PKCS#7
		auto input = defaultAllocator.makeArray!ubyte(50);
		auto inputDup = defaultAllocator.makeArray!ubyte(50);
		for (ubyte i; i < 40; ++i)
		{
			input[i] = i;
			inputDup[i] = i;
		}

		pad(input, PaddingMode.pkcs7, 64);
		unpad(input, PaddingMode.pkcs7, 64);
		assert(input == inputDup);

		defaultAllocator.dispose(input);
		defaultAllocator.dispose(inputDup);
	}
	{ // ANSI X.923
		auto input = defaultAllocator.makeArray!ubyte(50);
		auto inputDup = defaultAllocator.makeArray!ubyte(50);
		for (ubyte i; i < 40; ++i)
		{
			input[i] = i;
			inputDup[i] = i;
		}

		pad(input, PaddingMode.pkcs7, 64);
		unpad(input, PaddingMode.pkcs7, 64);
		assert(input == inputDup);

		defaultAllocator.dispose(input);
		defaultAllocator.dispose(inputDup);
	}
}
