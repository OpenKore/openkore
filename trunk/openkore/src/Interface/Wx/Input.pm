#########################################################################
#  OpenKore - WxWidgets Interface
#  Text input control with history support
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
package Interface::Wx::Input;

use strict;
use Wx ':everything';
use base qw(Wx::TextCtrl);
use Wx::Event qw(EVT_TEXT_ENTER EVT_KEY_DOWN);

use constant MAX_INPUT_HISTORY => 150;


sub new {
	my $class = shift;
	my $parent = shift;
	my $self = $class->SUPER::new($parent, 923, '',
		wxDefaultPosition, wxDefaultSize, wxTE_PROCESS_ENTER);
	$self->{history} = [];
	$self->{historyIndex} = -1;
	EVT_TEXT_ENTER($self, 923, \&_onEnter);
	EVT_KEY_DOWN($self, \&_onUpdown);
	return $self;
}

sub onEnter {
	my $self = shift;
	$self->{class} = shift;
	$self->{func} = shift;
}

sub _onEnter {
	my $self = shift;
	my $text = $self->GetValue;

	if ($self->{func}) {
		$self->{func}->($self->{class}, $text);
	}
	$self->Remove(0, -1);

	return if (@{$self->{history}} && $self->{history}[0] eq $text);

	unshift(@{$self->{history}}, $text) if ($text ne "");
	pop @{$self->{history}} if (@{$self->{history}} > MAX_INPUT_HISTORY);
	$self->{historyIndex} = -1;
	undef $self->{currentInput};
}

sub _onUpdown {
	my $self = shift;
	my $event = shift;

	if ($event->GetKeyCode == WXK_UP) {
		if ($self->{historyIndex} < $#{$self->{history}}) {
			$self->{currentInput} = $self->GetValue if (!defined $self->{currentInput});
			$self->{historyIndex}++;
			$self->SetValue($self->{history}[$self->{historyIndex}]);
			$self->SetInsertionPointEnd;
		}

	} elsif ($event->GetKeyCode == WXK_DOWN) {
		if ($self->{historyIndex} > 0) {
			$self->{historyIndex}--;
			$self->SetValue($self->{history}[$self->{historyIndex}]);
			$self->SetInsertionPointEnd;
		} elsif ($self->{historyIndex} == 0) {
			$self->{historyIndex} = -1;
			$self->SetValue($self->{currentInput});
			undef $self->{currentInput};
			$self->SetInsertionPointEnd;
		}

	} else {
		$event->Skip;
	}
}

1;
