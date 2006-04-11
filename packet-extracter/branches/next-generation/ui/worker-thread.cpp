#include "worker-thread.h"

WorkerThread::WorkerThread(wxProcess *process, long pid)
	: wxThread(wxTHREAD_JOINABLE),
	  analyzer(),
	  parser(&analyzer)
{
	this->process = process;
	this->pid = pid;
	stopped = false;
}

WorkerThread::~WorkerThread() {
	delete process;
}

wxThread::ExitCode
WorkerThread::Entry() {
	wxInputStream *input;

	process->CloseOutput();
	input = process->GetInputStream();
	while (!input->Eof() && analyzer.getState() != PacketLengthAnalyzer::DONE
	       && analyzer.getState() != PacketLengthAnalyzer::FAILED
	       && !stopped) {
		char buffer[1024 * 24];

		input->Read(buffer, sizeof(buffer));
		parser.addData(buffer, input->LastRead());
	}

	if (!input->Eof()) {
		wxKill(pid);
	}
	parser.setEOF();

	return 0;
}

PacketLengthAnalyzer &
WorkerThread::getAnalyzer()
{
	return analyzer;
}

void
WorkerThread::stop() {
	stopped = true;
}
