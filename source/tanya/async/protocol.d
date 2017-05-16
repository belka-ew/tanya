/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * Copyright: Eugene Wissner 2016-2017.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 */
module tanya.async.protocol;

import tanya.network.socket;
import tanya.async.transport;

/**
 * Common protocol interface.
 */
interface Protocol
{
    /**
     * Params:
     *  data = Read data.
     */
    void received(in ubyte[] data) @nogc;

    /**
     * Called when a connection is made.
     *
     * Params:
     *  transport = Protocol transport.
     */
    void connected(DuplexTransport transport) @nogc;

    /**
     * Called when a connection is lost.
     *
     * Params:
     *  exception = $(D_PSYMBOL Exception) if an error caused
     *              the disconnect, $(D_KEYWORD null) otherwise.
     */
    void disconnected(SocketException exception) @nogc;
}

/**
 * Interface for TCP.
 */
interface TransmissionControlProtocol  : Protocol
{
}
