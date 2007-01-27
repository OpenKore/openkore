///////////////////////////////////////////////////////////////////////////
// C++ code generated with wxFormBuilder (version Jan 27 2007)
// http://www.wxformbuilder.org/
//
// PLEASE DO "NOT" EDIT THIS FILE!
///////////////////////////////////////////////////////////////////////////

#ifndef __mainframe__
#define __mainframe__

// Define WX_GCH in order to support precompiled headers with GCC compiler.
// You have to create the header "wx_pch.h" and include all files needed
// for compile your gui inside it.
// Then, compile it and place the file "wx_pch.h.gch" into the same
// directory that "wx_pch.h".
#ifdef WX_GCH
#include <wx_pch.h>
#else
#include <wx/wx.h>
#endif

#include <wx/button.h>
#include <wx/gauge.h>
#include <wx/panel.h>

///////////////////////////////////////////////////////////////////////////


///////////////////////////////////////////////////////////////////////////////
/// Class MainFrame
///////////////////////////////////////////////////////////////////////////////
class MainFrame : public wxFrame 
{
	private:
	
	protected:
		wxPanel* panel_1;
		wxStaticText* label_1;
		wxTextCtrl* fileInput;
		wxButton* browseButton;
		wxCheckBox* alphaSort;
		wxGauge* progress;
		wxButton* aboutButton;
		wxButton* extractButton;
		wxButton* cancelButton;
	
	public:
		MainFrame( wxWindow* parent, int id = wxID_ANY, wxString title = wxT("OpenKore Packet Length Extractor"), wxPoint pos = wxDefaultPosition, wxSize size = wxDefaultSize, int style = wxCAPTION|wxCLOSE_BOX|wxMINIMIZE_BOX|wxSYSTEM_MENU|wxCLIP_CHILDREN );
	
};

#endif //__mainframe__
