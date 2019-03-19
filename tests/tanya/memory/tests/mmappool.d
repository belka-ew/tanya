/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */
module tanya.memory.tests.mmappool;

version (TanyaNative):

import tanya.memory.mmappool;

@nogc nothrow pure @system unittest
{
    auto p = MmapPool.instance.allocate(20);
    assert(p);
    MmapPool.instance.deallocate(p);

    p = MmapPool.instance.allocate(0);
    assert(p.length == 0);
}

@nogc nothrow pure @system unittest
{
    // allocate() check.
    size_t tooMuchMemory = size_t.max
                         - MmapPool.alignment_
                         - BlockEntry.sizeof * 2
                         - RegionEntry.sizeof
                         - pageSize;
    assert(MmapPool.instance.allocate(tooMuchMemory) is null);

    assert(MmapPool.instance.allocate(size_t.max) is null);

    // initializeRegion() check.
    tooMuchMemory = size_t.max - MmapPool.alignment_;
    assert(MmapPool.instance.allocate(tooMuchMemory) is null);
}

@nogc nothrow pure @system unittest
{
    auto p = MmapPool.instance.allocate(20);

    assert(MmapPool.instance.deallocate(p));
}

@nogc nothrow pure @system unittest
{
    void[] p;
    assert(!MmapPool.instance.reallocateInPlace(p, 5));
    assert(p is null);

    p = MmapPool.instance.allocate(1);
    auto orig = p.ptr;

    assert(MmapPool.instance.reallocateInPlace(p, 2));
    assert(p.length == 2);
    assert(p.ptr == orig);

    assert(MmapPool.instance.reallocateInPlace(p, 4));
    assert(p.length == 4);
    assert(p.ptr == orig);

    assert(MmapPool.instance.reallocateInPlace(p, 2));
    assert(p.length == 2);
    assert(p.ptr == orig);

    MmapPool.instance.deallocate(p);
}

@nogc nothrow pure @system unittest
{
    void[] p;
    MmapPool.instance.reallocate(p, 10 * int.sizeof);
    (cast(int[]) p)[7] = 123;

    assert(p.length == 40);

    MmapPool.instance.reallocate(p, 8 * int.sizeof);

    assert(p.length == 32);
    assert((cast(int[]) p)[7] == 123);

    MmapPool.instance.reallocate(p, 20 * int.sizeof);
    (cast(int[]) p)[15] = 8;

    assert(p.length == 80);
    assert((cast(int[]) p)[15] == 8);
    assert((cast(int[]) p)[7] == 123);

    MmapPool.instance.reallocate(p, 8 * int.sizeof);

    assert(p.length == 32);
    assert((cast(int[]) p)[7] == 123);

    MmapPool.instance.deallocate(p);
}

@nogc nothrow pure @system unittest
{
    assert(instance is instance);
}

@nogc nothrow pure @system unittest
{
    assert(MmapPool.instance.alignment == MmapPool.alignment_);
}

// A lot of allocations/deallocations, but it is the minimum caused a
// segmentation fault because MmapPool reallocateInPlace moves a block wrong.
@nogc nothrow pure @system unittest
{
    auto a = MmapPool.instance.allocate(16);
    auto d = MmapPool.instance.allocate(16);
    auto b = MmapPool.instance.allocate(16);
    auto e = MmapPool.instance.allocate(16);
    auto c = MmapPool.instance.allocate(16);
    auto f = MmapPool.instance.allocate(16);

    MmapPool.instance.deallocate(a);
    MmapPool.instance.deallocate(b);
    MmapPool.instance.deallocate(c);

    a = MmapPool.instance.allocate(50);
    MmapPool.instance.reallocateInPlace(a, 64);
    MmapPool.instance.deallocate(a);

    a = MmapPool.instance.allocate(1);
    auto tmp1 = MmapPool.instance.allocate(1);
    auto h1 = MmapPool.instance.allocate(1);
    auto tmp2 = cast(ubyte[]) MmapPool.instance.allocate(1);

    auto h2 = MmapPool.instance.allocate(2);
    tmp1 = MmapPool.instance.allocate(1);
    MmapPool.instance.deallocate(h2);
    MmapPool.instance.deallocate(h1);

    h2 = MmapPool.instance.allocate(2);
    h1 = MmapPool.instance.allocate(1);
    MmapPool.instance.deallocate(h2);

    auto rep = cast(void[]) tmp2;
    MmapPool.instance.reallocate(rep, tmp1.length);
    tmp2 = cast(ubyte[]) rep;

    MmapPool.instance.reallocate(tmp1, 9);

    rep = cast(void[]) tmp2;
    MmapPool.instance.reallocate(rep, tmp1.length);
    tmp2 = cast(ubyte[]) rep;
    MmapPool.instance.reallocate(tmp1, 17);

    tmp2[$ - 1] = 0;

    MmapPool.instance.deallocate(tmp1);

    b = MmapPool.instance.allocate(16);

    MmapPool.instance.deallocate(h1);
    MmapPool.instance.deallocate(a);
    MmapPool.instance.deallocate(b);
    MmapPool.instance.deallocate(d);
    MmapPool.instance.deallocate(e);
    MmapPool.instance.deallocate(f);
}
