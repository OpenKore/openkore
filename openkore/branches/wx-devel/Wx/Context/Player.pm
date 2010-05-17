package Interface::Wx::Context::Player;

use strict;
use base 'Interface::Wx::Base::Context';

use Wx ':everything';

use Globals qw($char %overallAuth @partyUsersID %sex_lut $pvp);
use Translation qw(T TF);
use Utils qw(binFind);

sub new {
	my ($class, $parent, $objects) = @_;
	
	my $self = $class->SUPER::new ($parent);
	
	my @tail;
	
	push @{$self->{head}}, {}, {
		title => @$objects > 3
		? TF('%d Monsters', scalar @$objects)
		: join '; ', map { sprintf
			"%s (%d %s %s)", $_->name, $_->{lv}, $_->job, $sex_lut{$_->{sex}}
		} @$objects
	};
	
	if (@$objects == 1) {
		my ($object) = @$objects;
		my $name = $object->{name};
		
		if ($object->{party} && $object->{party}{name}) {
			push @{$self->{head}}, {
				title => TF('Party: %s', $object->{party}{name})
			}
		}
		
		if ($object->{guild}) {
			push @{$self->{head}}, {
				title => TF('Guild: %s [%s]', $object->{guild}{name}, $object->{guild}{title})
			}
		}
		
		if ($pvp) {
			push @{$self->{head}}, {
				title => T('Attack'), command => "kill $object->{binID}"
			}
		}
		
		push @{$self->{head}}, {};
		
		if ($char && $char->{party}) {
			unless ($char->{party}{users}{$object->{ID}}) {
				push @{$self->{head}}, {
					title => T('Invite to Party'), command => "party request $name"
				}
			} else {
				push @{$self->{head}}, {
					title => T('Expel from Party'), command => "party kick " . binFind(\@partyUsersID, $object->{ID})
				}
			}
		}
		
		push @{$self->{head}}, {
			title => T('Look'), command => "lookp $object->{binID}"
		};
		
		push @{$self->{head}}, {
			title => T('Show Equipment'), command => "showeq p $name"
		};
		
		push @tail, {};
		
		# TODO: check if player if ignored
		push @tail, {
			title => T('Block'), command => "ignore 1 $name"
		};
		push @tail, {
			title => T('Unblock'), command => "ignore 0 $name"
		};
		
		push @tail, {
			title => T('Authorized for Chat Commands'), check => $overallAuth{$name},
			command => sprintf("auth $name %d", $overallAuth{$name} ? 0 : 1)
		};
	}
	
	push @{$self->{tail}}, reverse @tail;
	return $self;
}

1;
