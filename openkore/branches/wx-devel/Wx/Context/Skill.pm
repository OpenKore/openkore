package Interface::Wx::Context::Skill;

use strict;
use base 'Interface::Wx::Base::Context';

use Wx ':everything';

use Globals qw/$char %skillsDesc_lut/;
use Translation qw/T TF/;

sub new {
	my ($class, $parent, $objects) = @_;
	
	Scalar::Util::weaken(my $weak = my $self = $class->SUPER::new ($parent));
	
	my @tail;
	
	push @{$self->{head}}, {}, {
		title => @$objects > 3
		? TF('%d skills', scalar @$objects)
		: join '; ', map { $_->getName } @$objects
	};
	
	if (@$objects == 1) {
		my ($object) = @$objects;
		my $target = $object->getTargetType;
		
		if ($target == Skill::TARGET_SELF || $target == Skill::TARGET_ACTORS) {
			push @{$self->{head}}, {}, {title => T('Use on self'), command => "ss " . $object->getIDN};
		}
		
		if ($char->{skills}{$object->getHandle} && $char->{skills}{$object->getHandle}{up}) {
			push @{$self->{head}}, {}, {title => T('Level up'), command => "skills add " . $object->getIDN};
		}
		
		if (my $control = $skillsDesc_lut{$object->getHandle}) {
			chomp $control;
			push @tail, {}, {title => T('Description'), menu => [{title => $control}]};
		}	
	}
	
	push @{$self->{tail}}, reverse @tail;
	return $self;
}

1;
