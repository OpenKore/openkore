package eventMacro::Condition::ChatRoomNear;

use strict;
use Globals qw( $accountID %chatRooms @chatRoomsID);


use base 'eventMacro::Conditiontypes::RegexConditionState';

sub _hooks {
	['packet_mapChange','chat_created','packet_chatinfo','chat_removed','chat_modified'];
}

sub _parse_syntax {
	my ( $self, $condition_code ) = @_;
	
	$self->{fulfilled_chatID} = undef;
	
	$self->SUPER::_parse_syntax($condition_code);
}

sub validate_condition {
	my ( $self, $callback_type, $callback_name, $args ) = @_;
	
	if ($callback_type eq 'variable') {
		$self->update_validator_var($callback_name, $args);
		$self->recheck_all_chat_names;
		
	} elsif ($callback_type eq 'hook') {
		
		if ($callback_name eq 'packet_chatinfo') {
		
			if (!defined $self->{fulfilled_chatID} && $self->validator_check($args->{title})) {
				$self->{fulfilled_chatID} = $args->{chatID};
				
			} elsif (defined $self->{fulfilled_chatID} && $args->{chatID} eq $self->{fulfilled_chatID}) {
				unless ($self->validator_check($args->{title})) {
					my $last_id = $self->{fulfilled_chatID};
					$self->recheck_all_chat_names($last_id);
				}
			}
			
		} elsif ($callback_name eq 'chat_created' && !defined $self->{fulfilled_chatID} && $self->validator_check($args->{chat}{title})) {
			$self->{fulfilled_chatID} = $accountID;

		} elsif ($callback_name eq 'chat_removed' && defined $self->{fulfilled_chatID} && $args->{ID} eq $self->{fulfilled_chatID}) {
			my $last_id = $self->{fulfilled_chatID};
			$self->recheck_all_chat_names($last_id);
		
		} elsif ($callback_name eq 'chat_modified') {
		
			if (!defined $self->{fulfilled_chatID} && $self->validator_check($args->{new}{title})) {
				$self->{fulfilled_chatID} = $args->{ID};
				
			} elsif (defined $self->{fulfilled_chatID} && $args->{ID} eq $self->{fulfilled_chatID}) {
				unless ($self->validator_check($args->{new}{title})) {
					my $last_id = $self->{fulfilled_chatID};
					$self->recheck_all_chat_names($last_id);
				}
			}
			
		} elsif ($callback_name eq 'packet_mapChange') {
			$self->{fulfilled_chatID} = undef;
		}
		
	} elsif ($callback_type eq 'recheck') {
		$self->recheck_all_chat_names;
	}
	
	return $self->SUPER::validate_condition( (defined $self->{fulfilled_chatID} ? 1 : 0) );
}

sub recheck_all_chat_names {
	my ($self, $skip_id) = @_;
	$self->{fulfilled_chatID} = undef;
	foreach my $ID (keys %chatRooms) {
		next if (defined $skip_id && $skip_id eq $ID);
		next unless ($self->validator_check($chatRooms{$ID}{title}));
		$self->{fulfilled_chatID} = $ID;
		last;
	}
}

sub get_new_variable_list {
	my ($self) = @_;
	my $new_variables;
	
	$new_variables->{".".$self->{name}."Last"."ID"} = $self->{fulfilled_chatID};
	$new_variables->{".".$self->{name}."Last"."OwnerID"} = $chatRooms{$self->{fulfilled_chatID}}{ownerID};
	$new_variables->{".".$self->{name}."Last"."OwnerName"} = Actor::get($chatRooms{$self->{fulfilled_chatID}}{ownerID})->name;
	$new_variables->{".".$self->{name}."Last"."Title"} = $chatRooms{$self->{fulfilled_chatID}}{title};
	
	foreach my $index (0..$#chatRoomsID) {
		next if (!defined $chatRoomsID[$index]);
		next unless ($chatRoomsID[$index] eq $self->{fulfilled_chatID});
		$new_variables->{".".$self->{name}."Last"."BinID"} = $index;
		last;
	}
	
	return $new_variables;
}

1;
