/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * Common exceptions and errors.
 *
 * Copyright: Eugene Wissner 2017-2018.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 * Source: $(LINK2 https://github.com/caraus-ecms/tanya/blob/master/source/tanya/exception.d,
 *                 tanya/exception.d)
 */
module tanya.exception;

import tanya.conv;
import tanya.memory;

/**
 * Error thrown if memory allocation fails.
 */
final class OutOfMemoryError : Error
{
    /**
     * Constructs new error.
     *
     * Params:
     *  msg  = The message for the exception.
     *  file = The file where the exception occurred.
     *  line = The line number where the exception occurred.
     *  next = The previous exception in the chain of exceptions, if any.
     */
    this(string msg = "Out of memory",
         string file = __FILE__,
         size_t line = __LINE__,
         Throwable next = null) @nogc nothrow pure @safe
    {
        super(msg, file, line, next);
    }

    /// ditto
    this(string msg,
         Throwable next,
         string file = __FILE__,
         size_t line = __LINE__) @nogc nothrow pure @safe
    {
        super(msg, file, line, next);
    }
}

/**
 * Allocates $(D_PSYMBOL OutOfMemoryError) in a static storage and throws it.
 *
 * Params:
 *  msg = Custom error message.
 *
 * Throws: $(D_PSYMBOL OutOfMemoryError).
 */
void onOutOfMemoryError(string msg = "Out of memory")
@nogc nothrow pure @trusted
{
    static ubyte[stateSize!OutOfMemoryError] memory;
    alias PureType = OutOfMemoryError function(string) @nogc nothrow pure;
    throw (cast(PureType) () => emplace!OutOfMemoryError(memory))(msg);
}
