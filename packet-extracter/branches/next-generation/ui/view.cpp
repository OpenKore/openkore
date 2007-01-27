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

#include <wx/file.h>
#include <wz/server-socket.h>
#include "view.h"
#include "utils.h"

using namespace Wz;

#define WORKER_THREAD_POLL_ID 1201

BEGIN_EVENT_TABLE(View, MainFrame)
	EVT_TIMER(WORKER_THREAD_POLL_ID, View::onTimer)
END_EVENT_TABLE()

View::View()
	: MainFrame(NULL),
	  timer(this, WORKER_THREAD_POLL_ID)
{
	int width, height;

	GetClientSize(&width, &height);
	SetClientSize(350, height);
	Connect(browseButton->GetId(),  wxEVT_COMMAND_BUTTON_CLICKED,
		wxCommandEventHandler(View::onBrowseClick));
	Connect(extractButton->GetId(), wxEVT_COMMAND_BUTTON_CLICKED,
		wxCommandEventHandler(View::onExtractClick));
	Connect(cancelButton->GetId(),  wxEVT_COMMAND_BUTTON_CLICKED,
		wxCommandEventHandler(View::onCancelClick));
	Connect(aboutButton->GetId(),   wxEVT_COMMAND_BUTTON_CLICKED,
		wxCommandEventHandler(View::onAboutClick));

	if (wxApp::GetInstance()->argc >= 2) {
		fileInput->SetValue(wxApp::GetInstance()->argv[1]);
	}

	thread = NULL;

	if (findObjdump().Len() == 0) {
		wxMessageBox(wxS("The internal disassembler program, "
			     "objdump, is not found. Please redownload "
			     "this program."),
			     wxS("Error"), wxOK | wxICON_ERROR, this);
		Close();
	}
}

View::~View() {
	if (thread != NULL) {
		thread->stop();
		thread->Wait();
		delete thread;
	}
}

void
View::onBrowseClick(wxCommandEvent &event)
{
	wxFileDialog dialog (this, wxS("Open RO executable"), wxS(""), wxS(""),
			     wxS("Executables (*.exe)|*.exe|All files (*.*)|*.*"),
			     wxOPEN | wxFILE_MUST_EXIST);
	if (dialog.ShowModal() == wxID_OK) {
		fileInput->SetValue(dialog.GetPath());
	}
}

void
View::onExtractClick(wxCommandEvent &event) {
	if (fileInput->GetValue().Len() == 0) {
		wxMessageBox(wxS("You didn't specify a file."), wxS("Error"),
			     wxOK | wxICON_ERROR, this);
		return;
	} else if (!wxFileExists(fileInput->GetValue())) {
		wxMessageBox(wxS("The specified file does not exist."), wxS("Error"),
			     wxOK | wxICON_ERROR, this);
		return;
	}

	fileInput->Enable(false);
	browseButton->Enable(false);
	extractButton->Enable(false);


	// Start a server socket
	ServerSocket *server;
	try {
		server = ServerSocket::create(wxT("127.0.0.1"), 0);
	} catch (SocketException &e) {
		wxString message;
		message.Printf(wxT("Unable to start a server socket: %s"),
			       e.getMessage().c_str());
		wxMessageBox(message, wxS("Error"), wxOK | wxICON_ERROR, this);
		Close();
		return;
	}

	// Start the disassembler.
	wxString command;
	long pid;

	command = wxString::Format(wxT("\"%s\" -d -M intel --remote=%d \"%s\""),
		findObjdump().c_str(),
		server->getPort(),
		fileInput->GetValue().c_str());
	pid = wxExecute(command, wxEXEC_ASYNC, NULL);
	if (pid == 0) {
		delete server;
		wxMessageBox(wxS("Unable to launch the disassembler."), wxS("Error"),
			     wxOK | wxICON_ERROR, this);
		Close();
		return;
	}

	thread = new WorkerThread(pid, server);
	server->unref();
	thread->Create();
	thread->Run();
	timer.Start(100);
}

void
View::onCancelClick(wxCommandEvent &event) {
	Close();
}

void
View::onAboutClick(wxCommandEvent &event) {
	wxMessageBox(wxS("OpenKore Packet Length Extractor\n"
		     "Version 1.1.0\n"
		     "http://www.openkore.com/aliases/ple.php\n\n"
		     "Copyright (c) 2006 - written by VCL\n"
		     "Licensed under the GNU General Public License.\n"
		     "Parts of this program are copied from GNU binutils.\n"
		     "Written using WxWidgets (www.wxwidgets.org)"),
		     wxS("Information"), wxOK | wxICON_INFORMATION,
		     this);
}

void
View::onTimer(wxTimerEvent &event) {
	if (thread->IsAlive()) {
		PacketLengthAnalyzer &analyzer = thread->getAnalyzer();
		double progress = analyzer.getProgress();
		this->progress->SetValue(static_cast<int>(progress));
		return;
	}


	timer.Stop();
	progress->SetValue(100);

	thread->Wait();
	if (thread->getStatus() == WorkerThread::STATUS_ERROR) {
		wxMessageBox(thread->getError(), wxS("Error"), wxOK | wxICON_ERROR, this);
		delete thread;
		thread = NULL;
		Close();
		return;
	}

	PacketLengthAnalyzer &analyzer = thread->getAnalyzer();
	int state = analyzer.getState();

	if (state == PacketLengthAnalyzer::DONE) {
		saveRecvpackets(analyzer);
	} else if (state == PacketLengthAnalyzer::FAILED) {
		wxMessageBox(wxString::Format(
			wxS("An error occured:\n%s"),
			analyzer.getError().c_str()
			),
			wxS("Error"), wxOK | wxICON_ERROR, this);
	} else {
		wxMessageBox(wxString::Format(
			wxS("Error: packet analyzer is in an inconsistent state. "
			"Please report this bug.\n\n"
			"Technical details:\n"
			"state == %d"),
			state),
			wxS("Error"), wxOK | wxICON_ERROR, this);
	}

	delete thread;
	thread = NULL;
	Close();
}

void
View::saveRecvpackets(PacketLengthAnalyzer &analyzer) {
	wxMessageBox(wxS("The packets lengths have been successfully extracted.\n"
		     "Please choose a file to save them to."),
		     wxS("Extraction successful"),
		     wxOK | wxICON_INFORMATION, this);

	wxFileDialog dialog(this, wxS("Save recvpackets.txt"), wxS(""),
			    wxS("recvpackets.txt"), wxS("Text files (*.txt)|*.txt"),
			    wxSAVE | wxOVERWRITE_PROMPT);
	if (dialog.ShowModal() == wxID_OK) {
		wxFFile file(dialog.GetPath(), wxT("w"));
		if (!file.IsOpened()) {
			wxMessageBox(wxS("Unable to save to the specified file."),
				     wxS("Error"), wxOK | wxICON_ERROR,
				     this);
			return;
		}

		createRecvpackets(file, analyzer.getPacketLengths(), alphaSort->GetValue());
		file.Close();
	}
}
