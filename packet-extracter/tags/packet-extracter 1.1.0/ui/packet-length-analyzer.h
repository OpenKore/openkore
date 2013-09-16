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

#ifndef _PACKET_LENGTH_ANALYZER_H_
#define _PACKET_LENGTH_ANALYZER_H_

#include <wx/string.h>
#include <wx/arrstr.h>
#include <wx/regex.h>
#include <wx/hashmap.h>
#include "linehandler.h"

/**
 * Class which contains the length for a packet. Also contains an index of the
 * packet, in the order as it appears in the assembly source.
 */
class PacketInfo {
public:
	unsigned int length;
	/**
	 * @invariant index < PacketLengthAnalyzer.lengths.size()
	 */
	unsigned int index;
	PacketInfo(unsigned int length, unsigned int index);
};

WX_DECLARE_STRING_HASH_MAP(PacketInfo *, PacketLengthMap);

/**
 * This class extracts packet lengths by analyzing the RO client's
 * assembly data.
 */
class PacketLengthAnalyzer: public LineHandler {
public:
	enum State {
		FINDING_PACKET_LENGTH_FUNCTION,
		ANALYZING_PACKET_LENGTHS,
		DONE,
		FAILED
	};

	/**
	 * Create a new PacketLengthAnalyzer object.
	 *
	 * @ensure getState() == FINDING_PACKET_LENGTH_FUNCTION
	 */
	PacketLengthAnalyzer();

	~PacketLengthAnalyzer();
	virtual void processLine(const wxString &line);
	virtual void processEOF();

	/**
	 * Return the current state.
	 */
	State getState();

	/**
	 * Return an error message which explained why
	 * the analyzation failed.
	 *
	 * @require getState() == FAILED
	 */
	wxString getError();

	/**
	 * Return the extracted packet lengths.
	 *
	 * @require getState() == DONE
	 */
	PacketLengthMap &getPacketLengths();

	/**
	 * @ensure 0 <= result <= 100
	 */
	double getProgress();

private:
	static const unsigned int MAX_BACKLOG_SIZE = 100;

	/** @invariant backlog.GetCount() <= MAX_BACKLOG_SIZE */
	wxArrayString backlog;
	PacketLengthMap lengths;
	State state;
	wxString error;
	double progress;
	unsigned int counter;

	// Regular expressions
	wxRegEx packetLengthFunctionStart;
	wxRegEx packetLengthFunctionEnd;
	wxRegEx progressRegex;
	wxRegEx movDword;
	wxRegEx movToEbx;

	/** The current packet switch. */
	wxString packetSwitch;
	/** The current value of the ebx register. */
	unsigned int ebx;

	/**
	 * Add a line to the backlog. This function makes sure
	 * the backlog stays small by removing the oldest items.
	 */
	void addToBacklog(const wxString &line);

	/**
	 * Find an item in the backlog which represents the start of
	 * the packet length function.
	 *
	 * @return The index of the item, or -1 if failed.
	 * @require state == FINDING_PACKET_LENGTH_FUNCTION
	 * @ensure
	 *     -1 <= result < backlog.GetCount()
	 *     if result == -1:
	 *         state == FAILED
	 *     else:
	 *         state == ANALYZING_PACKET_LENGTHS
	 */
	int findPacketLengthFunction();

	/**
	 * Analyze a single line in the packet length function.
	 *
	 * @param line A line, without newline characters.
	 * @require state == ANALYZING_PACKET_LENGTHS
	 * @ensure  state == ANALYZING_PACKET_LENGTHS || state == DONE || state == FAILED
	 */
	void analyzeLine(const wxString &line);

	/**
	 * Indicate that the analyzation has failed.
	 *
	 * @param error An error message explaining why.
	 * @ensure getError() == error
	 */
	void setFailed(const wxString &error);
	void setFailed(const wxChar *error);
};

#endif /* _PACKET_LENGTH_ANALYZER_H_ */
