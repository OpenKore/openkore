package Bus::MessageParser;

use strict;
use bytes;
no encoding 'utf8';
use Bus::Messages qw(unserialize);

sub new {
	my ($class) = @_;
	my %self = (buffer => '');
	return bless \%self, $class;
}

sub add {
	my $self = $_[0];
	$self->{buffer} .= $_[1];
}

sub readNext {
	my ($self, $ID) = @_;
	my $processed;
	my $args = unserialize($self->{buffer}, $ID, \$processed);
	if ($args) {
		substr($self->{buffer}, 0, $processed, '');
	}
	return $args;
}

1;