#ifndef _WORKER_THREAD_H_
#define _WORKER_THREAD_H_

#include <wx/thread.h>
#include <wx/process.h>
#include "lineparser.h"
#include "packet-length-analyzer.h"

/**
 * A thread which runs the analyzing process.
 */
class WorkerThread: public wxThread {
public:
	WorkerThread(wxProcess *process, long pid);
	~WorkerThread();

	PacketLengthAnalyzer &getAnalyzer();
	void stop();

protected:
	virtual ExitCode Entry();

private:
	wxProcess *process;
	long pid;
	PacketLengthAnalyzer analyzer;
	LineParser parser;
	bool stopped;
};

#endif /* _WORKER_THREAD_H_ */
