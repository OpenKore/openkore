package Bus::DialogMaster;

use strict;
use Scalar::Util qw(refaddr);
use Modules 'register';
use Bus::Query;

use constant {
	STARTING   => 1,
	ENGAGED    => 2,
	TERMINATED => 3,
	TIMEOUT    => 4
};

# struct Bus::Dialog {
#     Bus::Client bus;
#     Bytes  peerID;
#     Bytes  dialogID;
#     Bytes  peerDialogID;
#     String reason;
#     Hash   args;
#     int    timeout;
#     int    state;
# }

sub new {
	my ($class, $args) = @_;
	my $self = bless $args, $class;
	my $bus = $self->{bus};

	$self->{timeout} ||= 5;
	$self->{receivedEvent} = $bus->onMessageReceived->add($self, \&messageReceived);
	$self->{query} = $bus->query("REQUEST_DIALOG", {
			TO       => $self->{peerID},
			reason   => $self->{reason},
			dialogID => refaddr($self),
			%{$self->{args}}
		}, {
			timeout => $self->{timeout}
		}
	);
	$self->{state} = STARTING;

	return $self;
}

sub DESTROY {
	my ($self) = @_;
	$self->{bus}->onMessageReceived->remove($self->{receivedEvent});
}

sub iterate {
	my ($self) = @_;
	if ($self->{state} == STARTING) {
		# Waiting for peer to accept dialog.
		my $query = $self->{query};
		if ($query->getState() == Bus::Query::DONE) {
			print "DialogMaster - Got reply for dialog request\n";
			my ($MID, $args) = $query->getReply();
			if ($MID eq "ACCEPTED") {
				# Dialog accepted.
				print "DialogMaster - Dialog accepted\n";
				$self->{state} = ENGAGED;
				$self->{peerDialogID} = $args->{dialogID};
			} else {
				# Dialog not accepted.
				print "DialogMaster - Dialog refused\n";
				$self->{state} = TERMINATED;
			}
			delete $self->{query};

		} elsif ($query->getState() == Bus::Query::TIMEOUT) {
			# Dialog not approved within time limit.
			print "DialogMaster - Start timeout\n";
			$self->{state} = TIMEOUT;
			delete $self->{query};
		}

	} elsif ($self->{state} == ENGAGED && (my $query = $self->{query})) {
		if ($query->getState() == Bus::Query::DONE) {
			my @reply = $query->getReply();
			$self->{reply} = \@reply;
			delete $self->{query};
		} elsif ($query->getState() == Bus::Query::TIMEOUT) {
			$self->{state} = TIMEOUT;
			delete $self->{query};
		}
	}
}

sub getState {
	my ($self) = @_;
	$self->iterate();
	return $self->{state};
}

##
# $Bus_Dialog->query(String messageID, args, Hash options)
sub query {
	my ($self, $MID, $args, $options) = @_;
	$self->iterate();
	if ($self->{query} || $self->{reply}) {
		die "Do not send another query without receiving the previous reply first.";
	} else {
		my %args2 = ($args) ? %{$args} : ();
		$args2{TO}       = $self->{peerID};
		$args2{dialogID} = $self->{peerDialogID};
		$self->{query} = $self->{bus}->query($MID, \%args2, $options);
	}
}

##
# Tuple $Bus_Dialog->getReply()
#
# Returns a an array with two items: the message ID and the message arguments.
sub getReply {
	my ($self) = @_;
	$self->iterate();
	my $reply = $self->{reply};
	delete $self->{reply};
	return @{$reply};
}

sub messageReceived {
	my ($self, undef, $message) = @_;
	my $state = $self->{state};
	my $MID   = $message->{messageID};
	my $args  = $message->{args};

	if (($state == STARTING || $state == ENGAGED) && $MID eq 'LEAVE' && $args->{clientID} eq $self->{peerID}) {
		$self->iterate();
		$self->{state} = TERMINATED;
	}
}

1;
