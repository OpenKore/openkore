package Network::Receive::ROla;

use strict;
use base qw(Network::Receive::ServerType0);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	
	my %packets = (
		'0C32' => ['account_server_info', 'v a4 a4 a4 a4 a26 C x17 a*', [qw(len sessionID accountID sessionID2 lastLoginIP lastLoginTime accountSex serverInfo)]],
	);
	
	$self->{packet_list}{$_} = $packets{$_} for keys %packets;

	my %handlers = qw(
		account_server_info 0C32
	);

	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;
	
	return $self;
}

1;