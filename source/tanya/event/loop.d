/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * Copyright: Eugene Wissner 2016.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:belka@caraus.de, Eugene Wissner)
 */  
module tanya.event.loop;

import tanya.memory;
import tanya.container.queue;
import tanya.container.vector;
import tanya.event.config;
import tanya.event.protocol;
import tanya.event.transport;
import tanya.event.watcher;
import tanya.container.buffer;
import core.thread;
import core.time;
import std.algorithm.iteration;
import std.algorithm.mutation;
import std.typecons;

static if (UseEpoll)
{
    import tanya.event.internal.epoll;
}

/**
 * Events.
 */
enum Event : uint
{
	none   = 0x00, /// No events.
	read   = 0x01, /// Non-blocking read call.
	write  = 0x02, /// Non-blocking write call.
	accept = 0x04, /// Connection made.
}

alias EventMask = BitFlags!Event;

/**
 * Event loop.
 */
abstract class Loop
{
	/// Pending watchers.
	protected Queue!Watcher pendings;

	protected Queue!Watcher swapPendings;

	/// Pending connections.
	protected Vector!ConnectionWatcher connections;

	/**
	 * Initializes the loop.
	 */
	this()
	{
		connections = make!(Vector!ConnectionWatcher)(defaultAllocator);
		pendings = make!(Queue!Watcher)(defaultAllocator);
		swapPendings = make!(Queue!Watcher)(defaultAllocator);
	}

	/**
	 * Frees loop internals.
	 */
	~this()
	{
		finalize(defaultAllocator, connections);
		finalize(defaultAllocator, pendings);
		finalize(defaultAllocator, swapPendings);
	}

	/**
	 * Starts the loop.
	 */
    void run()
    {
		done_ = false;
		do
		{
			poll();

			// Invoke pendings
			swapPendings.each!((ref p) => p.invoke());

			swap(pendings, swapPendings);
		}
		while (!done_);
    }

	/**
	 * Break out of the loop.
	 */
    void unloop() @safe pure nothrow
    {
		done_ = true;
    }

	/**
	 * Start watching.
	 *
	 * Params:
	 * 	watcher = Watcher.
	 */
	void start(ConnectionWatcher watcher)
	{
		if (watcher.active)
		{
			return;
		}
		watcher.active = true;
		watcher.accept = &acceptConnection;
		connections[watcher.socket] = watcher;

		modify(watcher.socket, EventMask(Event.none), EventMask(Event.accept));
	}

	/**
	 * Stop watching.
	 *
	 * Params:
	 * 	watcher = Watcher.
	 */
	void stop(ConnectionWatcher watcher)
	{
		if (!watcher.active)
		{
			return;
		}
		watcher.active = false;

		modify(watcher.socket, EventMask(Event.accept), EventMask(Event.none));
	}

	/**
	 * Feeds the given event set into the event loop, as if the specified event
	 * had happened for the specified watcher.
	 *
	 * Params:
	 * 	transport = Affected transport.
	 */
	void feed(DuplexTransport transport)
	{
		pendings.insertBack(connections[transport.socket]);
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
	protected bool modify(int socket, EventMask oldEvents, EventMask events);

	/**
	 * Returns: The blocking time.
	 */
	protected @property inout(Duration) blockTime()
	inout @safe pure nothrow
	{
		// Don't block if we have to do.
		return swapPendings.empty ? blockTime_ : Duration.zero;
	}

	/**
	 * Sets the blocking time for IO watchers.
	 *
	 * Params:
	 * 	blockTime = The blocking time. Cannot be larger than
	 * 	            $(D_PSYMBOL maxBlockTime).
	 */
	protected @property void blockTime(in Duration blockTime) @safe pure nothrow
	in
	{
		assert(blockTime <= 1.dur!"hours", "Too long to wait.");
		assert(!blockTime.isNegative);
	}
	body
	{
		blockTime_ = blockTime;
	}

	/**
	 * Does the actual polling.
	 */
	protected void poll();

	/**
	 * Accept incoming connections.
	 *
	 * Params:
	 * 	protocolFactory = Protocol factory.
	 * 	socket          = Socket.
	 */
	protected void acceptConnection(Protocol delegate() protocolFactory,
	                                int socket);

	/// Whether the event loop should be stopped.
    private bool done_;

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
	 * 	file = The file where the exception occurred.
	 * 	line = The line number where the exception occurred.
	 * 	next = The previous exception in the chain of exceptions, if any.
	 */
	this(string file = __FILE__, size_t line = __LINE__, Throwable next = null)
	pure @safe nothrow const @nogc
	{
		super("Event loop cannot be initialized.", file, line, next);
	}
}

/**
 * Returns the event loop used by default. If an event loop wasn't set with
 * $(D_PSYMBOL defaultLoop) before, $(D_PSYMBOL getDefaultLoop()) will try to
 * choose an event loop supported on the system.
 *
 * Returns: The default event loop.
 */
Loop getDefaultLoop()
{
    if (_defaultLoop !is null)
    {
		return _defaultLoop;
	}

	static if (UseEpoll)
	{
		_defaultLoop = make!EpollLoop(defaultAllocator);
	}

    return _defaultLoop;
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
 * 	loop = The event loop.
 */
@property void defaultLoop(Loop loop)
in
{
	assert(loop !is null);
}
body
{
	_defaultLoop = loop;
}

private Loop _defaultLoop;
