///////////////////////////////////////////////////////////////////////////
// C++ code generated with wxFormBuilder (version Jan 27 2007)
// http://www.wxformbuilder.org/
//
// PLEASE DO "NOT" EDIT THIS FILE!
///////////////////////////////////////////////////////////////////////////

#include "wx/wxprec.h"

#ifdef __BORLANDC__
#pragma hdrstop
#endif //__BORLANDC__

#ifndef WX_PRECOMP
#include <wx/wx.h>
#endif //WX_PRECOMP

#include "mainframe.h"

///////////////////////////////////////////////////////////////////////////

MainFrame::MainFrame( wxWindow* parent, int id, wxString title, wxPoint pos, wxSize size, int style ) : wxFrame( parent, id, title, pos, size, style )
{
	this->SetSizeHints( wxDefaultSize, wxDefaultSize );
	this->Centre( wxBOTH );
	
	wxBoxSizer* bSizer1;
	bSizer1 = new wxBoxSizer( wxVERTICAL );
	
	panel_1 = new wxPanel( this, wxID_ANY, wxDefaultPosition, wxDefaultSize, wxTAB_TRAVERSAL );
	wxBoxSizer* bSizer2;
	bSizer2 = new wxBoxSizer( wxVERTICAL );
	
	label_1 = new wxStaticText( panel_1, wxID_ANY, wxT("Select your RO client's .exe file:"), wxDefaultPosition, wxDefaultSize, 0 );
	bSizer2->Add( label_1, 0, wxLEFT|wxRIGHT|wxTOP|wxEXPAND, 8 );
	
	wxBoxSizer* bSizer3;
	bSizer3 = new wxBoxSizer( wxHORIZONTAL );
	
	fileInput = new wxTextCtrl( panel_1, wxID_ANY, wxEmptyString, wxDefaultPosition, wxDefaultSize, 0 );
	bSizer3->Add( fileInput, 1, wxLEFT|wxTOP|wxBOTTOM|wxALIGN_CENTER_VERTICAL, 8 );
	
	browseButton = new wxButton( panel_1, wxID_ANY, wxT("..."), wxDefaultPosition, wxDefaultSize, wxBU_EXACTFIT );
	bSizer3->Add( browseButton, 0, wxALL|wxALIGN_CENTER_VERTICAL, 8 );
	
	bSizer2->Add( bSizer3, 0, wxEXPAND, 0 );
	
	alphaSort = new wxCheckBox( panel_1, wxID_ANY, wxT("Sort the result alphabetically"), wxDefaultPosition, wxDefaultSize, 0 );
	alphaSort->SetValue(true);
	
	bSizer2->Add( alphaSort, 0, wxLEFT|wxRIGHT|wxBOTTOM|wxEXPAND, 8 );
	
	progress = new wxGauge( panel_1, wxID_ANY, 100, wxDefaultPosition, wxDefaultSize, wxGA_HORIZONTAL|wxGA_SMOOTH );
	progress->SetValue( 0 ); 
	bSizer2->Add( progress, 0, wxLEFT|wxRIGHT|wxBOTTOM|wxEXPAND|wxADJUST_MINSIZE, 8 );
	
	wxBoxSizer* bSizer4;
	bSizer4 = new wxBoxSizer( wxHORIZONTAL );
	
	aboutButton = new wxButton( panel_1, wxID_ANY, wxT("About"), wxDefaultPosition, wxDefaultSize, 0 );
	bSizer4->Add( aboutButton, 0, wxALL, 8 );
	
	bSizer4->Add( 20, 20, 1, wxEXPAND|wxADJUST_MINSIZE, 0 );
	
	extractButton = new wxButton( panel_1, wxID_ANY, wxT("Extract"), wxDefaultPosition, wxDefaultSize, 0 );
	bSizer4->Add( extractButton, 0, wxLEFT|wxTOP|wxBOTTOM, 8 );
	
	cancelButton = new wxButton( panel_1, wxID_ANY, wxT("Cancel"), wxDefaultPosition, wxDefaultSize, 0 );
	bSizer4->Add( cancelButton, 0, wxALL, 8 );
	
	bSizer2->Add( bSizer4, 0, wxEXPAND, 0 );
	
	panel_1->SetSizer( bSizer2 );
	panel_1->Layout();
	bSizer2->Fit( panel_1 );
	bSizer1->Add( panel_1, 1, wxEXPAND, 0 );
	
	this->SetSizer( bSizer1 );
	this->Layout();
	bSizer1->Fit( this );
}
