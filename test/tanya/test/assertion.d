/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * Additional assertions.
 *
 * This module provides functions that assert whether a given expression
 * satisfies some complex condition, that can't be tested with
 * $(D_KEYWORD assert) in a single line. Internally all the functions
 * just evaluate the expression and call $(D_KEYWORD assert).
 *
 * The functions can cause segmentation fault if the module is compiled
 * in production mode and the condition fails.
 *
 * Copyright: Eugene Wissner 2017-2019.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 * Source: $(LINK2 https://github.com/caraus-ecms/tanya/blob/master/source/tanya/test/assertion.d,
 *                 tanya/test/assertion.d)
 */
module tanya.test.assertion;

import tanya.memory.allocator;
import tanya.meta.trait;

/**
 * Asserts whether the function $(D_PARAM expr) throws an exception of type
 * $(D_PARAM E). If it does, the exception is catched and properly destroyed.
 * If it doesn't, an assertion error is thrown. If the exception doesn't match
 * $(D_PARAM E) type, it isn't catched and escapes.
 *
 * Params:
 *  E    = Expected exception type.
 *  T    = Throwing function type.
 *  Args = Argument types of the throwing function.
 *  expr = Throwing function.
 *  args = Arguments for $(D_PARAM expr).
 */
void assertThrown(E : Exception, T, Args...)(T expr, auto ref Args args)
if (isSomeFunction!T)
{
    try
    {
        cast(void) expr(args);
        assert(false, "Expected exception not thrown");
    }
    catch (E exception)
    {
        defaultAllocator.dispose(exception);
    }
}

///
@nogc nothrow pure @safe unittest
{
    // If you want to test that an expression throws, you can wrap it into an
    // arrow function.
    static struct CtorThrows
    {
        this(int i) @nogc pure @safe
        {
            throw defaultAllocator.make!Exception();
        }
    }
    assertThrown!Exception(() => CtorThrows(8));
}

/**
 * Asserts that the function $(D_PARAM expr) doesn't throw.
 *
 * If it does, the thrown exception is catched, properly destroyed and an
 * assertion error is thrown instead.
 *
 * Params:
 *  T    = Tested function type.
 *  Args = Argument types of $(D_PARAM expr).
 *  expr = Tested function.
 *  args = Arguments for $(D_PARAM expr).
 */
void assertNotThrown(T, Args...)(T expr, auto ref Args args)
if (isSomeFunction!T)
{
    try
    {
        cast(void) expr(args);
    }
    catch (Exception exception)
    {
        defaultAllocator.dispose(exception);
        assert(false, "Unexpected exception thrown");
    }
}

///
@nogc nothrow pure @safe unittest
{
    // If you want to test that an expression doesn't throw, you can wrap it
    // into an arrow function.
    static struct S
    {
    }
    assertNotThrown(() => S());
}
