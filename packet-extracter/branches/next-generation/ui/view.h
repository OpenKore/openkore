#ifndef _VIEW_H_
#define _VIEW_H_

#include "mainframe.h"

class View: public MainFrame {
protected:
	void onBrowseClick(wxCommandEvent &event);
	void onExtractClick(wxCommandEvent &event);
	void onCancelClick(wxCommandEvent &event);
public:
	View();
	~View();
};

#endif /* _VIEW_H_ */
