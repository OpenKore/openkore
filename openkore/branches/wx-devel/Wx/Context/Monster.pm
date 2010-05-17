package Interface::Wx::Context::Monster;

use strict;
use base 'Interface::Wx::Base::Context';

use Wx ':everything';

use Globals qw/$char %config %itemsDesc_lut %shop %arrowcraft_items %items_control %pickupitems/;
use Misc qw/mon_control/;
use Translation qw/T TF/;
use Utils qw/formatNumber/;

sub new {
	my ($class, $parent, $objects) = @_;
	
	my $self = $class->SUPER::new ($parent);
	
	my @tail;
	
	push @{$self->{head}}, {}, {
		title => @$objects > 3
		? TF('%d Monsters', scalar @$objects)
		: join '; ', map { $_->name ne $_->{name_given} ? sprintf("%s (%s)", $_->name, $_->{name_given}) : $_->name } @$objects
	};
	
	if (@$objects == 1) {
		my ($object) = @$objects;
		my $name = $object->{name};
		
		push @{$self->{head}}, {}, {title => T('Attack'), command => "a $object->{binID}"};
	}
	
	push @{$self->{tail}}, reverse @tail;
	return $self;
}

1;
