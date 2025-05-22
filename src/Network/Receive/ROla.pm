package Network::Receive::ROla;

use strict;
use base qw(Network::Receive::ServerType0);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	
	my %packets = (
		'0AE3' => ['received_login_token', 'v l Z20 Z*', [qw(len login_type flag login_token)]],
		'0C32' => ['account_server_info', 'v a4 a4 a4 a4 a26 C x17 a*', [qw(len sessionID accountID sessionID2 lastLoginIP lastLoginTime accountSex serverInfo)]],
	);
	
	$self->{packet_list}{$_} = $packets{$_} for keys %packets;

	my %handlers = qw(
		received_login_token 0AE3
		account_server_info 0C32
	);

	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;
	
	return $self;
}

1;