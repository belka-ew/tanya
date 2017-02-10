/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * Copyright: Eugene Wissner 2016-2017.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 */
module tanya.async.event.iocp;

version (Windows):

import tanya.container.buffer;
import tanya.async.loop;
import tanya.async.protocol;
import tanya.async.transport;
import tanya.async.watcher;
import tanya.memory;
import tanya.memory.mmappool;
import tanya.network.socket;
import core.sys.windows.basetyps;
import core.sys.windows.mswsock;
import core.sys.windows.winbase;
import core.sys.windows.windef;
import core.sys.windows.winsock2;

final class IOCPStreamTransport : StreamTransport
{
	private WriteBuffer!ubyte input;

	/**
	 * Creates new completion port transport.
	 *
	 * Params:
	 * 	socket = Socket.
	 *
	 * Precondition: $(D_INLINECODE socket)
	 */
	this(OverlappedConnectedSocket socket) @nogc
	in
	{
		assert(socket !is null);
	}
	body
	{
		super(socket);
		input = WriteBuffer!ubyte(8192, MmapPool.instance);
	}

	/**
	 * Returns: Socket.
	 */
	override @property OverlappedConnectedSocket socket() pure nothrow @safe @nogc
	{
		return cast(OverlappedConnectedSocket) socket_;
	}

	/**
	 * Switches the protocol.
	 *
	 * The protocol is deallocated by the event loop, it should currently be
	 * allocated with $(D_PSYMBOL MmapPool).
	 *
	 * Params:
	 * 	protocol = Application protocol.
	 *
	 * Precondition: $(D_INLINECODE protocol !is null)
	 */
	@property void protocol(Protocol protocol) pure nothrow @safe @nogc
	in
	{
		assert(protocol !is null);
	}
	body
	{
		protocol_ = protocol;
	}


	/**
	 * Write some data to the transport.
	 *
	 * Params:
	 * 	data = Data to send.
	 */
	void write(ubyte[] data) @nogc
	{
		immutable empty = input.length == 0;
		input ~= data;
		if (empty)
		{
			SocketState overlapped;
			try
			{
				overlapped = MmapPool.instance.make!SocketState;
				socket.beginSend(input[], overlapped);
			}
			catch (SocketException e)
			{
				MmapPool.instance.dispose(overlapped);
				MmapPool.instance.dispose(e);
			}
		}
	}
}

final class IOCPLoop : Loop
{
	protected HANDLE completionPort;

	protected OVERLAPPED overlap;

	/**
	 * Initializes the loop.
	 */
	this() @nogc
	{
		super();

		completionPort = CreateIoCompletionPort(INVALID_HANDLE_VALUE, NULL, 0, 0);
		if (!completionPort)
		{
			throw make!BadLoopException(defaultAllocator,
			                            "Creating completion port failed");
		}
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
	override protected bool reify(ConnectionWatcher watcher,
								  EventMask oldEvents,
								  EventMask events) @nogc
	{
		SocketState overlapped;
		if (!(oldEvents & Event.accept) && (events & Event.accept))
		{
			auto socket = cast(OverlappedStreamSocket) watcher.socket;
			assert(socket !is null);

			if (CreateIoCompletionPort(cast(HANDLE) socket.handle,
									   completionPort,
									   cast(ULONG_PTR) (cast(void*) watcher),
									   0) !is completionPort)
			{
				return false;
			}

			try
			{
				overlapped = MmapPool.instance.make!SocketState;
				socket.beginAccept(overlapped);
			}
			catch (SocketException e)
			{
				MmapPool.instance.dispose(overlapped);
				defaultAllocator.dispose(e);
				return false;
			}
		}
		if (!(oldEvents & Event.read) && (events & Event.read)
			|| !(oldEvents & Event.write) && (events & Event.write))
		{
			auto transport = cast(IOCPStreamTransport) watcher;
			assert(transport !is null);

			if (CreateIoCompletionPort(cast(HANDLE) transport.socket.handle,
									   completionPort,
									   cast(ULONG_PTR) (cast(void*) watcher),
									   0) !is completionPort)
			{
				return false;
			}

			// Begin to read
			if (!(oldEvents & Event.read) && (events & Event.read))
			{
				try
				{
					overlapped = MmapPool.instance.make!SocketState;
					transport.socket.beginReceive(transport.output[], overlapped);
				}
				catch (SocketException e)
				{
					MmapPool.instance.dispose(overlapped);
					defaultAllocator.dispose(e);
					return false;
				}
			}
		}
		return true;
	}

	/**
	 * Does the actual polling.
	 */
	override protected void poll() @nogc
	{
		DWORD lpNumberOfBytes;
		ULONG_PTR key;
		LPOVERLAPPED overlap;
		immutable timeout = cast(immutable int) blockTime.total!"msecs";

		auto result = GetQueuedCompletionStatus(completionPort,
												&lpNumberOfBytes,
												&key,
												&overlap,
												timeout);
		if (result == FALSE && overlap == NULL)
		{
			return; // Timeout
		}

		auto overlapped = (cast(SocketState) ((cast(void*) overlap) - 8));
		assert(overlapped !is null);
		scope (failure)
		{
			MmapPool.instance.dispose(overlapped);
		}

		switch (overlapped.event)
		{
			case OverlappedSocketEvent.accept:
				auto connection = cast(ConnectionWatcher) (cast(void*) key);
				assert(connection !is null);

				auto listener = cast(OverlappedStreamSocket) connection.socket;
				assert(listener !is null);

				auto socket = listener.endAccept(overlapped);
				auto transport = MmapPool.instance.make!IOCPStreamTransport(socket);

				connection.incoming.enqueue(transport);

				reify(transport, EventMask(Event.none), EventMask(Event.read, Event.write));

				pendings.enqueue(connection);
				listener.beginAccept(overlapped);
				break;
			case OverlappedSocketEvent.read:
				auto transport = cast(IOCPStreamTransport) (cast(void*) key);
				assert(transport !is null);

				if (!transport.active)
				{
					MmapPool.instance.dispose(transport);
					MmapPool.instance.dispose(overlapped);
					return;
				}

				int received;
				SocketException exception;
				try
				{
					received = transport.socket.endReceive(overlapped);
				}
				catch (SocketException e)
				{
					exception = e;
				}
				if (transport.socket.disconnected)
				{
					// We want to get one last notification to destroy the watcher
					transport.socket.beginReceive(transport.output[], overlapped);
					kill(transport, exception);
				}
				else if (received > 0)
				{
					immutable full = transport.output.free == received;

					transport.output += received;
					// Receive was interrupted because the buffer is full. We have to continue
					if (full)
					{
						transport.socket.beginReceive(transport.output[], overlapped);
					}
					pendings.enqueue(transport);
				}
				break;
			case OverlappedSocketEvent.write:
				auto transport = cast(IOCPStreamTransport) (cast(void*) key);
				assert(transport !is null);

				transport.input += transport.socket.endSend(overlapped);
				if (transport.input.length)
				{
					transport.socket.beginSend(transport.input[], overlapped);
				}
				else
				{
					transport.socket.beginReceive(transport.output[], overlapped);
				}
				break;
			default:
				assert(false, "Unknown event");
		}
	}
}
