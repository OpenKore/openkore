#ifndef _PACKET_LENGTH_ANALYZER_H_
#define _PACKET_LENGTH_ANALYZER_H_

#include <wx/string.h>
#include <wx/arrstr.h>
#include <wx/regex.h>
#include <wx/hashmap.h>
#include "linehandler.h"

WX_DECLARE_STRING_HASH_MAP(unsigned int, PacketLengthMap);

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
	virtual void processLine(const char *line);
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
	wxString &getError();

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

	// Regular expressions
	wxRegEx firstPacketSwitch;
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
	 *
	 * @require line != NULL
	 */
	void addToBacklog(const char *line);

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
	void setFailed(wxString &error);
	void setFailed(const char *error);
};

#endif /* _PACKET_LENGTH_ANALYZER_H_ */
