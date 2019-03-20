/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */
module tanya.async.tests.loop;

import core.time;
import tanya.async.loop;
import tanya.async.watcher;
import tanya.memory;

private final class DummyWatcher : Watcher
{
    bool invoked;

    override void invoke() @nogc
    {
        this.invoked = true;
    }
}

private final class TestLoop : Loop
{
    override protected bool reify(SocketWatcher watcher,
                                  EventMask oldEvents,
                                  EventMask events) @nogc
    {
        return true;
    }

    override protected void poll() @nogc
    {
        assert(!this.done);
        unloop();
    }

    override protected @property uint maxEvents()
    const pure nothrow @safe @nogc
    {
        return 64U;
    }

    @nogc @system unittest
    {
        auto loop = defaultAllocator.make!TestLoop;
        assert(loop.blockTime == 1.dur!"minutes");

        loop.blockTime = 2.dur!"minutes";
        assert(loop.blockTime == 2.dur!"minutes");

        defaultAllocator.dispose(loop);
    }

    @nogc @system unittest
    {
        auto loop = defaultAllocator.make!TestLoop;
        assert(loop.done);

        loop.run();
        assert(loop.done);

        defaultAllocator.dispose(loop);
    }

    @nogc @system unittest
    {
        auto loop = defaultAllocator.make!TestLoop;
        auto watcher = defaultAllocator.make!DummyWatcher;
        loop.pendings.insertBack(watcher);

        assert(!watcher.invoked);
        loop.run();
        assert(watcher.invoked);

        defaultAllocator.dispose(loop);
        defaultAllocator.dispose(watcher);
    }
}

@nogc @system unittest
{
    auto loop = defaultAllocator.make!TestLoop;
    assert(loop.maxEvents == 64);

    defaultAllocator.dispose(loop);
}

@nogc @system unittest
{
    auto oldLoop = defaultLoop;
    auto loop = defaultAllocator.make!TestLoop;

    defaultLoop = loop;
    assert(defaultLoop is loop);

    defaultLoop = oldLoop;
    defaultAllocator.dispose(loop);
}
