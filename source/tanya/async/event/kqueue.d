/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * Copyright: Eugene Wissner 2016-2017.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 */
module tanya.async.event.kqueue;

version (OSX)
{
    version = MacBSD;
}
else version (iOS)
{
    version = MacBSD;
}
else version (TVOS)
{
    version = MacBSD;
}
else version (WatchOS)
{
    version = MacBSD;
}
else version (FreeBSD)
{
    version = MacBSD;
}
else version (OpenBSD)
{
    version = MacBSD;
}
else version (DragonFlyBSD)
{
    version = MacBSD;
}

version (MacBSD):

import core.stdc.errno;
import core.sys.posix.time; // timespec
import core.sys.posix.unistd;
import core.time;
import std.algorithm.comparison;
import tanya.async.event.selector;
import tanya.async.loop;
import tanya.async.transport;
import tanya.async.watcher;
import tanya.container.array;
import tanya.memory;
import tanya.memory.mmappool;
import tanya.network.socket;

void EV_SET(kevent_t* kevp, typeof(kevent_t.tupleof) args) pure nothrow @nogc
{
    *kevp = kevent_t(args);
}

enum : short
{
    EVFILT_READ     =  -1,
    EVFILT_WRITE    =  -2,
    EVFILT_AIO      =  -3, /* attached to aio requests */
    EVFILT_VNODE    =  -4, /* attached to vnodes */
    EVFILT_PROC     =  -5, /* attached to struct proc */
    EVFILT_SIGNAL   =  -6, /* attached to struct proc */
    EVFILT_TIMER    =  -7, /* timers */
    EVFILT_MACHPORT =  -8, /* Mach portsets */
    EVFILT_FS       =  -9, /* filesystem events */
    EVFILT_USER     = -10, /* User events */
    EVFILT_VM       = -12, /* virtual memory events */
    EVFILT_SYSCOUNT =  11
}

struct kevent_t
{
    uintptr_t    ident; /* identifier for this event */
    short       filter; /* filter for event */
    ushort       flags;
    uint        fflags;
    intptr_t      data;
    void        *udata; /* opaque user data identifier */
}

enum
{
    /* actions */
    EV_ADD      = 0x0001, /* add event to kq (implies enable) */
    EV_DELETE   = 0x0002, /* delete event from kq */
    EV_ENABLE   = 0x0004, /* enable event */
    EV_DISABLE  = 0x0008, /* disable event (not reported) */

    /* flags */
    EV_ONESHOT  = 0x0010, /* only report one occurrence */
    EV_CLEAR    = 0x0020, /* clear event state after reporting */
    EV_RECEIPT  = 0x0040, /* force EV_ERROR on success, data=0 */
    EV_DISPATCH = 0x0080, /* disable event after reporting */

    EV_SYSFLAGS = 0xF000, /* reserved by system */
    EV_FLAG1    = 0x2000, /* filter-specific flag */

    /* returned values */
    EV_EOF      = 0x8000, /* EOF detected */
    EV_ERROR    = 0x4000, /* error, data contains errno */
}

extern(C) int kqueue() nothrow @nogc;
extern(C) int kevent(int kq, const kevent_t *changelist, int nchanges,
                     kevent_t *eventlist, int nevents, const timespec *timeout)
                     nothrow @nogc;

final class KqueueLoop : SelectorLoop
{
    protected int fd;
    private Array!kevent_t events;
    private Array!kevent_t changes;
    private size_t changeCount;

    /**
     * Returns: Maximal event count can be got at a time
     *          (should be supported by the backend).
     */
    override protected @property uint maxEvents()
    const pure nothrow @safe @nogc
    {
        return cast(uint) events.length;
    }

    this() @nogc
    {
        super();

        if ((fd = kqueue()) == -1)
        {
            throw make!BadLoopException(defaultAllocator,
                                        "kqueue initialization failed");
        }
        events = Array!kevent_t(64, MmapPool.instance);
        changes = Array!kevent_t(64, MmapPool.instance);
    }

    /**
     * Frees loop internals.
     */
    ~this() @nogc
    {
        close(fd);
    }

    private void set(socket_t socket, short filter, ushort flags) @nogc
    {
        if (changes.length <= changeCount)
        {
            changes.length = changeCount + maxEvents;
        }
        EV_SET(&changes[changeCount],
               cast(ulong) socket,
               filter,
               flags,
               0U,
               0L,
               null);
        ++changeCount;
    }

    /**
     * Should be called if the backend configuration changes.
     *
     * Params:
     * 	watcher   = Watcher.
     * 	oldEvents = The events were already set.
     * 	events    = The events should be set.
     *
     * Returns: $(D_KEYWORD true) if the operation was successful.
     */
    override protected bool reify(SocketWatcher watcher,
                                  EventMask oldEvents,
                                  EventMask events) @nogc
    {
        if (events != oldEvents)
        {
            if (oldEvents & Event.read || oldEvents & Event.accept)
            {
                set(watcher.socket.handle, EVFILT_READ, EV_DELETE);
            }
            if (oldEvents & Event.write)
            {
                set(watcher.socket.handle, EVFILT_WRITE, EV_DELETE);
            }
        }
        if (events & (Event.read | events & Event.accept))
        {
            set(watcher.socket.handle, EVFILT_READ, EV_ADD | EV_ENABLE);
        }
        if (events & Event.write)
        {
            set(watcher.socket.handle, EVFILT_WRITE, EV_ADD | EV_DISPATCH);
        }
        return true;
    }

    /**
     * Does the actual polling.
     */
    protected override void poll() @nogc
    {
        timespec ts;
        blockTime.split!("seconds", "nsecs")(ts.tv_sec, ts.tv_nsec);

        if (changeCount > maxEvents) 
        {
            events.length = changes.length;
        }

        auto eventCount = kevent(fd,
                                 changes.get().ptr,
                                 cast(int) changeCount,
                                 events.get().ptr,
                                 maxEvents,
                                 &ts);
        changeCount = 0;

        if (eventCount < 0)
        {
            if (errno != EINTR)
            {
                throw defaultAllocator.make!BadLoopException();
            }
            return;
        }

        for (int i; i < eventCount; ++i)
        {
            assert(connections.length > events[i].ident);

            auto transport = cast(StreamTransport) connections[events[i].ident];
            // If it is a ConnectionWatcher. Accept connections.
            if (transport is null)
            {
                auto connection = cast(ConnectionWatcher) connections[events[i].ident];
                assert(connection !is null);

                acceptConnections(connection);
            }
            else if (events[i].flags & EV_ERROR)
            {
                kill(transport);
            }
            else if (events[i].filter == EVFILT_READ)
            {
                SocketException exception;
                try
                {
                    ptrdiff_t received;
                    do
                    {
                        received = transport.socket.receive(transport.output[]);
                        transport.output += received;
                    }
                    while (received);
                }
                catch (SocketException e)
                {
                    exception = e;
                }
                if (transport.socket.disconnected)
                {
                    kill(transport, exception);
                }
                else if (transport.output.length)
                {
                    pendings.enqueue(transport);
                }
            }
            else if (events[i].filter == EVFILT_WRITE)
            {
                transport.writeReady = true;
                if (transport.input.length)
                {
                    feed(transport);
                }
            }
        }
    }

    /**
     * Returns: The blocking time.
     */
    override protected @property inout(Duration) blockTime()
    inout @nogc @safe pure nothrow
    {
        return min(super.blockTime, 1.dur!"seconds");
    }

    /**
     * If the transport couldn't send the data, the further sending should
     * be handled by the event loop.
     *
     * Params:
     * 	transport = Transport.
     * 	exception = Exception thrown on sending.
     *
     * Returns: $(D_KEYWORD true) if the operation could be successfully
     *          completed or scheduled, $(D_KEYWORD false) otherwise (the
     *          transport will be destroyed then).
     */
    protected override bool feed(StreamTransport transport,
                                 SocketException exception = null) @nogc
    {
        if (!super.feed(transport, exception))
        {
            return false;
        }
        if (!transport.writeReady)
        {
            set(transport.socket.handle, EVFILT_WRITE, EV_DISPATCH);
            return true;
        }
        return false;
    }
}
