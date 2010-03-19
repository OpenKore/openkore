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

use base 'Wx::Dialog';

use Wx ':everything';
use Wx::Event ':everything';

use Globals qw/%config $messageSender/;
use Translation qw/T TF/;

use constant DEFAULT_WIDTH => 250;

my $hooks = Plugins::addHooks(
	['captcha_file', \&onCaptcha],
);

Plugins::register('wx-captcha', 'GUI captcha dialog for Wx', sub { Plugins::delHooks($hooks) });

sub new {
	my ($class, $parent, $imageFile) = @_;
	my $self = $class->SUPER::new($parent, wxID_ANY, T('Captcha'));
	$self->_buildGUI($imageFile);
	return $self;
}

sub _buildGUI {
	my ($self, $imageFile) = @_;
	my ($sizer, $image, $text, $buttonSizer, $ok, $cancel);

	$sizer = new Wx::BoxSizer(wxVERTICAL);
	
	$image = new Wx::StaticBitmap ($self, wxID_ANY, new Wx::Bitmap (new Wx::Image ($imageFile, wxBITMAP_TYPE_ANY)));
	
	$sizer->Add ($image, 1, wxALL, 8);
	
	$text = new Wx::TextCtrl($self, wxID_ANY, '', wxDefaultPosition,
		[DEFAULT_WIDTH, -1], wxTE_PROCESS_ENTER);
	$sizer->Add($text, 0, wxLEFT | wxRIGHT | wxGROW, 8);
	EVT_TEXT_ENTER($self, $text->GetId, sub { $_[0]->EndModal(wxID_OK) });

	$sizer->AddSpacer(12);

	$buttonSizer = new Wx::BoxSizer(wxHORIZONTAL);
	$sizer->Add($buttonSizer, 0, wxALIGN_CENTER | wxLEFT | wxRIGHT | wxBOTTOM, 8);

	$ok = new Wx::Button($self, wxID_ANY, T('OK'), wxDefaultPosition, wxDefaultSize);
	$ok->SetDefault();
	$buttonSizer->Add($ok, 1, wxRIGHT, 8);
	EVT_BUTTON($self, $ok->GetId, sub { $_[0]->EndModal(wxID_OK) });

	$cancel = new Wx::Button($self, wxID_ANY, T('Cancel'));
	$buttonSizer->Add($cancel, 1);
	EVT_BUTTON($self, $cancel->GetId, sub { $_[0]->EndModal(wxID_CANCEL) });

	$self->SetSizerAndFit($sizer);
	$self->{text} = $text;
}

sub GetValue { $_[0]->{text}->GetValue }

# static

sub onCaptcha {
	my (undef, $args) = @_;
	
	return unless $config{wx_captcha};
	
	my $dialog = new Interface::Wx::CaptchaDialog(undef, $args->{file});
	my $result = ($dialog->ShowModal == wxID_OK) ? $dialog->GetValue : '';
	$dialog->Destroy;
	
	unless ($result eq '') {
		$messageSender->sendCaptchaAnswer($result);
		$args->{return} = 1;
	}
}

1;
