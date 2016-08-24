/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * Copyright: Eugene Wissner 2016.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:belka@caraus.de, Eugene Wissner)
 */  
module tanya.event.protocol;

import tanya.event.transport;

/**
 * Common protocol interface.
 */
interface Protocol
{
@nogc:
	/**
	 * Params:
	 * 	data = Read data.
	 */
	void received(ubyte[] data);

	/**
	 * Called when a connection is made.
	 *
	 * Params:
	 * 	transport = Protocol transport.
	 */
	void connected(DuplexTransport transport);

	/**
	 * Called when a connection is lost.
	 */
	void disconnected();
}

/**
 * Interface for TCP.
 */
interface TransmissionControlProtocol  : Protocol
{
}
