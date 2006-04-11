#include "view.h"

View::View()
	: MainFrame(NULL, -1, "",  wxDefaultPosition, wxDefaultSize, 0)
{
	int width, height;

	GetClientSize(&width, &height);
	SetClientSize(350, height);
	Connect(browseButton->GetId(), wxEVT_COMMAND_BUTTON_CLICKED,
		wxCommandEventHandler(View::onBrowseClick));
	Connect(extractButton->GetId(), wxEVT_COMMAND_BUTTON_CLICKED,
		wxCommandEventHandler(View::onExtractClick));
	Connect(cancelButton->GetId(), wxEVT_COMMAND_BUTTON_CLICKED,
		wxCommandEventHandler(View::onCancelClick));
}

View::~View() {
}

void
View::onBrowseClick(wxCommandEvent &event)
{

}

void
View::onExtractClick(wxCommandEvent &event)
{

}

void
View::onCancelClick(wxCommandEvent &event)
{
	Close();
}
