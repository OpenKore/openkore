package Base::Ragnarok::SessionStore;

use strict;
use Time::HiRes qw(time);
use Carp::Assert;

use constant SESSION_TIMEOUT => 60;

sub new {
	my ($class) = @_;
	my %self = (
		sessions => {},
		sessionsByTime => [],
		sessionCount => 0
	);
	return bless \%self, $class;
}

sub add {
	my ($self, $session) = @_;
	assert(defined $session->{sessionID}) if DEBUG;
	$session->{time} = time;
	$self->{sessions}{$session->{sessionID}} = $session;
	push @{$self->{sessionsByTime}}, $session;
}

sub get {
	my ($self, $sessionID) = @_;
	return $self->{sessions}{$sessionID};
}

sub getIndex {
	my ($self, $session) = @_;
	for (my $i = 0; $i < @{$self->{sessionsByTime}}; $i++) {
		if ($self->{sessionsByTime}[$i] == $session) {
			return $i;
		}
	}
	return -1;
}

sub mark {
	my ($self, $sessionID) = @_;
	my $session = $self->{sessions}{$sessionID};
	if ($session) {
		my $index = $self->getIndex($session);
		$session->{time} = time;
		splice(@{$self->{sessionsByTime}}, $index, 1);
		push @{$self->{sessionsByTime}}, $session;
	}
}

sub remove {
	my ($self, $sessionID) = @_;
	my $session = $self->{sessions}{$sessionID};
	if ($session) {
		my $index = $self->getIndex($session);
		splice(@{$self->{sessionsByTime}}, $index, 1);
	}
}

sub removeTimedOutSessions {
	my ($self) = @_;
	while (@{$self->{sessionsByTime}} && time - $self->{sessionsByTime}[0]{time} > SESSION_TIMEOUT) {
		my $sessionID = $self->{sessionsByTime}[0]{sessionID};
		delete $self->{sessions}{$sessionID};
		shift @{$self->{sessionsByTime}};
	}
}

##
# int $Base_Ragnarok_SessionStore->generateSessionID()
#
# Generate a unique session ID.
sub generateSessionID {
	my ($self) = @_;
	my $ID = $self->{sessionCount};
	$self->{sessionCount} = ($self->{sessionCount} + 1) % 0xFFFFFFFF;
	return $ID;
}

1;