/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */
module tanya.math.tests;

import tanya.math;

static if (ieeePrecision!float == IEEEPrecision.doubleExtended)
@nogc nothrow pure @safe unittest
{
    assert(classify(1.68105e-10) == FloatingPointClass.normal);
    assert(classify(1.68105e-4932L) == FloatingPointClass.subnormal);

    // Emulate unnormals, because they aren't generated anymore since i386
    FloatBits!real unnormal;
    unnormal.exp = 0x123;
    unnormal.mantissa = 0x1;
    assert(classify(unnormal) == FloatingPointClass.subnormal);
}
