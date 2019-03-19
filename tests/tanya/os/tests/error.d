/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */
module tanya.os.tests.error;

import tanya.os.error;

@nogc nothrow pure @safe unittest
{
    ErrorCode ec = cast(ErrorCode.ErrorNo) -1;
    assert(ec.toString() is null);
}
