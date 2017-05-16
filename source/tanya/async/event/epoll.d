/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * Copyright: Eugene Wissner 2016-2017.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 */
module tanya.async.event.epoll;

version (linux):

public import core.sys.linux.epoll;
import tanya.async.protocol;
import tanya.async.event.selector;
import tanya.async.loop;
import tanya.async.transport;
import tanya.async.watcher;
import tanya.container.array;
import tanya.memory;
import tanya.memory.mmappool;
import tanya.network.socket;
import core.stdc.errno;
import core.sys.posix.unistd;
import core.time;
import std.algorithm.comparison;

extern (C) nothrow @nogc
{
    int epoll_create1(int flags);
    int epoll_ctl (int epfd, int op, int fd, epoll_event *event);
    int epoll_wait (int epfd, epoll_event *events, int maxevents, int timeout);
}

final class EpollLoop : SelectorLoop
{
    protected int fd;
    private Array!epoll_event events;

    /**
     * Initializes the loop.
     */
    this() @nogc
    {
        if ((fd = epoll_create1(EPOLL_CLOEXEC)) < 0)
        {
            throw defaultAllocator.make!BadLoopException("epoll initialization failed");
        }
        super();
        events = Array!epoll_event(maxEvents, MmapPool.instance);
    }

    /**
     * Frees loop internals.
     */
    ~this() @nogc
    {
        close(fd);
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
    protected override bool reify(SocketWatcher watcher,
                                  EventMask oldEvents,
                                  EventMask events) @nogc
    {
        int op = EPOLL_CTL_DEL;
        epoll_event ev;

        if (events == oldEvents)
        {
            return true;
        }
        if (events && oldEvents)
        {
            op = EPOLL_CTL_MOD;
        }
        else if (events && !oldEvents)
        {
            op = EPOLL_CTL_ADD;
        }

        ev.data.fd = watcher.socket.handle;
        ev.events = (events & (Event.read | Event.accept) ? EPOLLIN | EPOLLPRI : 0)
                  | (events & Event.write ? EPOLLOUT : 0)
                  | EPOLLET;

        return epoll_ctl(fd, op, watcher.socket.handle, &ev) == 0;
    }

    /**
     * Does the actual polling.
     */
    protected override void poll() @nogc
    {
        // Don't block
        immutable timeout = cast(immutable int) blockTime.total!"msecs";
        auto eventCount = epoll_wait(fd, events.get().ptr, maxEvents, timeout);

        if (eventCount < 0)
        {
            if (errno != EINTR)
            {
                throw defaultAllocator.make!BadLoopException();
            }
            return;
        }

        for (auto i = 0; i < eventCount; ++i)
        {
            auto transport = cast(StreamTransport) connections[events[i].data.fd];

            if (transport is null)
            {
                auto connection = cast(ConnectionWatcher) connections[events[i].data.fd];
                assert(connection !is null);

                acceptConnections(connection);
            }
            else if (events[i].events & EPOLLERR)
            {
                kill(transport);
                continue;
            }
            else if (events[i].events & (EPOLLIN | EPOLLPRI | EPOLLHUP))
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
                    continue;
                }
                else if (transport.output.length)
                {
                    pendings.enqueue(transport);
                }
            }
            if (events[i].events & EPOLLOUT)
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
    inout @safe pure nothrow
    {
        return min(super.blockTime, 1.dur!"seconds");
    }
}
