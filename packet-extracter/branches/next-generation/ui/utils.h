#ifndef _UTILS_H_
#define _UTILS_H_

#include <wx/string.h>
#include <wx/ffile.h>
#include "packet-length-analyzer.h"

/**
 * Create a recvpackets.txt.
 *
 * @param file   The file to write the contents to.
 * @param length The PacketLengthMap which contains the packet lengths.
 * @require file.IsOpened()
 * @ensure  file.IsOpened()
 */
void createRecvpackets(wxFFile &file, PacketLengthMap &lengths);

/**
 * Find the location of our objdump program.
 *
 * @return A filename, or an empty if not found.
 */
wxString findObjdump();

#define wxS(s) wxString(wxT(s))

#endif /* _UTILS_H_ */
