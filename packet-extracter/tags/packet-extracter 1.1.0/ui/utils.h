/*
 *  OpenKore Packet Length Extractor
 *  Copyright (C) 2006 - written by VCL
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

#ifndef _UTILS_H_
#define _UTILS_H_

#include <wx/string.h>
#include <wx/ffile.h>
#include "packet-length-analyzer.h"

/**
 * Create a recvpackets.txt.
 *
 * @param file       The file to write the contents to.
 * @param length     The PacketLengthMap which contains the packet lengths.
 * @param alphaSort  Whether the packets in the text file should be sorted alphabetically
 *                   according to packet identifier, or sorted according to the order they
 *                   appear in the disassembled source.
 * @require file.IsOpened()
 * @ensure  file.IsOpened()
 */
void createRecvpackets(wxFFile &file, PacketLengthMap &lengths, bool alphaSort = true);

/**
 * Find the location of our objdump program.
 *
 * @return A filename, or an empty if not found.
 */
wxString findObjdump();

#define wxS(s) wxString(wxT(s))

#endif /* _UTILS_H_ */
