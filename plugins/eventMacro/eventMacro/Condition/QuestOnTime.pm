package eventMacro::Condition::QuestOnTime;

use strict;
use Globals qw( $questList );
use base 'eventMacro::Condition::Base::Quest';

sub check_quests {
	my ( $self, $list ) = @_;
	$self->{fulfilled_ID} = undef;
	$self->{fulfilled_member_index} = undef;
	foreach my $member_index ( 0..$#{ $self->{members_array} } ) {
		my $quest_ID = $self->{members_array}->[$member_index];
		next unless (defined $quest_ID);
		next unless (exists $questList->{$quest_ID});
		next unless (exists $questList->{$quest_ID}->{active});
		next unless ($questList->{$quest_ID}->{active});
		next unless (exists $questList->{$quest_ID}->{time_expire});
		next unless ($questList->{$quest_ID}->{time_expire} > 0);
		next unless ($questList->{$quest_ID}->{time_expire} > time);
		
		$self->{fulfilled_ID} = $quest_ID;
		$self->{fulfilled_member_index} = $member_index;
		last;
	}
}

1;
