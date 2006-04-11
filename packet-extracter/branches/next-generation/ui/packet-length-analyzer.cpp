#include <stdio.h>
#include "packet-length-analyzer.h"

PacketLengthAnalyzer::PacketLengthAnalyzer()
	: firstPacketSwitch ("mov    DWORD PTR \\[ebp-8\\],0x187", wxRE_NOSUB),
	  packetLengthFunctionStart ("push   ebp", wxRE_NOSUB),
	  packetLengthFunctionEnd   ("ret ", wxRE_NOSUB),
	  movDword ("mov    DWORD PTR \\[(.*?)\\],(.*?)$"),
	  movToEbx ("mov    ebx,(.*?)$")
{
	state = FINDING_PACKET_LENGTH_FUNCTION;
	ebx = 0;
}

PacketLengthAnalyzer::~PacketLengthAnalyzer() {
}

void
PacketLengthAnalyzer::processLine(const char *line) {
	switch (state) {
	case FINDING_PACKET_LENGTH_FUNCTION:
		addToBacklog(line);
		if (firstPacketSwitch.Matches(line)) {
			// Find the start of the packet length function in the backlog,
			// and analyze everything in the backlog starting from that point,
			// plus the current line.

			int start = findPacketLengthFunction();
			if (start == -1) {
				printf ("Cannot find packet length function\n");
				break;
			}

			int i = start;
			while (i < (int) backlog.GetCount() && state == ANALYZING_PACKET_LENGTHS) {
				analyzeLine(backlog[i]);
				i++;
			}
		}
		break;

	case ANALYZING_PACKET_LENGTHS:
		if (packetLengthFunctionEnd.Matches(line)) {
			state = DONE;
		} else {
			wxString l (line);
			analyzeLine(l);
		}
		break;

	default:
		break;
	};
}

PacketLengthAnalyzer::State
PacketLengthAnalyzer::getState() {
	return state;
}

PacketLengthMap&
PacketLengthAnalyzer::getPacketLengths() {
	return lengths;
}

void
PacketLengthAnalyzer::addToBacklog(const char *line) {
	backlog.Add(wxString(line));
	if (backlog.GetCount() > MAX_BACKLOG_SIZE) {
		backlog.RemoveAt(0);
	}
}

int
PacketLengthAnalyzer::findPacketLengthFunction() {
	int result = -1;
	int i = backlog.GetCount() - 1;

	while (i >= 0 && result == -1) {
		if (packetLengthFunctionStart.Matches(backlog[i])) {
			result = i;
			state = ANALYZING_PACKET_LENGTHS;
		}
		i--;
	}

	if (result == -1) {
		state = FAILED;
	}

	return result;
}

/**
 * Convert a hexadecimal number to an int.
 *
 * @param hex A hexadecimal number in the form of "0x123".
 * @return Whether the conversion was successful.
 */
static bool
hexToInt(const wxString &hex, unsigned int &result) {
	return sscanf(hex, "%x", &result) == 1;
}

void
PacketLengthAnalyzer::analyzeLine(const wxString &line) {
	// Looking for something like:
	// mov   DWORD PTR [ebp-1],0x123
	if (movDword.Matches(line)) {
		wxString to = movDword.GetMatch(line, 1);
		wxString from = movDword.GetMatch(line, 2);
		static wxString ebp = "ebp";
		static wxString hexPrefix = "0x";
		static wxString eax = "eax";

		if (to.Contains(ebp) && from.StartsWith(hexPrefix)) {
			// Packet switch
			unsigned int value;

			if (!hexToInt(from, value)) {
				state = FAILED;
			} else {
				packetSwitch = wxString::Format("%04X", value);
			}

		} else if (to.Contains(eax)) {
			// Packet length
			unsigned int len;

			if (from == "ebx") {
				len = ebx;
			} else if (from.StartsWith(hexPrefix)) {
				if (!hexToInt(from, len)) {
					state = FAILED;
				}
			} else {
				len = 0;
			}

			if (packetSwitch.Len() == 0) {
				state = FAILED;
			} else {
				lengths[packetSwitch] = len;
			}
		}

	// Looking for something like:
	// mov   ebx,0x123
	} else if (movToEbx.Matches(line)) {
		// Remember the value of ebx.
		wxString value;

		value = movToEbx.GetMatch(line, 1);
		if (!hexToInt(value, ebx)) {
			state = FAILED;
		}
	}
}
