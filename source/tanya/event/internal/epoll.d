/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * Copyright: Eugene Wissner 2016.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:belka@caraus.de, Eugene Wissner)
 */  
module tanya.event.internal.epoll;

import tanya.event.config;

static if (UseEpoll):

public import core.sys.linux.epoll;
import tanya.event.internal.selector;
import tanya.event.protocol;
import tanya.event.transport;
import tanya.event.watcher;
import tanya.event.loop;
import tanya.container.list;
import tanya.memory;
import core.stdc.errno;
import core.sys.posix.fcntl;
import core.sys.posix.netinet.in_;
import core.time;
import std.algorithm.comparison;

extern (C) nothrow
{ // TODO: Make a pull request for Phobos to mark this extern functions as @nogc.
    int epoll_create1(int __flags);
    int epoll_ctl(int __epfd, int __op, int __fd, epoll_event *__event);
    int epoll_wait(int __epfd, epoll_event *__events, int __maxevents, int __timeout);
	int accept4(int, sockaddr*, socklen_t*, int flags);
}

private enum maxEvents = 128;

class EpollLoop : Loop
{
	/**
	 * Initializes the loop.
	 */
	this()
	{
		super();

		if ((fd = epoll_create1(EPOLL_CLOEXEC)) < 0)
		{
			return;
		}
		epollEvents = makeArray!epoll_event(defaultAllocator, maxEvents).ptr;
	}

	/**
	 * Frees loop internals.
	 */
	~this()
	{
		dispose(defaultAllocator, epollEvents);
	}

	/**
	 * Should be called if the backend configuration changes.
	 *
	 * Params:
	 * 	socket    = Socket.
	 * 	oldEvents = The events were already set.
	 * 	events    = The events should be set.
	 *
	 * Returns: $(D_KEYWORD true) if the operation was successful.
	 */
	protected override bool modify(int socket, EventMask oldEvents, EventMask events)
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

		ev.data.fd = socket;
		ev.events = (events & (Event.read | Event.accept) ? EPOLLIN | EPOLLPRI : 0)
		          | (events & Event.write ? EPOLLOUT : 0)
		          | EPOLLET;

		return epoll_ctl(fd, op, socket, &ev) == 0;
	}

	/**
	 * Accept incoming connections.
	 *
	 * Params:
	 * 	protocolFactory = Protocol factory.
	 * 	socket          = Socket.
	 */
	protected override void acceptConnection(Protocol delegate() protocolFactory,
	                                         int socket)
	{
		sockaddr_in client_addr;
		socklen_t client_len = client_addr.sizeof;
		int client = accept4(socket,
		                     cast(sockaddr *)&client_addr,
		                     &client_len,
		                     O_NONBLOCK);
		while (client >= 0)
		{
			auto transport = make!SocketTransport(defaultAllocator, this, client);
			IOWatcher connection;

			if (connections.length > client)
			{
				connection = cast(IOWatcher) connections[client];
				// If it is a ConnectionWatcher
				if (connection is null && connections[client] !is null)
				{
					dispose(defaultAllocator, connections[client]);
					connections[client] = null;
				}
			}
			if (connection !is null)
			{
				connection(protocolFactory, transport);
			}
			else
			{
				connections[client] = make!IOWatcher(defaultAllocator,
				                                     protocolFactory,
				                                     transport);
			}

			modify(client, EventMask(Event.none), EventMask(Event.read, Event.write));

			swapPendings.insertBack(connections[client]);

			client = accept4(socket,
			                 cast(sockaddr *)&client_addr,
			                 &client_len,
			                 O_NONBLOCK);
		}
	}

	/**
	 * Does the actual polling.
	 */
	protected override void poll()
	{
		// Don't block
		immutable timeout = cast(immutable int) blockTime.total!"msecs";
		auto eventCount = epoll_wait(fd, epollEvents, maxEvents, timeout);

		if (eventCount < 0)
		{
			if (errno != EINTR)
			{
				throw make!BadLoopException(defaultAllocator);
			}

			return;
		}

		for (auto i = 0; i < eventCount; ++i)
		{
			epoll_event *ev = epollEvents + i;
			auto connection = cast(IOWatcher) connections[ev.data.fd];

			if (connection is null)
			{
				swapPendings.insertBack(connections[ev.data.fd]);
//				acceptConnection(connections[ev.data.fd].protocol,
//				                 connections[ev.data.fd].socket);
			}
			else
			{
				auto transport = cast(SocketTransport) connection.transport;
				assert(transport !is null);

				if (ev.events & (EPOLLIN | EPOLLPRI | EPOLLERR | EPOLLHUP))
				{
					try
					{
						while (!transport.receive())
						{
						}
						swapPendings.insertBack(connection);
					}
					catch (TransportException e)
					{
						swapPendings.insertBack(connection);
						dispose(defaultAllocator, e);
					}
				}
				else if (ev.events & (EPOLLOUT | EPOLLERR | EPOLLHUP))
				{
					transport.writeReady = true;
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

	private int fd;
	private epoll_event* epollEvents;
}
