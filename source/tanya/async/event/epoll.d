/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * Copyright: Eugene Wissner 2016.
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

class EpollLoop : SelectorLoop
{
	protected int fd;
	private epoll_event[] events;

	/**
	 * Initializes the loop.
	 */
	this() @nogc
	{
		if ((fd = epoll_create1(EPOLL_CLOEXEC)) < 0)
		{
			throw MmapPool.instance.make!BadLoopException("epoll initialization failed");
		}
		super();
		MmapPool.instance.resizeArray(events, maxEvents);
	}

	/**
	 * Free loop internals.
	 */
	~this() @nogc
	{
		MmapPool.instance.dispose(events);
		close(fd);
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
	protected override bool reify(ConnectionWatcher watcher,
	                              EventMask oldEvents,
	                              EventMask events) @nogc
	in
	{
		assert(watcher !is null);
	}
	body
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
		auto eventCount = epoll_wait(fd, events.ptr, maxEvents, timeout);

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
			auto io = cast(IOWatcher) connections[events[i].data.fd];

			if (io is null)
			{
				acceptConnections(connections[events[i].data.fd]);
			}
			else if (events[i].events & EPOLLERR)
			{
				kill(io, null);
			}
			else if (events[i].events & (EPOLLIN | EPOLLPRI | EPOLLHUP))
			{
				auto transport = cast(SelectorStreamTransport) io.transport;
				assert(transport !is null);

				SocketException exception;
				try
				{
					ptrdiff_t received;
					do
					{
						received = transport.socket.receive(io.output[]);
						io.output += received;
					}
					while (received);
				}
				catch (SocketException e)
				{
					exception = e;
				}
				if (transport.socket.disconnected)
				{
					kill(io, exception);
				}
				else if (io.output.length)
				{
					pendings.enqueue(io);
				}
			}
			else if (events[i].events & EPOLLOUT)
			{
				auto transport = cast(SelectorStreamTransport) io.transport;
				assert(transport !is null);

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
