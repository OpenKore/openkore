package Interface::Wx::Context::Skill;

use strict;
use base 'Interface::Wx::Base::Context';

use Wx ':everything';

use Globals qw/$char %config %skillsDesc_lut/;
use Translation qw/T TF/;

sub new {
	my ($class, $parent, $objects) = @_;
	
	Scalar::Util::weaken(my $weak = my $self = $class->SUPER::new ($parent));
	
	my @tail;
	
	push @{$self->{head}}, {}, {
		title => @$objects > 3
		? TF('%d Skills', scalar @$objects)
		: join '; ', map { $_->getName } @$objects
	};
	
	if (@$objects == 1) {
		my ($object) = @$objects;
		my $handle = $object->getHandle;
		my $target = $object->getTargetType;
		
		if (
			$char->{skills}{$handle} && $char->{skills}{$handle}{lv}
			&& {Skill::TARGET_SELF => 1, Skill::TARGET_ACTORS => 1}->{$target}
		) {
			push @{$self->{head}}, {}, {title => T('Use on Self'), command => "ss " . $object->getIDN};
		}
		
		if ($char->{skills}{$handle} && $char->{skills}{$handle}{up} && $char->{points_skill}) {
			push @{$self->{head}}, {}, {title => T('Level Up'), command => "skills add " . $object->getIDN};
		}
		
		if ($char->{skills}{SA_AUTOSPELL} && $char->{skills}{SA_AUTOSPELL}{lv}) {
			# TODO: Network::Receive::sage_autospell lacks skill list parsing. Add check here and command for single use
			my $check = $config{autoSpell} && Skill->new(auto => $config{autoSpell})->getHandle eq $object->getHandle;
			push @tail, {}, {
				title => Skill->new(handle => 'SA_AUTOSPELL')->getName,
				check => $check,
				callback => sub { Misc::bulkConfigModify({autoSpell => $check ? undef : $handle}, 1) }
			}
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
