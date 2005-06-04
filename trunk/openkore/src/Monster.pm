package Monster;
use strict;
our @ISA = qw(Actor);

sub new {
	return bless({type => 'Monster'});
}

1;
