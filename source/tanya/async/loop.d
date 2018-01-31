/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * Interface for the event loop implementations and the default event loop
 * chooser.
 *
 * ---
 * import tanya.async;
 * import tanya.memory;
 * import tanya.network.socket;
 *
 * class EchoProtocol : TransmissionControlProtocol
 * {
 *  private DuplexTransport transport;
 *
 *  void received(in ubyte[] data) @nogc
 *  {
 *      transport.write(data);
 *  }
 *
 *  void connected(DuplexTransport transport) @nogc
 *  {
 *      this.transport = transport;
 *  }
 *
 *  void disconnected(SocketException e) @nogc
 *  {
 *  }
 * }
 *
 * void main()
 * {
 *  auto address = defaultAllocator.make!InternetAddress("127.0.0.1", cast(ushort) 8192);
 *
 *  version (Windows)
 *  {
 *      auto sock = defaultAllocator.make!OverlappedStreamSocket(AddressFamily.inet);
 *  }
 *  else
 *  {
 *      auto sock = defaultAllocator.make!StreamSocket(AddressFamily.inet);
 *      sock.blocking = false;
 *  }
 *
 *  sock.bind(address);
 *  sock.listen(5);
 *
 *  auto io = defaultAllocator.make!ConnectionWatcher(sock);
 *  io.setProtocol!EchoProtocol;
 *
 *  defaultLoop.start(io);
 *  defaultLoop.run();
 *
 *  sock.shutdown();
 *  defaultAllocator.dispose(io);
 *  defaultAllocator.dispose(sock);
 *  defaultAllocator.dispose(address);
 * }
 * ---
 *
 * Copyright: Eugene Wissner 2016-2017.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 * Source: $(LINK2 https://github.com/caraus-ecms/tanya/blob/master/source/tanya/async/loop.d,
 *                 tanya/async/loop.d)
 */
module tanya.async.loop;

import core.time;
import std.algorithm.iteration;
import std.algorithm.mutation;
import std.typecons;
import tanya.async.transport;
import tanya.async.watcher;
import tanya.container.buffer;
import tanya.container.queue;
import tanya.memory;
import tanya.memory.mmappool;
import tanya.network.socket;

version (DisableBackends)
{
}
else version (D_Ddoc)
{
}
else version (linux)
{
    import tanya.async.event.epoll;
    version = Epoll;
}
else version (Windows)
{
    import tanya.async.event.iocp;
    version = IOCP;
}
else version (OSX)
{
    version = Kqueue;
}
else version (iOS)
{
    version = Kqueue;
}
else version (FreeBSD)
{
    version = Kqueue;
}
else version (OpenBSD)
{
    version = Kqueue;
}
else version (DragonFlyBSD)
{
    version = Kqueue;
}
version (unittest)
{
    final class TestLoop : Loop
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
    }
}

/**
 * Events.
 */
enum Event : uint
{
    none   = 0x00,       /// No events.
    read   = 0x01,       /// Non-blocking read call.
    write  = 0x02,       /// Non-blocking write call.
    accept = 0x04,       /// Connection made.
    error  = 0x80000000, /// Sent when an error occurs.
}

alias EventMask = BitFlags!Event;

/**
 * Event loop.
 */
abstract class Loop
{
    private bool done = true;

    /// Pending watchers.
    protected Queue!Watcher pendings;

    /**
     * Returns: Maximal event count can be got at a time
     *          (should be supported by the backend).
     */
    protected @property uint maxEvents()
    const pure nothrow @safe @nogc
    {
        return 128U;
    }

    private unittest
    {
        auto loop = defaultAllocator.make!TestLoop;
        assert(loop.maxEvents == 64);

        defaultAllocator.dispose(loop);
    }

    /**
     * Initializes the loop.
     */
    this() @nogc
    {
        pendings = Queue!Watcher(MmapPool.instance);
    }

    /**
     * Frees loop internals.
     */
    ~this() @nogc
    {
        foreach (w; pendings)
        {
            MmapPool.instance.dispose(w);
        }
    }

    /**
     * Starts the loop.
     */
    void run() @nogc
    {
        this.done = false;
        do
        {
            poll();

            // Invoke pendings
            foreach (ref w; this.pendings)
            {
                w.invoke();
            }
        }
        while (!this.done);
    }

    /**
     * Break out of the loop.
     */
    void unloop() @safe pure nothrow @nogc
    {
        this.done = true;
    }

    private unittest
    {
        auto loop = defaultAllocator.make!TestLoop;
        assert(loop.done);

        loop.run();
        assert(loop.done);

        defaultAllocator.dispose(loop);
    }

    private unittest
    {
        auto loop = defaultAllocator.make!TestLoop;
        auto watcher = defaultAllocator.make!DummyWatcher;
        loop.pendings.enqueue(watcher);

        assert(!watcher.invoked);
        loop.run();
        assert(watcher.invoked);

        defaultAllocator.dispose(loop);
        defaultAllocator.dispose(watcher);
    }

    /**
     * Start watching.
     *
     * Params:
     *  watcher = Watcher.
     */
    void start(ConnectionWatcher watcher) @nogc
    {
        if (watcher.active)
        {
            return;
        }
        watcher.active = true;

        reify(watcher, EventMask(Event.none), EventMask(Event.accept));
    }

    /**
     * Stop watching.
     *
     * Params:
     *  watcher = Watcher.
     */
    void stop(ConnectionWatcher watcher) @nogc
    {
        if (!watcher.active)
        {
            return;
        }
        watcher.active = false;

        reify(watcher, EventMask(Event.accept), EventMask(Event.none));
    }

    /**
     * Should be called if the backend configuration changes.
     *
     * Params:
     *  watcher   = Watcher.
     *  oldEvents = The events were already set.
     *  events    = The events should be set.
     *
     * Returns: $(D_KEYWORD true) if the operation was successful.
     */
    abstract protected bool reify(SocketWatcher watcher,
                                  EventMask oldEvents,
                                  EventMask events) @nogc;

    /**
     * Returns: The blocking time.
     */
    protected @property inout(Duration) blockTime()
    inout @safe pure nothrow @nogc
    {
        // Don't block if we have to do.
        return pendings.empty ? blockTime_ : Duration.zero;
    }

    /**
     * Sets the blocking time for IO watchers.
     *
     * Params:
     *  blockTime = The blocking time. Cannot be larger than
     *              $(D_PSYMBOL maxBlockTime).
     */
    protected @property void blockTime(in Duration blockTime) @safe pure nothrow @nogc
    in
    {
        assert(blockTime <= 1.dur!"hours", "Too long to wait.");
        assert(!blockTime.isNegative);
    }
    do
    {
        blockTime_ = blockTime;
    }

    private unittest
    {
        auto loop = defaultAllocator.make!TestLoop;
        assert(loop.blockTime == 1.dur!"minutes");

        loop.blockTime = 2.dur!"minutes";
        assert(loop.blockTime == 2.dur!"minutes");

        defaultAllocator.dispose(loop);
    }

    /**
     * Does the actual polling.
     */
    abstract protected void poll() @nogc;

    /// Maximal block time.
    protected Duration blockTime_ = 1.dur!"minutes";
}

/**
 * Exception thrown on errors in the event loop.
 */
class BadLoopException : Exception
{
    /**
     * Params:
     *  file = The file where the exception occurred.
     *  line = The line number where the exception occurred.
     *  next = The previous exception in the chain of exceptions, if any.
     */
    this(string file = __FILE__, size_t line = __LINE__, Throwable next = null)
    pure nothrow const @safe @nogc
    {
        super("Event loop cannot be initialized.", file, line, next);
    }
}

/**
 * Returns the event loop used by default. If an event loop wasn't set with
 * $(D_PSYMBOL defaultLoop) before, $(D_PSYMBOL defaultLoop) will try to
 * choose an event loop supported on the system.
 *
 * Returns: The default event loop.
 */
@property Loop defaultLoop() @nogc
{
    if (defaultLoop_ !is null)
    {
        return defaultLoop_;
    }
    version (Epoll)
    {
        defaultLoop_ = MmapPool.instance.make!EpollLoop;
    }
    else version (IOCP)
    {
        defaultLoop_ = MmapPool.instance.make!IOCPLoop;
    }
    else version (Kqueue)
    {
        import tanya.async.event.kqueue;
        defaultLoop_ = MmapPool.instance.make!KqueueLoop;
    }
    return defaultLoop_;
}

/**
 * Sets the default event loop.
 *
 * This property makes it possible to implement your own backends or event
 * loops, for example, if the system is not supported or if you want to
 * extend the supported implementation. Just extend $(D_PSYMBOL Loop) and pass
 * your implementation to this property.
 *
 * Params:
 *  loop = The event loop.
 */
@property void defaultLoop(Loop loop) @nogc
in
{
    assert(loop !is null);
}
do
{
    defaultLoop_ = loop;
}

private Loop defaultLoop_;

private unittest
{
    auto oldLoop = defaultLoop_;
    auto loop = defaultAllocator.make!TestLoop;

    defaultLoop = loop;
    assert(defaultLoop_ is loop);
    assert(defaultLoop is loop);

    defaultLoop_ = oldLoop;
    defaultAllocator.dispose(loop);
}
