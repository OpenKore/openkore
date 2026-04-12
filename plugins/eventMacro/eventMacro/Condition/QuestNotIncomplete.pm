package eventMacro::Condition::QuestNotIncomplete;

use strict;
use eventMacro::Utilities qw( getQuestStatus );
use base 'eventMacro::Condition::Base::Quest';

sub check_quests {
        my ( $self, $list ) = @_;
        $self->{fulfilled_ID} = undef;
        $self->{fulfilled_member_index} = undef;
        foreach my $member_index ( 0..$#{ $self->{members_array} } ) {
                my $quest_ID = $self->{members_array}->[$member_index];
                next unless (defined $quest_ID);
                my $status = getQuestStatus($quest_ID)->{$quest_ID};
                next if ($status && $status eq 'incomplete');
                $self->{fulfilled_ID} = $quest_ID;
                $self->{fulfilled_member_index} = $member_index;
                last;
        }
}

1;
