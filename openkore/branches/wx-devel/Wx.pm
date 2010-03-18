#########################################################################
#  OpenKore - WxWidgets Interface
#  You need:
#  * WxPerl (the Perl bindings for WxWidgets) - http://wxperl.sourceforge.net/
#
#  More information about WxWidgets here: http://www.wxwidgets.org/
#
#  Copyright (c) 2004,2005,2006,2007 OpenKore development team
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
#  $Revision$
#  $Id$
#
#########################################################################
package Interface::Wx;

# Note: don't use wxTimer for anything important. It's known to cause reentrancy issues!

# Note: some wx constants are defined by Wx::Event only if corresponding events are imported

# Note: segfault can be triggered by creating Wx::Windows's with wrong parent (or without one at all)

BEGIN {
	require Wx::Perl::Packager if ($^O eq 'MSWin32');
}

use strict;
use Wx ':everything';
use Wx::Event ':everything';
use Time::HiRes qw(time sleep);
use File::Spec;
use FindBin qw($RealBin);


use Globals;
use Interface;
use base 'Interface';
use Modules;
use Field;
use I18N qw/bytesToString/;

use Interface::Wx::App;
use AI;
use Settings qw(%sys);
use Plugins;
use Misc;
use Commands;
use Utils qw/timeOut wrapText/;
use Translation qw/T TF/;

our ($iterationTime, $updateUITime, $updateUITime2);

sub new { bless {
	title => '',
	iterating => 0,
}, $_[0] }

sub mainLoop {
	my ($self) = @_;
	
	$self->{app} = new Interface::Wx::App;
	
	# Hide console on Win32
	if ($^O eq 'MSWin32' && $sys{wxHideConsole}) {
		eval 'use Win32::Console; Win32::Console->new(STD_OUTPUT_HANDLE)->Free();';
	}
	
	# Start the real main loop in 100 msec, so that the UI has
	# the chance to layout correctly.
	EVT_TIMER($self->{app}{mainFrame}, (
		my $timer = new Wx::Timer($self->{app}{mainFrame})
	)->GetId, sub { $self->realMainLoop });
	$timer->Start(100, 1);
	
	$self->{app}->MainLoop;
}

sub realMainLoop {
	my ($self) = @_;
	my $timer = new Wx::Timer($self->{app}{mainFrame});
	my $sleepTime = $config{sleepTime};
	my $quitting;
	my $sub = sub {
		return if ($quitting);
		if ($quit) {
			$quitting = 1;
			$self->{app}->ExitMainLoop;
			$timer->Stop;
			return;
		} elsif ($self->{iterating}) {
			return;
		}

		$self->{iterating}++;

		if ($sleepTime ne $config{sleepTime}) {
			$sleepTime = $config{sleepTime};
			$timer->Start(($sleepTime / 1000) > 0
				? ($sleepTime / 1000)
				: 10);
		}
		main::mainLoop();

		$self->{iterating}--;
	};

	EVT_TIMER($self->{app}{mainFrame}, $timer->GetId, $sub);
	$timer->Start(($sleepTime / 1000) > 0
		? ($sleepTime / 1000)
		: 10);
}

sub iterate {
	my $self = shift;

	if ($self->{iterating} == 0) {
		$self->{app}{mainFrame}->Refresh; # for console it was
		$self->{app}{mainFrame}->Update;
	}
	$self->{app}{mainFrame}->Yield();
	$iterationTime = time;
}

sub getInput {
	my $self = shift;
	my $timeout = shift;
	my $msg;

	if ($timeout < 0) {
		while (!defined $self->{input} && !$quit) {
			$self->iterate;
			sleep 0.01;
		}
		$msg = $self->{input};

	} elsif ($timeout == 0) {
		$msg = $self->{input};

	} else {
		my $begin = time;
		until (defined $self->{input} || time - $begin > $timeout || $quit) {
			$self->iterate;
			sleep 0.01;
		}
		$msg = $self->{input};
	}

	undef $self->{input};
	undef $msg if (defined($msg) && $msg eq "");

	# Make sure we update the GUI. This is to work around the effect
	# of functions that block for a while
	$self->iterate if (timeOut($iterationTime, 0.05));

	return $msg;
}

sub query {
	my $self = shift;
	my $message = shift;
	my %args = @_;

	$args{title} = "Query" if (!defined $args{title});
	$args{cancelable} = 1 if (!exists $args{cancelable});

	$message = wrapText($message, 70);
	$message =~ s/\n$//s;
	my $dialog;
	if ($args{isPassword}) {
		# WxPerl doesn't support wxPasswordEntryDialog :(
		$dialog = new Interface::Wx::PasswordDialog($self->{frame}, $message, $args{title});
	} else {
		$dialog = new Wx::TextEntryDialog($self->{frame}, $message, $args{title});
	}
	while (1) {
		my $result;
		if ($dialog->ShowModal == wxID_OK) {
			$result = $dialog->GetValue;
		}
		if (!defined($result) || $result eq '') {
			if ($args{cancelable}) {
				$dialog->Destroy;
				return undef;
			}
		} else {
			$dialog->Destroy;
			return $result;
		}
	}
}

sub showMenu {
	my ($self, $message, $choices, %args) = @_;
	
	$args{title} = T('Menu') unless defined $args{title};
	$args{cancelable} = 1 unless exists $args{cancelable};
	
	$message = wrapText($message, 70);
	chomp $message;
	
	my $result;
	do {
		$result = Wx::GetSingleChoiceIndex($message, $args{title}, $choices, $self->{app}{mainFrame})
	} until $result != -1 || $args{cancelable};
	
	return $result;
}
=pod
sub showMenu {
	my $self = shift;
	my $message = shift;
	my $choices = shift;
	my %args = @_;

	$args{title} = "Menu" if (!defined $args{title});
	$args{cancelable} = 1 if (!exists $args{cancelable});

	$message = wrapText($message, 70);
	$message =~ s/\n$//s;
	my $dialog = new Wx::SingleChoiceDialog($self->{frame},
		$message, $args{title}, $choices);
	while (1) {
		my $result;
		if ($dialog->ShowModal == wxID_OK) {
			$result = $dialog->GetSelection;
		}
		if (!defined($result)) {
			if ($args{cancelable}) {
				$dialog->Destroy;
				return -1;
			}
		} else {
			$dialog->Destroy;
			return $result;
		}
	}
}
=cut
sub writeOutput {
	my ($self, @args) = @_;
	
	Plugins::callHook('interface/writeOutput', \@args);
	# Make sure we update the GUI. This is to work around the effect
	# of functions that block for a while
	$self->iterate if (timeOut($iterationTime, 0.05));
}

sub title {
	my ($self, $title) = @_;
	
	if (defined $title && $title ne $self->{title}) {
		$self->{app}{mainFrame}->SetTitle($self->{title} = $title);
	}
	
	return $self->{title};
}

sub displayUsage { print $_[1] }

sub errorDialog {
	my ($self, $msg, $fatal) = @_;
	
	$self->{iterating}++;
	Wx::MessageBox(
		$msg,
		(sprintf '%s - %s', $fatal ? T('Fatal error') : T('Error'), $Settings::NAME),
		$fatal ? wxICON_ERROR : wxICON_EXCLAMATION,
		$self->{app}{mainFrame},
	);
	$self->{iterating}--;
}

sub beep { Wx::Bell }

1;
