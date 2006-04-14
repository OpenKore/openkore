#ifndef _WORKER_THREAD_H_
#define _WORKER_THREAD_H_

#include <wx/thread.h>
#include <wx/process.h>
#include <wz/server-socket.h>
#include "lineparser.h"
#include "packet-length-analyzer.h"

/**
 * A thread which runs the analyzing process.
 */
class WorkerThread: public wxThread {
public:
	WorkerThread(long pid, Wz::ServerSocket *server);
	~WorkerThread();

	PacketLengthAnalyzer &getAnalyzer();
	void stop();

	enum Status {
		STATUS_OK,
		STATUS_ERROR,
		STATUS_STOPPED
	};
	Status getStatus();
	wxString getError();

protected:
	virtual ExitCode Entry();

private:
	long pid;
	Wz::ServerSocket *server;
	PacketLengthAnalyzer analyzer;
	LineParser parser;
	bool stopped;
	Status status;
	wxString error;
};

#endif /* _WORKER_THREAD_H_ */
