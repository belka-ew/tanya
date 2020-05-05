/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * This module contains protocol which handle data in asynchronous
 * applications.
 *
 * When an event from the network arrives, a protocol method gets
 * called and can respond to the event.
 *
 * Copyright: Eugene Wissner 2016-2020.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 * Source: $(LINK2 https://github.com/caraus-ecms/tanya/blob/master/source/tanya/async/protocol.d,
 *                 tanya/async/protocol.d)
 */
module tanya.async.protocol;

import tanya.async.transport;
import tanya.network.socket;

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
