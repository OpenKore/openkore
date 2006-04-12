#include <wx/filename.h>
#include <limits.h>
#include "utils.h"
#ifdef WIN32
	#include <windows.h>
	#include <wchar.h>
#else
	#include <unistd.h>
#endif

wxString
createRecvpackets(PacketLengthMap &lengths) {
	PacketLengthMap::iterator it;
	wxArrayString packets;

	for (it = lengths.begin(); it != lengths.end(); it++) {
		wxString packet = it->first;
		packets.Add(packet);
	}
	packets.Sort();

	wxString result;
	for (size_t i = 0; i < packets.GetCount(); i++) {
		wxString &packet = packets[i];
		result += wxString::Format(wxT("%s %d\n"),
			packet.c_str(), lengths[packet]);
	}
	return result;
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
