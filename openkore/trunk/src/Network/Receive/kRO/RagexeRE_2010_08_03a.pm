package Network::Receive::kRO::RagexeRE_2010_08_03a;

use strict;
use base qw(Network::Receive::kRO::RagexeRE_2010_07_14a);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	
	my %packets = (
		'0839' => ['guild_expulsion', 'Z40 Z24', [qw(message name)]],
	);
	foreach my $switch (keys %packets) {
		$self->{packet_list}{$switch} = $packets{$switch};
	}
	
	return $self;
}

1;
