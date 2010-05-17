package Interface::Wx::Context::NPC;

use strict;
use base 'Interface::Wx::Base::Context';

use Wx ':everything';

use Globals qw/%config $field %portals_lut %maps_lut/;
use Translation qw/T TF/;

sub new {
	my ($class, $parent, $objects) = @_;
	
	Scalar::Util::weaken(my $weak = my $self = $class->SUPER::new ($parent));
	
	my @tail;
	
	push @{$self->{head}}, {}, {
		title => @$objects > 3
		? TF('%d NPCs', scalar @$objects)
		: join '; ', map { sprintf "%s (%s, %s)", $_->name, @{$_->{pos_to}}{qw(x y)}} @$objects
	};
	
	if (@$objects == 1) {
		my ($object) = @$objects;
		my $location = sprintf "%s %d %d", $field->name, @{$object->{pos_to}}{qw(x y)};
		
		push @{$self->{head}}, {}, {title => T('Talk'), command => "talk $object->{binID}"};
		
		if ($config{storageAuto_npc} eq $location) {
			push @{$self->{head}}, {
				title => T('Open Storage'),
				command => sprintf "talknpc %d %d %s", @{$object->{pos_to}}{qw(x y)}, $config{storageAuto_npc_steps}
			};
		}
		
		push @tail, {};
		push @tail, {
			title => T('Auto-sell disabled'),
			radio => !$config{sellAuto},
			callback => sub { Misc::bulkConfigModify({sellAuto => 0}, 1) }
		};
		push @tail, {
			title => TF('Auto-sell as configured (%s)', $config{sellAuto_npc}),
			radio => $config{sellAuto},
			callback => sub { Misc::bulkConfigModify({sellAuto => 1}, 1) }
		} if $config{sellAuto_npc} && $config{sellAuto_npc} ne $location;
		push @tail, {
			title => T('Auto-sell with this NPC'),
			radio => $config{sellAuto} && $config{sellAuto_npc} eq $location,
			callback => sub { Misc::bulkConfigModify({sellAuto => 1, sellAuto_npc => $location}, 1) }
		};
	}
	
	my @portals;
	for (@$objects) {
		if (my $portal = $portals_lut{sprintf "%s %d %d", $field->name, @{$_->{pos_to}}{qw(x y)}}) {
			for (values %{$portal->{dest}}) {
				push @portals, {
					title => TF(
						'Move to %s (%s %d, %d)%s',
						$maps_lut{$_->{map}.'.rsw'} || T('Unknown Area'),
						@$_{qw(map x y)},
						$_->{cost} ? TF(': %d zeny', $_->{cost}) : T('')
					),
					command => sprintf "talknpc %d %d %s", @{$portal->{source}}{qw(x y)}, $_->{steps}
				}
			}
		}
	}
	if (@portals) {
		push @{$self->{head}}, {}, @portals;
	}
	
	push @{$self->{tail}}, reverse @tail;
	return $self;
}

1;
