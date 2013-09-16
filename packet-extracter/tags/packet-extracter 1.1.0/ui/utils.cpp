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

#include <wx/filename.h>
#include <stdlib.h>
#include <limits.h>
#include <algorithm>
#include "utils.h"
#ifdef WIN32
	#include <windows.h>
	#include <wchar.h>
#else
	#include <unistd.h>
#endif

void
createRecvpackets(wxFFile &file, PacketLengthMap &lengths, bool alphaSort) {
	PacketLengthMap::iterator it;
	wxArrayString packets;

	packets.Add(wxT(""), lengths.size());
	for (it = lengths.begin(); it != lengths.end(); it++) {
		wxString packet = it->first;
		PacketInfo *info = it->second;
		packets[info->index] = packet;
	}
	if (alphaSort) {
		packets.Sort();
	}

	for (size_t i = 0; i < packets.GetCount(); i++) {
		wxString &packet = packets[i];
		wxString line = wxString::Format(
			wxT("%s %d\n"), packet.c_str(), lengths[packet]->length);
		file.Write(line);
	}
}

wxString
findObjdump() {
	wxFileName exeName;

	#ifdef WIN32
		#define OBJDUMP_EXE wxT("objdump.exe")
		DWORD count;
		WCHAR path[PATH_MAX];
	
		count = GetModuleFileNameW(NULL, path, sizeof(path) - 1);
		if (count != 0) {
			path[count] = (WCHAR) 0;
			wxMBConvUTF16 conv;
			wxString fn = wxString(static_cast<const wchar_t *>(path),
				conv);
			exeName.Assign(fn);
		}
	#else
		#define OBJDUMP_EXE wxT("objdump")
		char path[PATH_MAX];
		int count;

		count = readlink("/proc/self/exe", path, sizeof(path) - 1);
		if (count != -1) {
			path[count] = '\0';
			exeName.Assign(wxString::FromAscii(path));
		}
	#endif

	if (!exeName.IsOk()) {
		return wxT("");
	} else {
		wxFileName filename(exeName);
		filename.AppendDir(wxT("objdump"));
		filename.SetFullName(OBJDUMP_EXE);
		if (filename.FileExists()) {
			return filename.GetFullPath();
		}

		filename.Assign(exeName);
		filename.RemoveLastDir();
		filename.AppendDir(wxT("objdump"));
		filename.SetFullName(OBJDUMP_EXE);
		if (filename.FileExists()) {
			return filename.GetFullPath();
		}

		filename.Assign(exeName);
		filename.SetFullName(OBJDUMP_EXE);
		if (filename.FileExists()) {
			return filename.GetFullPath();
		}

		return wxT("");
	}
}
