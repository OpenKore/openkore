# bRO (Brazil): Odin
package Network::Send::bRO;
use strict;

use base 'Network::Send::ServerType0';

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	
	my %handlers = qw(
		master_login 02B0
		buy_bulk_vender 0801
	);
	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;
	
	return $self;
}

1;
