module tanya.meta.tests.metafunction;

import tanya.meta.metafunction;

@nogc nothrow pure @safe unittest
{
    enum cmp(int x, int y) = x - y;
    static assert(isSorted!(cmp));
    static assert(isSorted!(cmp, 1));
    static assert(isSorted!(cmp, 1, 2, 2));
    static assert(isSorted!(cmp, 1, 2, 2, 4));
    static assert(isSorted!(cmp, 1, 2, 2, 4, 8));
    static assert(!isSorted!(cmp, 32, 2, 2, 4, 8));
    static assert(isSorted!(cmp, 32, 32));
}

@nogc nothrow pure @safe unittest
{
    enum cmp(int x, int y) = x < y;
    static assert(isSorted!(cmp));
    static assert(isSorted!(cmp, 1));
    static assert(isSorted!(cmp, 1, 2, 2));
    static assert(isSorted!(cmp, 1, 2, 2, 4));
    static assert(isSorted!(cmp, 1, 2, 2, 4, 8));
    static assert(!isSorted!(cmp, 32, 2, 2, 4, 8));
    static assert(isSorted!(cmp, 32, 32));
}
