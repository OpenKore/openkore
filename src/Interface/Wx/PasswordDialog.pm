#########################################################################
#  OpenKore - WxWidgets Interface
#  Password input dialog
#
#  Copyright (c) 2006,2007 OpenKore development team
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#
#  $Revision$
#  $Id$
#
#########################################################################
package Interface::Wx::PasswordDialog;

use strict;
use Wx ':everything';
use Wx::Event qw(EVT_TEXT_ENTER EVT_BUTTON);
use base qw(Wx::Dialog);

use Translation qw/T TF/;

use constant DEFAULT_WIDTH => 250;


sub new {
	my ($class, $parent, $message, $title) = @_;
	$title = T('Enter password') if (!defined($title));
	my $self = $class->SUPER::new($parent, wxID_ANY, $title);
	$self->_buildGUI($message);
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
	my ($self, $message) = @_;
	my ($sizer, $label, $text, $buttonSizer, $ok, $cancel);

	$sizer = new Wx::BoxSizer(wxVERTICAL);
	$label = new Wx::StaticText($self, wxID_ANY, $message);
	$sizer->Add($label, 0, wxALL, 8);

	$text = new Wx::TextCtrl($self, wxID_ANY, '', wxDefaultPosition,
		[DEFAULT_WIDTH, -1], wxTE_PASSWORD | wxTE_PROCESS_ENTER);
	$sizer->Add($text, 0, wxLEFT | wxRIGHT | wxGROW, 8);
	EVT_TEXT_ENTER($self, $text->GetId, \&_onTextEnter);

	$sizer->AddSpacer(12);

	$buttonSizer = new Wx::BoxSizer(wxHORIZONTAL);
	$sizer->Add($buttonSizer, 0, wxALIGN_CENTER | wxLEFT | wxRIGHT | wxBOTTOM, 8);

	$ok = new Wx::Button($self, wxID_ANY, T('OK'), wxDefaultPosition, wxDefaultSize);
	$ok->SetDefault();
	$buttonSizer->Add($ok, 1, wxRIGHT, 8);
	EVT_BUTTON($self, $ok->GetId, \&_onOK);

	$cancel = new Wx::Button($self, wxID_ANY, T('Cancel'));
	$buttonSizer->Add($cancel, 1);
	EVT_BUTTON($self, $cancel->GetId, \&_onCancel);

	$self->SetSizerAndFit($sizer);
	$self->{text} = $text;
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
