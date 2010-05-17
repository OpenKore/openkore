package Interface::Wx::Context::CartItem;

use strict;
use base 'Interface::Wx::Context::Item';

use Globals qw/%storage/;
use Translation qw/T TF/;

sub new {
	my ($class, $parent, $objects) = @_;
	
	Scalar::Util::weaken(my $weak = my $self = $class->SUPER::new ($parent, $objects));
	
	push @{$self->{head}}, {};
	my @invIndexes = map { $_->{index} } @$objects;
	push @{$self->{head}}, {
		title => T('Move to inventory'),
		command => join ';;', map { "cart get $_" } @invIndexes
	};
	push @{$self->{head}}, {
		title => T('Move to storage'),
		command => join ';;', map { "storage addfromcart $_" } @invIndexes
	} if %storage && $storage{opened};
	
	return $self;
}

1;
