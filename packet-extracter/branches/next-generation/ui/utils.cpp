#include <wx/filename.h>
#include "utils.h"
#ifdef WIN32
	#include <windows.h>
	#define PATH_MAX 1024 * 8
#else
	#include <unistd.h>
	#include <limits.h>
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
		result += wxString::Format("%s %d\n",
			(const char *) packet, lengths[packet]);
	}
	return result;
}

wxString
findObjdump() {
	char path[PATH_MAX];
	bool ok;

	#ifdef WIN32
		#define OBJDUMP_EXE "objdump.exe"
		DWORD count;

		count = GetModuleFileName(NULL, path, sizeof(path) - 1);
		ok = count != 0;
		if (ok) {
			path[count] = '\0';
		}

	#else
		#define OBJDUMP_EXE "objdump"
		int count;

		count = readlink("/proc/self/exe", path, sizeof(path) - 1);
		ok = count != -1;
		if (ok) {
			path[count] = '\0';
		}
	#endif

	if (!ok) {
		return "";
	} else {
		wxFileName filename(path);
		filename.AppendDir("objdump");
		filename.SetFullName(OBJDUMP_EXE);
		if (filename.FileExists()) {
			return filename.GetFullPath();
		}

		filename.Assign(path);
		filename.RemoveLastDir();
		filename.AppendDir("objdump");
		filename.SetFullName(OBJDUMP_EXE);
		if (filename.FileExists()) {
			return filename.GetFullPath();
		}

		filename.Assign(path);
		filename.SetFullName(OBJDUMP_EXE);
		if (filename.FileExists()) {
			return filename.GetFullPath();
		}

		return "";
	}
}
