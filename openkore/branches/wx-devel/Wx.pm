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

use Interface::Wx::Utils;

our ($iterationTime, $updateUITime, $updateUITime2);

sub new { bless {
	title => '',
}, $_[0] }

sub mainLoop {
	my ($self) = @_;
	
	# Hide console on Win32
	if ($^O eq 'MSWin32' && $sys{wxHideConsole}) {
		eval 'use Win32::Console; Win32::Console->new(STD_OUTPUT_HANDLE)->Free();';
	}
	
	startMainLoop($self->{app} = new Interface::Wx::App);
}

# called only from Interface::writeOutput?
sub iterate {
	my $self = shift;
	
	return unless $self->{app};
	
	if ($self->{app}{iterating} == 0) {
		Plugins::callHook('interface/updateConsole');
	}
	$self->{app}->Yield();
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
	my ($self, $message, %args) = @_;
	
	$args{title} = T('Query') unless defined $args{title};
	$args{cancelable} = 1 unless exists $args{cancelable};

	$message = wrapText($message, 70);
	chomp $message;
	
	my $result;
	do {
		$result = ($args{isPassword} ? \&Wx::GetPasswordFromUser : \&Wx::GetTextFromUser)
		->($message, $args{title});
	} until (defined $result && $result ne '' or $args{cancelable});
	
	return $result;
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
	} until ($result != -1 or $args{cancelable});
	
	return $result;
}

sub writeOutput {
	my ($self, @args) = @_;
	
	if (Plugins::hasHook('interface/output')) {
		Plugins::callHook('interface/output', \@args);
	} else {
		print STDOUT $args[2];
		STDOUT->flush;
	}

	# Make sure we update the GUI. This is to work around the effect
	# of functions that block for a while
	$self->iterate if (timeOut($iterationTime, 0.05));
}

sub title {
	my ($self, $title) = @_;
	
	if ($self->{app} && defined $title && $title ne $self->{title}) {
		$self->{app}{mainFrame}->SetTitle($self->{title} = $title);
	}
	
	return $self->{title};
}

sub displayUsage { print $_[1] }

sub errorDialog {
	my ($self, $msg, $fatal) = @_;
	
	$self->{app}{iterating}++;
	Wx::MessageBox(
		$msg,
		(sprintf '%s - %s', $fatal ? T('Fatal error') : T('Error'), $Settings::NAME),
		$fatal ? wxICON_ERROR : wxICON_EXCLAMATION,
		$self->{app}{mainFrame},
	);
	$self->{app}{iterating}--;
}

sub beep { Wx::Bell }

1;
