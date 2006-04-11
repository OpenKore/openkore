#include <wx/wx.h>
#include "view.h"

class MainApp: public wxApp {
private:
	View *view;
protected:
	virtual bool OnInit();
};

IMPLEMENT_APP(MainApp);

bool
MainApp::OnInit() {
	view = new View();
	SetTopWindow(view);
	view->Show(1);
	return true;
}
