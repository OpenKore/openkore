package Interface::Wx::Context::Player;

use strict;
use base 'Interface::Wx::Base::Context';

use Wx ':everything';

use Globals qw($char %config %overallAuth @partyUsersID %sex_lut $pvp);
use Translation qw(T TF);
use Utils qw(binFind);

use Interface::Wx::Utils;

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
		my ($ID, $binID, $name) = @{$object}{qw(ID binID name)};
		
		if (
			$object->{party} && $object->{party}{name}
			&& !($char && $char->{party} && $char->{party}{users}{$object->{ID}})
		) {
			push @{$self->{head}}, {
				title => TF('Party: %s', $object->{party}{name})
			}
		} elsif ($char && $char->{party}) {
			unless ($char->{party}{users}{$object->{ID}}) {
				push @{$self->{head}}, {
					title => T('Invite to Party'), command => "party request $name"
				}
			} else {
				push @{$self->{head}}, {
					title => T('Expel from Party'), command => "party kick " . binFind(\@partyUsersID, $ID)
				}
			}
		}
		
		if ($object->{guild}) {
			push @{$self->{head}}, {
				title => TF('Guild: %s [%s]', $object->{guild}{name}, $object->{guild}{title})
			}
		}
		
		push @{$self->{head}}, {};
		
		if ($pvp) {
			push @{$self->{head}}, {
				title => T('Attack'), command => "kill $binID"
			}
		}
		
		push @{$self->{head}}, {
			title => T('Use Skill'), menu => [skillListMenuList(
				sub { $_[0]->getLevel && {
					Skill::TARGET_LOCATION => 1,
					Skill::TARGET_ACTORS => 1,
					$pvp && (Skill::TARGET_ENEMY => 1),
				}->{$_[0]->getTargetType} },
				sub { command => sprintf "sp %d %d", $_[0]->getIDN, $binID }
			)]
		};
		
		push @{$self->{head}}, {
			title => T('Look'), command => "lookp $binID"
		};
		
		push @{$self->{head}}, {};
		
		unless ($config{follow} && $config{followTarget} eq $name) {
			push @{$self->{head}}, {
				title => T('Follow'), command => "follow $binID"
			}
		} else {
			push @{$self->{head}}, {
				title => T('Stop Following'), command => "follow stop"
			}
		}
		
		unless ($config{tankMode} && $config{tankModeTarget} eq $name) {
			push @{$self->{head}}, {
				title => T('Tank'), command => "tank $binID"
			}
		} else {
			push @{$self->{head}}, {
				title => T('Stop Tanking'), command => "tank stop"
			}
		}
		
		push @{$self->{head}}, {};
		
		push @{$self->{head}}, {
			title => T('Show Info'), command => "pl $name"
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
