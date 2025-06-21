https://openkore.com/wiki/Poseidon

Poseidon is a solution for the GameGuard problem. Server like bRO use
GameGuard. The RO server sends a packet to the client, and the client
must response with an appropriate packet.


Overview
--------
Poseidon works like this:
1. Poseidon sets up a fake RO server (let us call it "Poseidon (RO server)").
2. Poseidon sets up a second server socket to communicate with OpenKore (let us call it "Poseidon (Query server)").
3. OpenKore connects to Poseidon (Query server).
4. RO client connects to Poseidon (RO server).

5. Real RO server sends GameGuard query to OpenKore.
6. OpenKore sends GameGuard query to Poseidon (Query server).
7. Poseidon (RO server) sends GameGuard query to RO client.
8. RO client sends a reply.
9. Poiseidon (Query server) sends reply to OpenKore.
10. OpenKore sends reply to real RO server.


Protocol
--------
The Poseidon server uses the same message format as the bus system.
See the Bus::Messages module for information.

A request to the Poseidon server is as follows:
Message ID: "Poseidon Query"
Key 'packet' - The GameGuard packet, as sent by the RO server.

The Poseidon server replies with the following message:
Message ID: "Poseidon Reply"
Key 'packet' - Response to send back to the GameGuard server.


Server files
------------
poseidon.pl, QueryServer.pm and RagnarokServer.pm are part of the Poseidon
server.


Client files
------------
The Poseidon::Client module provides a simple interface for OpenKore to
communicate with the Poseidon server.
