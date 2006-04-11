#include "utils.h"

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
