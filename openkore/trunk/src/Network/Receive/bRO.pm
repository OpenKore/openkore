# bRO (Brazil): Odin
package Network::Receive::bRO;
use strict;

use base 'Network::Receive::ServerType0';

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	my %packets = (
		'0097' => ['private_message', 'v Z24 V Z*', [qw(len privMsgUser flag privMsg)]], # -1
	);

	foreach my $switch (keys %packets) {
		$self->{packet_list}{$switch} = $packets{$switch};
	}

	return $self;
}

1;