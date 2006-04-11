#ifndef _UTILS_H_
#define _UTILS_H_

#include <wx/string.h>
#include "packet-length-analyzer.h"

/**
 * Create the contents for recvpackets.txt.
 */
wxString createRecvpackets(PacketLengthMap &lengths);

#endif /* _UTILS_H_ */
