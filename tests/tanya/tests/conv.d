module tanya.tests.conv;

import tanya.conv;
import tanya.range;
import tanya.test.assertion;
import tanya.test.stub;

// ':' is not a hex value
@nogc nothrow pure @safe unittest
{
    string colon = ":";
    auto actual = readIntegral!ubyte(colon, 16);
    assert(actual == 0);
    assert(colon.length == 1);
}

// reads ubyte.max
@nogc nothrow pure @safe unittest
{
    string number = "255";
    assert(readIntegral!ubyte(number) == 255);
    assert(number.empty);
}

// detects integer overflow
@nogc nothrow pure @safe unittest
{
    string number = "500";
    readIntegral!ubyte(number);
    assert(number.front == '0');
    assert(number.length == 1);
}

// stops on a non-digit
@nogc nothrow pure @safe unittest
{
    string number = "10-";
    readIntegral!ubyte(number);
    assert(number.front == '-');
}

// returns false if the number string is empty
@nogc nothrow pure @safe unittest
{
    string number = "";
    readIntegral!ubyte(number);
    assert(number.empty);
}

@nogc nothrow pure @safe unittest
{
    string number = "29";
    assert(readIntegral!ubyte(number) == 29);
    assert(number.empty);
}

@nogc nothrow pure @safe unittest
{
    string number = "25467";
    readIntegral!ubyte(number);
    assert(number.front == '6');
}

// Converts lower case hexadecimals
@nogc nothrow pure @safe unittest
{
    string number = "a";
    assert(readIntegral!ubyte(number, 16) == 10);
    assert(number.empty);
}

// Converts upper case hexadecimals
@nogc nothrow pure @safe unittest
{
    string number = "FF";
    assert(readIntegral!ubyte(number, 16) == 255);
    assert(number.empty);
}

// Handles small overflows
@nogc nothrow pure @safe unittest
{
    string number = "256";
    assert(readIntegral!ubyte(number, 10) == 25);
    assert(number.front == '6');
}

@nogc nothrow pure @safe unittest
{
    int val = 5;
    assert(val.to!int() == 5);
}

@nogc nothrow pure @safe unittest
{
    // ubyte -> ushort
    assert((cast(ubyte) 0).to!ushort == 0);
    assert((cast(ubyte) 1).to!ushort == 1);
    assert((cast(ubyte) (ubyte.max - 1)).to!ushort == ubyte.max - 1);
    assert((cast(ubyte) ubyte.max).to!ushort == ubyte.max);

    // ubyte -> short
    assert((cast(ubyte) 0).to!short == 0);
    assert((cast(ubyte) 1).to!short == 1);
    assert((cast(ubyte) (ubyte.max - 1)).to!short == ubyte.max - 1);
    assert((cast(ubyte) ubyte.max).to!short == ubyte.max);
}

@nogc pure @safe unittest
{
    // ubyte <- ushort
    assert((cast(ushort) 0).to!ubyte == 0);
    assert((cast(ushort) 1).to!ubyte == 1);
    assert((cast(ushort) (ubyte.max - 1)).to!ubyte == ubyte.max - 1);
    assert((cast(ushort) ubyte.max).to!ubyte == ubyte.max);

    // ubyte <- short
    assert((cast(short) 0).to!ubyte == 0);
    assert((cast(short) 1).to!ubyte == 1);
    assert((cast(short) (ubyte.max - 1)).to!ubyte == ubyte.max - 1);
    assert((cast(short) ubyte.max).to!ubyte == ubyte.max);

    // short <-> int
    assert(short.min.to!int == short.min);
    assert((short.min + 1).to!int == short.min + 1);
    assert((cast(short) -1).to!int == -1);
    assert((cast(short) 0).to!int == 0);
    assert((cast(short) 1).to!int == 1);
    assert((short.max - 1).to!int == short.max - 1);
    assert(short.max.to!int == short.max);

    assert((cast(int) short.min).to!short == short.min);
    assert((cast(int) short.min + 1).to!short == short.min + 1);
    assert((cast(int) -1).to!short == -1);
    assert((cast(int) 0).to!short == 0);
    assert((cast(int) 1).to!short == 1);
    assert((cast(int) short.max - 1).to!short == short.max - 1);
    assert((cast(int) short.max).to!short == short.max);

    // uint <-> int
    assert((cast(uint) 0).to!int == 0);
    assert((cast(uint) 1).to!int == 1);
    assert((cast(uint) (int.max - 1)).to!int == int.max - 1);
    assert((cast(uint) int.max).to!int == int.max);

    assert((cast(int) 0).to!uint == 0);
    assert((cast(int) 1).to!uint == 1);
    assert((cast(int) (int.max - 1)).to!uint == int.max - 1);
    assert((cast(int) int.max).to!uint == int.max);
}

@nogc pure @safe unittest
{
    assertThrown!ConvException(&to!(short, int), int.min);
    assertThrown!ConvException(&to!(short, int), int.max);
    assertThrown!ConvException(&to!(ushort, uint), uint.max);
    assertThrown!ConvException(&to!(uint, int), -1);
}

@nogc nothrow pure @safe unittest
{
    enum Test : int
    {
        one,
        two,
    }
    assert(Test.one.to!int == 0);
    assert(Test.two.to!int == 1);
}

@nogc pure @safe unittest
{
    assertThrown!ConvException(&to!(int, double), 2147483647.5);
    assertThrown!ConvException(&to!(int, double), -2147483648.5);
    assertThrown!ConvException(&to!(uint, double), -21474.5);
}

@nogc pure @safe unittest
{
    enum Test : uint
    {
        one,
        two,
    }
    assertThrown!ConvException(&to!(Test, int), 5);
}

@nogc pure @safe unittest
{
    assertThrown!ConvException(&to!(bool, int), -1);
    assertThrown!ConvException(&to!(bool, int), 2);
}

@nogc pure @safe unittest
{
    assertThrown!ConvException(() => "1".to!bool);
}

@nogc pure @safe unittest
{
    assertThrown!ConvException(() => "".to!int);
    assertThrown!ConvException(() => "-".to!int);
    assertThrown!ConvException(() => "-5".to!uint);
    assertThrown!ConvException(() => "-129".to!byte);
    assertThrown!ConvException(() => "256".to!ubyte);
}
