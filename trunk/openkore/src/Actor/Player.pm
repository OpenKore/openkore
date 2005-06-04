package Actor::Player;
use strict;
our @ISA = qw(Actor);

sub new {
	return bless({type => 'Player'});
}

1;
