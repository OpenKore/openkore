package Interface::Wx::Context::StorageItem;

use strict;
use base 'Interface::Wx::Context::Item';

use Globals qw/$char/;
use Translation qw/T TF/;

sub new {
	my ($class, $parent, $objects) = @_;
	
	Scalar::Util::weaken(my $weak = my $self = $class->SUPER::new ($parent, $objects));
	
	push @{$self->{head}}, {};
	my @invIndexes = map { $_->{binID} } @$objects;
	push @{$self->{head}}, {
		title => T('Move to inventory'),
		command => "storage get " . (join ',', @invIndexes)
	};
	push @{$self->{head}}, {
		title => T('Move to cart'),
		command => join ';;', map { "storage gettocart $_" } @invIndexes
	} if $char->cartActive;
	
	return $self;
}

1;
