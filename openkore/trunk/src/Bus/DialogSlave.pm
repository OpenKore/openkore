package Bus::DialogSlave;

use strict;
use Scalar::Util qw(refaddr);
use Exception::Class ('Bus::DialogSave::AlreadyAccepted');

sub new {
	my ($class, $args) = @_;
	my $self = bless $args, $class;
	return $self;
}

sub DESTROY {
	my ($self) = @_;
	if (!$self->{accepted}) {
		$self->{bus}->send("REFUSED", {
			TO  => $self->{peerID},
			SEQ => $self->{seq},
			IRY => 1
		});
	} else {
		$self->{bus}->onMessageReceived->remove($self->{receivedEvent});
	}
}

sub accept {
	my ($self) = @_;
	if ($self->{accepted}) {
		Bus::DialogSave::AlreadyAccepted->throw("The dialog is already accepted.");
	} else {
		$self->{accepted} = 1;
		$self->{receivedEvent} = $self->{bus}->onMessageReceived->add($self, \&messageReceived);
		$self->{dialogID} = refaddr($self);
		$self->{bus}->send("ACCEPTED", {
			TO       => $self->{peerID},
			SEQ      => $self->{seq},
			IRY      => 1,
			dialogID => $self->{dialogID}
			
		});
	}
}

sub getQuery {
	my ($self) = @_;
	if ($self->{query}) {
		my $query = $self->{query};
		delete $self->{query};
		return @{$query};
	} else {
		return undef;
	}
}

sub reply {
	my ($self, $MID, $args) = @_;
	my %args2;
	%args2 = %{$args} if ($args);
	$args2{TO}  = $self->{peerID};
	$args2{SEQ} = $self->{currentSeq};
	$args2{IRY} = 1;
	$self->{bus}->send($MID, \%args2);
}

sub messageReceived {
	my ($self, undef, $message) = @_;
	my $args = $message->{args};
	if ($args->{dialogID} eq $self->{dialogID} && $args->{FROM} eq $self->{peerID}) {
		# We received a new query for this dialog.
		$self->{query} = [$message->{messageID}, $args];
		$self->{currentSeq} = $args->{SEQ};
	}
}

1;
