module tanya.tests.format;

import tanya.format;
import tanya.range;

// Converting an integer to string.
@nogc nothrow pure @system unittest
{
    char[21] buf;

    assert(integral2String(80, buf) == "80");
    assert(integral2String(-80, buf) == "-80");
    assert(integral2String(0, buf) == "0");
    assert(integral2String(uint.max, buf) == "4294967295");
    assert(integral2String(int.min, buf) == "-2147483648");
}

// Doesn't print the first argument repeatedly
@nogc nothrow pure @safe unittest
{
    assert(format!"{}{}"(1, 2) == "12");
}

@nogc nothrow pure @safe unittest
{
    assert(format!"Without arguments"() == "Without arguments");
    assert(format!""().length == 0);

    static assert(!is(typeof(format!"{}"())));
    static assert(!is(typeof(format!"{j}"(5))));
}

// Enum
@nogc nothrow pure @safe unittest
{
    enum E1 : int
    {
        one,
        two,
    }
    assert(format!"{}"(E1.one) == "one");

    const E1 e1;
    assert(format!"{}"(e1) == "one");
}

// Modifiers
@nogc pure @safe unittest
{
    assert(format!"{}"(8.5) == "8.5");
    assert(format!"{}"(8.6) == "8.6");
    assert(format!"{}"(1000) == "1000");
    assert(format!"{}"(1) == "1");
    assert(format!"{}"(10.25) == "10.25");
    assert(format!"{}"(1) == "1");
    assert(format!"{}"(0.01) == "0.01");
}

// String printing
@nogc pure @safe unittest
{
    assert(format!"{}"("Some weired string") == "Some weired string");
    assert(format!"{}"(cast(string) null) == "");
    assert(format!"{}"('c') == "c");
}

// Integer
@nogc pure @safe unittest
{
    assert(format!"{}"(8) == "8");
    assert(format!"{}"(8) == "8");
    assert(format!"{}"(-8) == "-8");
    assert(format!"{}"(-8L) == "-8");
    assert(format!"{}"(8) == "8");
    assert(format!"{}"(100000001) == "100000001");
    assert(format!"{}"(99999999L) == "99999999");
    assert(format!"{}"(10) == "10");
    assert(format!"{}"(10L) == "10");
}

// Floating point
@nogc pure @safe unittest
{
    assert(format!"{}"(0.1234) == "0.1234");
    assert(format!"{}"(0.3) == "0.3");
    assert(format!"{}"(0.333333333333) == "0.333333");
    assert(format!"{}"(38234.1234) == "38234.1");
    assert(format!"{}"(-0.3) == "-0.3");
    assert(format!"{}"(0.000000000000000006) == "6e-18");
    assert(format!"{}"(0.0) == "0");
    assert(format!"{}"(double.init) == "NaN");
    assert(format!"{}"(-double.init) == "-NaN");
    assert(format!"{}"(double.infinity) == "Inf");
    assert(format!"{}"(-double.infinity) == "-Inf");
    assert(format!"{}"(0.000000000000000000000000003) == "3e-27");
    assert(format!"{}"(0.23432e304) == "2.3432e+303");
    assert(format!"{}"(-0.23432e8) == "-2.3432e+07");
    assert(format!"{}"(1e-307) == "1e-307");
    assert(format!"{}"(1e+8) == "1e+08");
    assert(format!"{}"(111234.1) == "111234");
    assert(format!"{}"(0.999) == "0.999");
    assert(format!"{}"(0x1p-16382L) == "0");
    assert(format!"{}"(1e+3) == "1000");
    assert(format!"{}"(38234.1234) == "38234.1");
    assert(format!"{}"(double.max) == "1.79769e+308");
}

// typeof(null)
@nogc pure @safe unittest
{
    assert(format!"{}"(null) == "null");
}

// Boolean
@nogc pure @safe unittest
{
    assert(format!"{}"(true) == "true");
    assert(format!"{}"(false) == "false");
}

// Unsafe tests with pointers
@nogc pure @system unittest
{
    // Pointer convesions
    assert(format!"{}"(cast(void*) 1) == "0x1");
    assert(format!"{}"(cast(void*) 20) == "0x14");
    assert(format!"{}"(cast(void*) null) == "0x0");
}

// Structs
@nogc pure @safe unittest
{
    static struct WithoutStringify1
    {
        int a;
        void func()
        {
        }
    }
    assert(format!"{}"(WithoutStringify1(6)) == "WithoutStringify1(6)");

    static struct WithoutStringify2
    {
    }
    assert(format!"{}"(WithoutStringify2()) == "WithoutStringify2()");

    static struct WithoutStringify3
    {
        int a = -2;
        int b = 8;
    }
    assert(format!"{}"(WithoutStringify3()) == "WithoutStringify3(-2, 8)");

    struct Nested
    {
        int i;

        void func()
        {
        }
    }
    assert(format!"{}"(Nested()) == "Nested(0)");

    static struct WithToString
    {
        OR toString(OR)(OR range) const
        {
            put(range, "toString method");
            return range;
        }
    }
    assert(format!"{}"(WithToString()) == "toString method");
}

// Aggregate types
@system unittest // Object.toString has no attributes.
{
    import tanya.memory.allocator;
    import tanya.memory.smartref;

    interface I
    {
    }
    class A : I
    {
    }
    auto instance = defaultAllocator.unique!A();
    assert(format!"{}"(instance.get()) == instance.get().toString());
    assert(format!"{}"(cast(I) instance.get()) == I.classinfo.name);
    assert(format!"{}"(cast(A) null) == "null");

    class B
    {
        OR toString(OR)(OR range) const
        {
            put(range, "Class B");
            return range;
        }
    }
    assert(format!"{}"(cast(B) null) == "null");
}

// Unions
unittest
{
    union U
    {
        int i;
        char c;
    }
    assert(format!"{}"(U(2)) == "U");
}

// Ranges
@nogc pure @safe unittest
{
    static struct Stringish
    {
        private string content = "Some content";

        immutable(char) front() const @nogc nothrow pure @safe
        {
            return this.content[0];
        }

        void popFront() @nogc nothrow pure @safe
        {
            this.content = this.content[1 .. $];
        }

        bool empty() const @nogc nothrow pure @safe
        {
            return this.content.length == 0;
        }
    }
    assert(format!"{}"(Stringish()) == "Some content");

    static struct Intish
    {
        private int front_ = 3;

        int front() const @nogc nothrow pure @safe
        {
            return this.front_;
        }

        void popFront() @nogc nothrow pure @safe
        {
            --this.front_;
        }

        bool empty() const @nogc nothrow pure @safe
        {
            return this.front == 0;
        }
    }
    assert(format!"{}"(Intish()) == "[3, 2, 1]");
}

// Typeid
nothrow @safe unittest
{
    assert(format!"{}"(typeid(int[])) == "int[]");

    class C
    {
    }
    assert(format!"{}"(typeid(C)) == typeid(C).toString());
}
