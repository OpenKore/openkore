#########################################################################
#  OpenKore - WxWidgets Interface
#  Dock control
#
#  Copyright (c) 2004 OpenKore development team 
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
package Interface::Wx::Dock;

use strict;
use Wx ':everything';
use Wx::Event qw(EVT_BUTTON EVT_CLOSE EVT_TIMER);
use Interface::Wx::TitleBar;
use base qw(Wx::Panel);
use File::Spec;


sub new {
	my $class = shift;
	my $parent = shift;
	my $id = shift;
	my $title = shift;
	my $self = $class->SUPER::new($parent, $id);

	my $sizer = $self->{sizer} = new Wx::BoxSizer(wxVERTICAL);
	my $titleBar = $self->{titleBar} = new Interface::Wx::TitleBar($self, $title);
	$titleBar->onDetach(\&detach, $self);
	$titleBar->onClose(\&close, $self);
	$sizer->Add($titleBar, 0, wxGROW);
	$self->SetSizerAndFit($sizer);

	return $self;
}

sub attach {
	my $self = shift;

	if ($self->{dialog}) {
		if ($self->{control}) {
			$self->{control}->Reparent($self);
			$self->{dialogSizer}->Remove($self->{control});
			$self->{sizer}->Add($self->{control}, 1, wxGROW);
		}
		$self->{dialog}->Destroy;
		delete $self->{dialog};
		$self->SetSizerAndFit($self->{sizer});
		$self->Layout;
	}

	$self->{showFunc}->($self->{showFuncSelf}, $self, $self->{showFuncData}) if ($self->{showFunc});
	$self->Show(1);
}

sub detach {
	my $self = shift;
	$self->close;

	my $dialog;
	if ($^O eq 'MSWin32') {
		$dialog = new Wx::MiniFrame($self->{frame}, -1, $self->{titleBar}->title);
	} else {
		$dialog = new Wx::Dialog($self->{frame}, -1, $self->{titleBar}->title);
	}

	if ($self->{control}) {
		my $sizer = $self->{dialogSizer} = new Wx::BoxSizer(wxVERTICAL);
		$self->{control}->Reparent($dialog);
		$self->{sizer}->Remove($self->{control});
		$self->SetSizerAndFit($self->{sizer});
		$self->Layout;
		$sizer->Add($self->{control}, 0, wxGROW);
		$dialog->SetSizer($sizer);
		$dialog->Fit;
	}

	$self->{dialog} = $dialog;
	$dialog->Show(1);
	EVT_CLOSE($dialog, sub { $self->attach; });
}

sub close {
	my $self = shift;
	if ($self->{hideFunc}) {
		$self->{hideFunc}->($self->{hideFuncSelf}, $self, $self->{hideFuncData});
	} else {
		$self->Show(0);
	}
}

sub Fit {
	my $self = shift;
	if ($self->{dialog}) {
		if ($self->{control}) {
			my $size = $self->{control}->GetBestSize;
			my @timers;
			my $set = sub {
				$self->{dialog}->SetClientSize($size->GetWidth, $size->GetHeight);
				foreach (@timers) {
					$_->Stop();
				}
			};

			$set->();
			# We set the size again after some time, to work around a bug
			foreach (10, 100, 500, 1000) {
				my $timer = new Wx::Timer($self->{dialog}, $_);
				EVT_TIMER($self->{dialog}, $_, $set);
				push @timers, $timer;
				$timer->Start($_, 1);
			}
		}
	} else {
		$self->SUPER::Fit(@_);
	}
}

sub title {
	my $self = shift;
	if ($self->{dialog}) {
		if ($_[0]) {
			my $oldTitle = $self->{titleBar}->title;
			if ($oldTitle ne $_[0]) {
				$self->{titleBar}->title($_[0]);
				$self->{dialog}->SetTitle($_[0]);
			}
		} else {
			return $self->{titleBar}->title;
		}
	} else {
		return $self->{titleBar}->title(@_);
	}
}


sub set {
	my $self = shift;
	my $control = shift;
	$self->{control} = $control;
	$self->{sizer}->Add($control, 1, wxGROW);
	$self->SetSizerAndFit($self->{sizer});
}

sub setParentFrame {
	my $self = shift;
	$self->{frame} = shift;
}

sub setShowFunc {
	my $self = shift;
	$self->{showFuncSelf} = shift;
	$self->{showFunc} = shift;
	$self->{showFuncData} = shift;
}

sub setHideFunc {
	my $self = shift;
	$self->{hideFuncSelf} = shift;
	$self->{hideFunc} = shift;
	$self->{hideFuncData} = shift;
}


#### Private stuff ####

sub onDialogClose {
	my $self = shift;

	if ($self->{control}) {
		$self->{control}->Reparent($self);
		$self->{dialogSizer}->Remove($self->{control});
		$self->{sizer}->Add($self->{control}, 1, wxGROW);
		$self->SetSizerAndFit($self->{sizer});
	}

	$self->{dialog}->Destroy;
	undef $self->{dialog};
	$self->attach;
	return 0;
}

sub ShowS {
	my $self = shift;
	my $show = shift;
	if ($show) {
		if ($self->{showFunc}) {
			$self->{showFunc}->($self->{showFuncSelf}, $self, $self->{showFuncData});
		} else {
			$self->SUPER::Show($show);
		}
	} else {
		if ($self->{hideFunc}) {
			$self->{hideFunc}->($self->{hideFuncSelf}, $self, $self->{hideFuncData});
		} else {
			$self->SUPER::Show($show);
		}
	}
}

1;
