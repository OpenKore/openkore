#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#########################################################################
package Interface::Wx::CaptchaDialog;

use strict;
use List::Util qw(min);
use Interface::Wx::Utils qw(wxFilePath);
use Wx ':everything';
use Wx::Event qw(EVT_TEXT_ENTER EVT_BUTTON);
use base qw(Wx::Dialog);

use constant DEFAULT_WIDTH => 250;


sub new {
	my ($class, $parent, $imageFile) = @_;
	my $self = $class->SUPER::new($parent, wxID_ANY, 'Captcha', wxDefaultPosition,
		wxDefaultSize, wxDEFAULT_DIALOG_STYLE | wxRESIZE_BORDER);
	$self->_buildGUI ($imageFile);
	return $self;
}

sub getValue {
	my ($self) = @_;
	return $self->{text}->GetValue;
}

sub GetValue {
	&getValue;
}

sub _buildGUI {
	my ($self, $imageFile) = @_;
	my ($sizer, $text, $buttonSizer, $ok, $cancel);

	$sizer = new Wx::BoxSizer(wxVERTICAL);
	
	my $bitmap = new Wx::Bitmap (new Wx::Image (wxFilePath($imageFile), wxBITMAP_TYPE_ANY));
	my $viewport = new Wx::ScrolledWindow ($self, wxID_ANY);
	$viewport->SetScrollRate (8, 8);
	my $imageSizer = new Wx::BoxSizer (wxVERTICAL);
	$imageSizer->Add (new Wx::StaticBitmap ($viewport, wxID_ANY, $bitmap), 0);
	$viewport->SetSizer ($imageSizer);

	my $displayIndex = $self->GetParent ? Wx::Display::GetFromWindow($self->GetParent) : 0;
	my $area = Wx::Display->new($displayIndex == wxNOT_FOUND ? 0 : $displayIndex)->GetClientArea;
	$viewport->SetMinSize ([min($bitmap->GetWidth, int($area->GetWidth * 0.75)),
		min($bitmap->GetHeight, int($area->GetHeight * 0.75))]);
	$sizer->Add ($viewport, 1, wxALL | wxGROW, 8);
	
	$text = new Wx::TextCtrl($self, wxID_ANY, '', wxDefaultPosition,
		[DEFAULT_WIDTH, -1], wxTE_PROCESS_ENTER);
	$sizer->Add($text, 0, wxLEFT | wxRIGHT | wxGROW, 8);
	EVT_TEXT_ENTER($self, $text->GetId, \&_onTextEnter);

	$sizer->AddSpacer(12);

	$buttonSizer = new Wx::BoxSizer(wxHORIZONTAL);
	$sizer->Add($buttonSizer, 0, wxALIGN_CENTER | wxLEFT | wxRIGHT | wxBOTTOM, 8);

	$ok = new Wx::Button($self, wxID_ANY, 'OK', wxDefaultPosition, wxDefaultSize);
	$ok->SetDefault();
	$buttonSizer->Add($ok, 1, wxRIGHT, 8);
	EVT_BUTTON($self, $ok->GetId, \&_onOK);

	$cancel = new Wx::Button($self, wxID_ANY, 'Cancel');
	$buttonSizer->Add($cancel, 1);
	EVT_BUTTON($self, $cancel->GetId, \&_onCancel);

	$self->SetSizerAndFit($sizer);
	$viewport->FitInside;
	$self->{text} = $text;
	$text->SetFocus;
}

sub _onTextEnter {
	my ($self) = @_;
	$self->EndModal(wxID_OK);
}

sub _onOK {
	my ($self) = @_;
	$self->EndModal(wxID_OK);
}

sub _onCancel {
	my ($self) = @_;
	$self->EndModal(wxID_CANCEL);
}

1;
