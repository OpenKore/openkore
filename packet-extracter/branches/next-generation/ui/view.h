#ifndef _VIEW_H_
#define _VIEW_H_

#include "mainframe.h"
#include "worker-thread.h"

class View: public MainFrame {
public:
	View();
	~View();
protected:
	void onBrowseClick(wxCommandEvent &event);
	void onExtractClick(wxCommandEvent &event);
	void onCancelClick(wxCommandEvent &event);
	void onAboutClick(wxCommandEvent &event);
	void onTimer(wxTimerEvent &event);
private:
	WorkerThread *thread;
	wxTimer timer;

	void saveRecvpackets(PacketLengthAnalyzer &analyzer);

	DECLARE_EVENT_TABLE();
};

#endif /* _VIEW_H_ */
