#########################################################################
#  OpenKore - Bus system
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#
#  $Revision: 3328 $
#  $Id: Processors.pm 3328 2005-09-28 16:50:58Z hongli $
#
#########################################################################
##
# MODULE DESCRIPTION: Default OpenKore bus message handlers.

package Bus::Handlers;

use strict;
use Modules 'register';
use Globals qw(%maps_lut $net);
use Network;
use Log qw(message debug);


sub new {
	my ($class, $bus) = @_;
	my $self = bless {}, $class;
	$self->{bus} = $bus;
	$self->{receivedEvent} = $bus->onMessageReceived->add($self, \&process);
	return $self;
}

sub DESTROY {
	my ($self) = @_;
	$self->{bus}->onMessageReceived->remove($self->{receivedEvent});
}

sub process {
	my ($self, undef, undef, $args) = @_;

	my $MID = $args->{messageID};
	$args = $args->{args};
	if (my $handler = $self->can("handle$MID")) {
		debug "Bus - handling message '$MID'.\n", "busHandlers";
		$self->{currentFrom} = $args->{FROM};
		$self->{currentSeq}  = $args->{SEQ};
		$handler->($self, $args);
		delete $self->{currentFrom};
		delete $self->{currentSeq};
	} else {
		debug "Bus - unhandled message '$MID' received.\n", "busHandlers";
	}
}

# Send a reply for the current query.
sub sendReply {
	my ($self, $MID, $args) = @_;
	if (exists $self->{currentSeq}) {
		my %args2;
		%args2 = %{$args} if ($args);
		$args2{TO}  = $self->{currentFrom};
		$args2{SEQ} = $self->{currentSeq};
		$args2{IRY} = 1;
		$self->{bus}->send($MID, \%args2);
	}
}


########### Command and query handlers ###########

sub handleMoveTo {
	my ($self, $args) = @_;
	if ($net->getState() == Network::IN_GAME) {
		my $map = $args->{field};
		my $mapDesc = $maps_lut{"${map}.rsw"};
		message "On route to: $mapDesc ($map): $args->{x}, $args->{y}\n";
		main::ai_route($args->{field}, $args->{x}, $args->{y},
			attackOnRoute => 1);
	}
}

sub handleDialog {
	my ($self, $args) = @_;
	if ($net->getState() == Network::IN_GAME && $args->{type}) {
		if (my $handler = $self->can("dialog$args->{type}")) {
			$handler->call($self, $args);
		}
	}
}

sub handleJobRequest {
	my ($self, $args) = @_;
	if ($net->getState() == Network::IN_GAME && $args->{type}) {
		if (my $handler = $self->can("job$args->{type}")) {
			$handler->call($self, $args);
		}
	}
}


########### Job handlers ###########

sub jobTransferItems {
	my ($self) = @_;
	$self->sendReply("JobRequest", { quality => 1 });
	message "Replied to TransferItems job request.\n";
}


########### Dialog handlers ###########

sub dialogSecretMeeting {
	
}

1;
