#include <wx/file.h>
#include "view.h"
#include "utils.h"

#define WORKER_THREAD_POLL_ID 1201

BEGIN_EVENT_TABLE(View, MainFrame)
	EVT_TIMER(WORKER_THREAD_POLL_ID, View::onTimer)
END_EVENT_TABLE()

View::View()
	: MainFrame(NULL, -1, "",  wxDefaultPosition, wxDefaultSize, 0),
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

	if (findObjdump() == "") {
		wxMessageBox("The internal disassembler program, "
			     "objdump, is not found. Please redownload "
			     "this program.",
			     "Error", wxOK | wxICON_ERROR, this);
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
	wxFileDialog dialog (this, "Open RO executable", "", "",
			     "Executables (*.exe)|*.exe|All files (*.*)|*.*",
			     wxOPEN | wxFILE_MUST_EXIST);
	if (dialog.ShowModal() == wxID_OK) {
		fileInput->SetValue(dialog.GetPath());
	}
}

/*
 * A wxProcess which does nothing in OnTerminate.
 * This avoids some crashes.
 */
class Process: public wxProcess {
public:
	Process() : wxProcess(wxPROCESS_REDIRECT) {}
protected:
	virtual void OnTerminate(int pid, int status) {}
};

void
View::onExtractClick(wxCommandEvent &event) {
	if (fileInput->GetValue().Len() == 0) {
		wxMessageBox("You didn't specify a file.", "Error",
			     wxOK | wxICON_ERROR, this);
		return;
	} else if (!wxFileExists(fileInput->GetValue())) {
		wxMessageBox("The specified file does not exist.", "Error",
			     wxOK | wxICON_ERROR, this);
		return;
	}

	fileInput->Enable(false);
	browseButton->Enable(false);
	extractButton->Enable(false);

	char *command[7];
	wxProcess *process = new Process();
	long pid;

	command[0] = const_cast<char *>(findObjdump().c_str());
	command[1] = "objdump";
	command[2] = "-d";
	command[3] = "-M";
	command[4] = "intel";
	command[5] = const_cast<char *>(fileInput->GetValue().c_str());
	command[6] = NULL;

	pid = wxExecute((char **) command, wxEXEC_ASYNC, process);
	if (pid == 0) {
		wxMessageBox("Unable to launch the disassembler.", "Error",
			     wxOK | wxICON_ERROR, this);
		Close();
		return;
	}

	thread = new WorkerThread(process, pid);
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
	wxMessageBox("OpenKore Packet Length Extractor\n"
		     "Version 1.0.0\n"
		     "http://www.openkore.com/\n\n"
		     "Copyright (c) 2006 - written by VCL\n"
		     "Licensed under the GNU General Public License.\n"
		     "Parts of this program are copied from GNU binutils.",
		     "Information", wxOK | wxICON_INFORMATION,
		     this);
}

void
View::onTimer(wxTimerEvent &event) {
	if (thread->IsAlive()) {
		PacketLengthAnalyzer &analyzer = thread->getAnalyzer();
		double progress = analyzer.getProgress();
		this->progress->SetValue(static_cast<int>(progress));

	} else {
		timer.Stop();
		progress->SetValue(100);

		thread->Wait();
		PacketLengthAnalyzer &analyzer = thread->getAnalyzer();
		int state = analyzer.getState();

		if (state == PacketLengthAnalyzer::DONE) {
			saveRecvpackets(analyzer);
		} else if (state == PacketLengthAnalyzer::FAILED) {
			wxMessageBox(wxString::Format(
				"An error occured:\n%s",
				(const char *) analyzer.getError()
				), "Error", wxOK | wxICON_ERROR,
				this);
		} else {
			wxMessageBox(wxString::Format(
				"Error: packet analyzer is in an inconsistent state. "
				"Please report this bug.\n\n"
				"Technical details:\n"
				"state == %d",
				state), "Error", wxOK | wxICON_ERROR,
				this);
		}

		delete thread;
		thread = NULL;
		Close();
	}
}

void
View::saveRecvpackets(PacketLengthAnalyzer &analyzer) {
	wxMessageBox("The packets lengths have been successfully extracted.\n"
		     "Please choose a file to save them to.",
		     "Extraction successful", wxOK | wxICON_INFORMATION,
		     this);

	wxString contents = createRecvpackets(analyzer.getPacketLengths());
	wxFileDialog dialog(this, "Save recvpackets.txt", "",
			    "recvpackets.txt", "Text files (*.txt)|*.txt",
			    wxSAVE | wxOVERWRITE_PROMPT);
	if (dialog.ShowModal() == wxID_OK) {
		wxFile file(dialog.GetPath(), wxFile::write);
		if (!file.IsOpened()) {
			wxMessageBox("Unable to save to the specified file.",
				     "Error", wxOK | wxICON_ERROR,
				     this);
			return;
		}

		file.Write(contents);
		file.Close();
	}
}
