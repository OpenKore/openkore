##########################################################
#  OpenKore - Bus System
#  Bus query object
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#
#  $Revision$
#  $Id$
#
#########################################################################
package Bus::Query;

use strict;
use Time::HiRes qw(time);
use Modules 'register';

# Query state constants.
use constant {
	WAITING => 1,
	DONE    => 2,
	TIMEOUT => 3
};

# See $BusClient->query() for options allowed for the constructor.
sub new {
	my ($class, $args) = @_;
	my $self = bless $args, $class;

	# Invariant: if $state == WAITING: defined($receivedEvent)
	$self->{receivedEvent} = $self->{bus}->onMessageReceived->add($self, \&messageReceived);
	$self->{replies} = [];
	$self->{state} = WAITING;
	$self->{start_time} = time;
	$self->{timeout} ||= 5;

	return $self;
}

sub DESTROY {
	my ($self) = @_;
	if ($self->{receivedEvent}) {
		$self->{bus}->onMessageReceived->remove($self->{receivedEvent});
	}
}

sub getState {
	my ($self) = @_;
	if ($self->{state} == WAITING) {
		if (time - $self->{start_time} > $self->{timeout}) {
			# Timeout for query reached.
			$self->{bus}->onMessageReceived->remove($self->{receivedEvent});
			delete $self->{receivedEvent};

			if (@{$self->{replies}} > 0) {
				$self->{state} = DONE;
				return DONE;
			} else {
				$self->{state} = TIMEOUT;
				return TIMEOUT;
			}
		} else {
			return WAITING;
		}
	} else {
		return $self->{state};
	}
}

sub getReply {
	my ($self) = @_;
	if (@{$self->{replies}}) {
		my $message = shift @{$self->{replies}};
		return @{$message};
	} else {
		return undef;
	}
}

sub messageReceived {
	my ($self, undef, $message) = @_;
	if ($self->{state} == WAITING && $message->{args}{SEQ} == $self->{seq} && $message->{args}{IRY}) {
		# A reply has been received.
		push @{$self->{replies}}, [$message->{messageID}, $message->{args}];

		if (!$self->{collectAll}) {
			# This query needs only one reply, so stop immediately.
			$self->{bus}->onMessageReceived->remove($self->{receivedEvent});
			delete $self->{receivedEvent};
			$self->{state} = DONE;
		}
	}
}

1;
