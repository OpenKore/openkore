package eventMacro::Condition::QuestAllListInactive;

use strict;
use Globals qw( $questList );
use base 'eventMacro::Condition::Base::Quest';

sub _hooks {
	my ($self) = @_;
	my $hooks = $self->SUPER::_hooks;
	push(@{$hooks}, 'achievement_list');
	return $hooks;
}

sub check_quests {
	my ( $self, $list ) = @_;
	$self->{fulfilled_ID} = undef;
	$self->{fulfilled_member_index} = undef;

	foreach my $member_index ( 0..$#{ $self->{members_array} } ) {
		my $quest_ID = $self->{members_array}->[$member_index];
		next unless (defined $quest_ID);
		if (exists $questList->{$quest_ID}
			&& exists $questList->{$quest_ID}->{active}
			&& $questList->{$quest_ID}->{active}) {
			return;
		}
	}

	# Fulfill only when every listed quest is inactive. Mirror list-style
	# variables so automacros can inspect the first configured quest ID.
	$self->{fulfilled_ID} = $self->{members_array}[0];
	$self->{fulfilled_member_index} = 0 if (@{$self->{members_array}});
}

1;
