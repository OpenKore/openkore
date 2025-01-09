package eventMacro::Condition::IsEquippedID;

use strict;

use Globals qw( %equipSlot_rlut $char %equipSlot_lut );

use base 'eventMacro::Condition';

use eventMacro::Utilities qw( find_variable );

sub _hooks {
	['inventory_clear','equipped_item','unequipped_item','inventory_ready'];
}

#slot_index to index_name: %equipSlot_lut
#index_name to slot_index: %equipSlot_rlut

sub _parse_syntax {
	my ( $self, $condition_code ) = @_;
	
	$self->{fulfilled_slot} = undef;
	$self->{fulfilled_item} = undef;
	$self->{fulfilled_member_index} = undef;
	
	$self->{slot_name_to_member_to_check_array} = {};
	$self->{var_to_member_index_item_id} = {};
	$self->{var_to_member_index_slot_name} = {};
	$self->{members_array} = [];
	$self->{is_on_stand_by} = 1;
	
	my $var_exists_hash = {};
	
	my $member_index = 0;
	foreach my $member (split(/\s*,\s*/, $condition_code)) {
		my ($slot_name, $item_id) = split(/\s+/, $member);
		
		unless (defined $slot_name && defined $item_id) {
			$self->{error} = "List member '".$member."' must have a slot and an ID defined";
			return 0;
		}

		my $slot_is_var = 0;
		if (my $var = find_variable($slot_name)) {
			if ($var =~ /^\./) {
				$self->{error} = "System variables should not be used in automacros (The ones starting with a dot '.')";
				return 0;
			} else {
				$slot_is_var = 1;
				push ( @{ $self->{var_to_member_index_slot_name}{$var->{display_name}} }, $member_index );
				push ( @{ $self->{variables} }, $var ) unless (exists $var_exists_hash->{$var->{display_name}});
				$var_exists_hash->{$var->{display_name}} = undef;
			}
		}
		
		if (!$slot_is_var && !exists $equipSlot_rlut{$slot_name}) {
			$self->{error} = "List member '".$member."' has a equipment slot value '".$slot_name."' not valid";
			return 0;
		}
		
		my $id_is_var = 0;
		if (my $var = find_variable($item_id)) {
			if ($var =~ /^\./) {
				$self->{error} = "System variables should not be used in automacros (The ones starting with a dot '.')";
				return 0;
			} else {
				$id_is_var = 1;
				push ( @{ $self->{var_to_member_index_item_id}{$var->{display_name}} }, $member_index );
				push ( @{ $self->{variables} }, $var ) unless (exists $var_exists_hash->{$var->{display_name}});
				$var_exists_hash->{$var->{display_name}} = undef;
			}
		}
		
		if (!$id_is_var && $item_id !~ /^\d+$/) {
			$self->{error} = "List member '".$member."' has a equipment ID value '".$item_id."' not valid";
			return 0;
		}
		
		if (!$id_is_var && !$slot_is_var) {
			$self->{slot_name_to_member_to_check_array}{$slot_name}{$member_index} = undef;
		}
		
		push (@{$self->{members_array}}, {slot_name => ($slot_is_var ? undef : $slot_name) , item_id => ($id_is_var ? undef : $item_id)});
		
	} continue {
		$member_index++;
	}
	
	return 1;
}

sub update_vars {
	my ( $self, $var_name, $var_value ) = @_;
	
	my %members_index_changed;
	
	foreach my $member_index (@{$self->{var_to_member_index_slot_name}{$var_name}}) {
		if (defined $self->{members_array}[$member_index]{slot_name} && exists $self->{slot_name_to_member_to_check_array}{$self->{members_array}[$member_index]{slot_name}}{$member_index}) {
			delete $self->{slot_name_to_member_to_check_array}{$self->{members_array}[$member_index]{slot_name}}{$member_index};
			unless (scalar keys %{ $self->{slot_name_to_member_to_check_array}{$self->{members_array}[$member_index]{slot_name}} }) {
				delete $self->{slot_name_to_member_to_check_array}{$self->{members_array}[$member_index]{slot_name}};
			}
		}
		unless (exists $equipSlot_rlut{$var_value}) {
			$self->{members_array}[$member_index]{slot_name} = undef;
		} else {
			$self->{members_array}[$member_index]{slot_name} = $var_value;
			$self->{slot_name_to_member_to_check_array}{$var_value}{$member_index};
		}
		$members_index_changed{$member_index} = undef;
	}
	
	foreach my $member_index (@{$self->{var_to_member_index_item_id}{$var_name}}) {
		unless ($var_value =~ /^\d+$/) {
			$self->{members_array}[$member_index]{item_id} = undef;
		} else {
			$self->{members_array}[$member_index]{item_id} = $var_value;
		}
		$members_index_changed{$member_index} = undef;
	}
	
	my $recheck_index;
	my $changed_fulfilled_index = 0;
	
	foreach my $changed_index (keys %members_index_changed) {
		if ($changed_index == $self->{fulfilled_member_index}) {
			$changed_fulfilled_index = 1;
		}
		my $member = $self->{members_array}->[$changed_index];
		
		if (!defined $member->{item_id} || !defined $member->{slot_name}) {
			if (defined $member->{slot_name} && exists $self->{slot_name_to_member_to_check_array}{$member->{slot_name}}{$changed_index}) {
				delete $self->{slot_name_to_member_to_check_array}{$member->{slot_name}}{$changed_index};
				unless (scalar keys %{$self->{slot_name_to_member_to_check_array}{$member->{slot_name}}}) {
					delete $self->{slot_name_to_member_to_check_array}{$member->{slot_name}};
				}
			}
		} else {
			unless (exists $self->{slot_name_to_member_to_check_array}{$member->{slot_name}}{$changed_index}) {
				$self->{slot_name_to_member_to_check_array}{$member->{slot_name}}{$changed_index} = undef;
			}
			$recheck_index->{$member->{slot_name}}{$changed_index} = undef;
		}
	}
	
	#if (!defined $self->{fulfilled_slot} || $changed_fulfilled_index) {
		$self->check_all_equips($recheck_index);
	#}
}

sub check_all_equips {
	my ( $self, $list ) = @_;
	$self->{fulfilled_slot} = undef;
	$self->{fulfilled_item} = undef;
	$self->{fulfilled_member_index} = undef;
	foreach my $slot (keys %{$char->{equipment}}) {
		next unless (exists $list->{$slot});
		my $equipment = $char->{equipment}{$slot};
		$self->check_slot($slot, $equipment);
		last if (defined $self->{fulfilled_slot});
	}
}

sub check_slot {
	my ( $self, $slot, $item ) = @_;
	my @members = keys %{$self->{slot_name_to_member_to_check_array}{$slot}};
	foreach my $member_index (@members) {
		my $member = $self->{members_array}->[$member_index];
		next unless ($item->{nameID} == $member->{item_id});
		$self->{fulfilled_slot} = $member->{slot_name};
		$self->{fulfilled_item} = $item;
		$self->{fulfilled_member_index} = $member_index;
		last;
	}
}

sub validate_condition {
	my ( $self, $callback_type, $callback_name, $args ) = @_;
	
	if ($callback_type eq 'hook') {
		if ($callback_name eq 'equipped_item') {
			#return $self->SUPER::validate_condition if (defined $self->{fulfilled_slot} || !exists $self->{slot_name_to_member_to_check_array}{$args->{slot}});
			#$self->check_slot($args->{slot}, $args->{item});
			$self->check_all_equips($self->{slot_name_to_member_to_check_array});

		} elsif ($callback_name eq 'unequipped_item') {
			#return $self->SUPER::validate_condition unless (defined $self->{fulfilled_slot} || $self->{fulfilled_slot} ne $args->{slot});
			$self->check_all_equips($self->{slot_name_to_member_to_check_array});
			
		} elsif ($callback_name eq 'inventory_clear') {
			$self->{fulfilled_slot} = undef;
			$self->{fulfilled_item} = undef;
			$self->{fulfilled_member_index} = undef;
			$self->{is_on_stand_by} = 1;
			
		} elsif ($callback_name eq 'inventory_ready') {
			$self->{is_on_stand_by} = 0;
			$self->check_all_equips($self->{slot_name_to_member_to_check_array});
		}
	
	} elsif ($callback_type eq 'variable') {
		$self->update_vars($callback_name, $args);
		
	} elsif ($callback_type eq 'recheck') {
		$self->{is_on_stand_by} = 0;
		$self->check_all_equips($self->{slot_name_to_member_to_check_array});
	}
	
	return $self->SUPER::validate_condition( (defined $self->{fulfilled_slot} ? 1 : 0) );
}

sub get_new_variable_list {
	my ($self) = @_;
	my $new_variables;
	
	$new_variables->{".".$self->{name}."LastID"} = $self->{fulfilled_item}->{nameID};
	$new_variables->{".".$self->{name}."LastName"} = $self->{fulfilled_item}->{name};
	$new_variables->{".".$self->{name}."LastSlot"} = $self->{fulfilled_slot};
	$new_variables->{".".$self->{name}."LastListIndex"} = $self->{fulfilled_member_index};
	
	return $new_variables;
}

1;
