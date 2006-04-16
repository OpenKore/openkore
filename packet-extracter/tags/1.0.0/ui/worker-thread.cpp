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

#include <wz/socket.h>
#include <wz/exception.h>
#include "worker-thread.h"

using namespace Wz;

WorkerThread::WorkerThread(long pid, ServerSocket *server)
	: wxThread(wxTHREAD_JOINABLE),
	  analyzer(),
	  parser(&analyzer)
{
	this->pid = pid;
	this->server = server;
	server->ref();
	stopped = false;
	status = STATUS_OK;
}

WorkerThread::~WorkerThread() {
	server->unref();
}

wxThread::ExitCode
WorkerThread::Entry() {
	Socket *socket;
	InputStream *input;

	try {
		socket = server->accept(4000);
		if (socket == NULL) {
			status = STATUS_ERROR;
			error = wxT("The internal disassembler program failed to start.");
			return 0;
		}
		input = socket->getInputStream();
	} catch (IOException &e) {
		status = STATUS_ERROR;
		error = wxT("Socket error: ") + e.getMessage();
		return 0;
	}

	try {
		while (!input->eof() && analyzer.getState() != PacketLengthAnalyzer::DONE
		       && analyzer.getState() != PacketLengthAnalyzer::FAILED
		       && !stopped) {
			char buffer[1024 * 24];
			int size;

			size = input->read(buffer, sizeof(buffer));
			if (size > 0) {
				parser.addData(buffer, size);
			}
		}
	} catch (LineParser::BufferOverflowException &e) {
		status = STATUS_ERROR;
		error = wxT("The disassembler generated a line that's too long.");
	} catch (IOException &e) {
		status = STATUS_ERROR;
		error = wxT("The disassembler exited unexpectedly.");
	}

	delete socket;
	parser.setEOF();
	return 0;
}

PacketLengthAnalyzer &
WorkerThread::getAnalyzer() {
	return analyzer;
}

void
WorkerThread::stop() {
	stopped = true;
	status = STATUS_STOPPED;
}

WorkerThread::Status
WorkerThread::getStatus() {
	return status;
}

wxString
WorkerThread::getError() {
	return error;
}
