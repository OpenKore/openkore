                        === Padded packets emulator ===


What is this?
-------------
Some RO servers, such as euRO (Europe), iRO (International) and rRO (Russia)
use so-called padded packets. The RO client will insert what seems to be
garbage data into parts of certain packet. In reality, this "garbage" is the
result of of a complex hashing algorithm. Furthermore, the size of the garbage
data, and the algorithm that is used, varies every time a sync is received
from the RO server. Thus, a packet may have different sizes during different
times.

We refer to packets that contain such data, as "padded packets". The padded
packets emulator is a subsystem in OpenKore which generates correct padded
packets.

Padded packets only affect packets that are sent from the client to the server,
not packets received from server to client. Furthermore, not all packets are
padded - only some are, usually the "sit", "stand", "attack" and "use skill"
packets.


How the algorithm works
-----------------------
As you know, each packet in the RO protocol is at least 2 bytes. The first
two bytes are referred to as "packet switch" (although I prefer to call them
"message" and "message ID", respectively). More information about the RO
protocol's general format can be found here:
http://www.openkore.com/wiki/index.php/Network_subsystem#Appendix_A:_introduction_to_the_Ragnarok_Online_protocol

A padded packet contains a hash of of its packet switch. There are 16
different hashing algorithms that can be used. Which hashing algorithm is
currently used, depends on a variety of factors such as:
- The last received map sync.
- The last received sync.
- The account ID.


Subsystem high-level architecture
---------------------------------
The padded packets emulator consists of a C++ part and a Perl part. The Perl
part, Network/PaddedPackets.pm, is just a wrapper around the C++ part. The
C++ part is where the real work is done, and its source code is in this folder.

The relations between the various source files are illustrated in this
diagram:

                      Perl module
                (Network::PaddedPackets)
                           |
                           |
                    PaddedPackets.xs
                           |
           +---------------+---------------+
           |                               |
           |                               |
      engine.cpp                     algorithms.cpp
                                           |
                                  +--------+---------+
                                  |        |         |
                              feal8.c   rmd128.c   ...etc...

PaddedPackets.xs is responsible for generating the padded packets.
Algorithms/algorithms.cpp is the main interface to the 16 different
hashing functions.
engine.cpp is a utility class used when generating padded packets.
