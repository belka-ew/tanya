/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * Copyright: Eugene Wissner 2016.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:belka@caraus.de, Eugene Wissner)
 */  
module tanya.event.transport;

import tanya.container.buffer;
import tanya.event.protocol;

/**
 * Exception thrown on read/write errors.
 */
class TransportException : Exception
{
	/**
	 * Params:
	 * 	msg  = Message to output.
	 * 	file = The file where the exception occurred.
	 * 	line = The line number where the exception occurred.
	 * 	next = The previous exception in the chain of exceptions, if any.
	 */
	this(string msg,
	     string file = __FILE__,
	     size_t line = __LINE__,
	     Throwable next = null) pure @safe nothrow const @nogc
	{
		super(msg, file, line, next);
	}
}

/**
 * Base transport interface.
 */
interface Transport
{
	/**
	 * Returns: Protocol.
	 */
	@property Protocol protocol() @safe pure nothrow;

	/**
	 * Returns: $(D_KEYWORD true) if the peer closed the connection,
	 *          $(D_KEYWORD false) otherwise.
	 */
	@property immutable(bool) disconnected() const @safe pure nothrow;

	/**
	 * Params:
	 * 	protocol = Application protocol.
	 */
	@property void protocol(Protocol protocol) @safe pure nothrow
	in
	{
		assert(protocol !is null, "protocolConnected cannot be unset.");
	}

	/**
	 * Returns: Application protocol.
	 */
	@property inout(Protocol) protocol() inout @safe pure nothrow;

	/**
	 * Returns: Transport socket.
	 */
	int socket() const @safe pure nothrow;
}

/**
 * Interface for read-only transports.
 */
interface ReadTransport : Transport
{
	/**
	 * Returns: Underlying output buffer.
	 */
	@property ReadBuffer output();

	/**
	 * Reads data into the buffer.
	 *
	 * Returns: Whether the reading is completed.
	 *
	 * Throws: $(D_PSYMBOL TransportException) if a read error is occured.
	 */
	bool receive()
	in
	{
		assert(!disconnected);
	}
}

/**
 * Interface for write-only transports.
 */
interface WriteTransport : Transport
{
	/**
	 * Returns: Underlying input buffer.
	 */
	@property WriteBuffer input();

	/**
	 * Write some data to the transport.
	 *
	 * Params:
	 * 	data = Data to send.
	 */
	void write(ubyte[] data);

	/**
	 * Returns: Whether the writing is completed.
	 *
	 * Throws: $(D_PSYMBOL TransportException) if a read error is occured.
	 */
	bool send()
	in
	{
		assert(input.length);
		assert(!disconnected);
	}
}

/**
 * Represents a bidirectional transport.
 */
abstract class DuplexTransport : ReadTransport, WriteTransport
{
}
