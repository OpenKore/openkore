package Network::Receive::kRO::RagexeRE_2011_11_02a;

use strict;
use base qw(Network::Receive::kRO::RagexeRE_2011_10_05a);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	
	my %packets = (
		'08B9' => ['account_id', 'x4 a4 x2', [qw(accountID)]], # 12
	);
	foreach my $switch (keys %packets) {
		$self->{packet_list}{$switch} = $packets{$switch};
	}
	
	return $self;
} 
1;
