module tanya.os.tests.error;

import tanya.os.error;

@nogc nothrow pure @safe unittest
{
    ErrorCode ec = cast(ErrorCode.ErrorNo) -1;
    assert(ec.toString() is null);
}
