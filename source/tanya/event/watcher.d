/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * Copyright: Eugene Wissner 2016.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:belka@caraus.de, Eugene Wissner)
 */  
module tanya.event.watcher;

import tanya.event.protocol;
import tanya.event.transport;
import tanya.memory;
import std.functional;

/**
 * A watcher is an opaque structure that you allocate and register to record
 * your interest in some event. 
 */
abstract class Watcher
{
    /// Whether the watcher is active.
    bool active;

	/**
	 * Invoke some action on event.
	 */
	void invoke();
}

class ConnectionWatcher : Watcher
{
	/// Watched file descriptor.
    private int socket_;

	/// Protocol factory.
	protected Protocol delegate() protocolFactory;

	/// Callback.
	package void delegate(Protocol delegate() protocolFactory,
	                      int socket) accept;

	invariant
	{
		assert(socket_ >= 0, "Called with negative file descriptor.");
	}

	/**
	 * Params:
	 * 	protocolFactory = Function returning a new $(D_PSYMBOL Protocol) instance.
	 * 	socket          = Socket.
	 */
	this(Protocol function() protocolFactory, int socket)
	{
		this.protocolFactory = toDelegate(protocolFactory);
		socket_ = socket;
	}

	/// Ditto.
	this(Protocol delegate() protocolFactory, int socket)
	{
		this.protocolFactory = protocolFactory;
		socket_ = socket;
	}

	/// Ditto.
	protected this(Protocol function() protocolFactory)
	{
		this.protocolFactory = toDelegate(protocolFactory);
	}

	/// Ditto.
	protected this(Protocol delegate() protocolFactory)
	{
		this.protocolFactory = protocolFactory;
	}

	/**
	 * Returns: Socket.
	 */
	@property inout(int) socket() inout @safe pure nothrow
	{
		return socket_;
	}

	/**
	 * Returns: Application protocol factory.
	 */
	@property inout(Protocol delegate()) protocol() inout
	{
		return protocolFactory;
	}

	override void invoke()
	{
		accept(protocol, socket);
	}
}

/**
 * Contains a pending watcher with the invoked events or a transport can be
 * read from.
 */
class IOWatcher : ConnectionWatcher
{
	/// References a watcher or a transport.
	DuplexTransport transport_;

	/**
	 * Params:
	 * 	protocolFactory = Function returning application specific protocol.
	 * 	transport       = Transport.
	 */
	this(Protocol delegate() protocolFactory,
		 DuplexTransport transport)
	in
	{
		assert(transport !is null);
		assert(protocolFactory !is null);
	}
	body
	{
		super(protocolFactory);
		this.transport_ = transport;
	}

	~this()
	{
		dispose(defaultAllocator, transport_);
	}

    /**
     * Assigns a transport.
     *
     * Params:
	 * 	protocolFactory = Function returning application specific protocol.
	 * 	transport       = Transport.
     *
	 * Returns: $(D_KEYWORD this).
     */
	IOWatcher opCall(Protocol delegate() protocolFactory,
	                 DuplexTransport transport) @safe pure nothrow
	in
	{
		assert(transport !is null);
		assert(protocolFactory !is null);
	}
	body
	{
		this.protocolFactory = protocolFactory;
        this.transport_ = transport;
		return this;
	}

	/**
	 * Returns: Transport used by this watcher.
	 */
	@property inout(DuplexTransport) transport() inout @safe pure nothrow
	{
		return transport_;
	}

	/**
	 * Returns: Socket.
	 */
	override @property inout(int) socket() inout @safe pure nothrow
	{
		return transport.socket;
	}

	/**
	 * Invokes the watcher callback.
	 *
	 * Finalizes the transport on disconnect.
	 */
	override void invoke()
	{
		if (transport.protocol is null)
		{
			transport.protocol = protocolFactory();
			transport.protocol.connected(transport);
		}
		else if (transport.disconnected)
		{
			transport.protocol.disconnected();
			dispose(defaultAllocator, transport_);
			protocolFactory = null;
		}
		else if (transport.output.length)
		{
			transport.protocol.received(transport.output[]);
		}
		else if (transport.input.length)
		{
			try
			{
				transport.send();
			}
			catch (TransportException e)
			{
				dispose(defaultAllocator, e);
			}
		}
	}
}
