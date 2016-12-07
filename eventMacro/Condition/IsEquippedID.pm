package eventMacro::Condition::IsEquippedID;

use strict;
use Globals;
use Utils;

use base 'eventMacro::Condition';

my $variable_qr = qr/\.?[a-zA-Z][a-zA-Z\d]*/;

sub _hooks {
	['packet_mapChange','equipped_item','unequipped_item'];
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
	
	my $var_exists_hash = {};
	
	my $member_index = 0;
	foreach my $member (split(/\s*,\s*/, $condition_code)) {
		my ($slot_name, $item_id) = split(/\s+/, $member);
		
		unless (defined $slot_name && defined $item_id) {
			$self->{error} = "List member '".$member."' must have a slot and an ID defined";
			return 0;
		}
		
		unless (exists $equipSlot_rlut{$slot_name}) {
			$self->{error} = "List member '".$member."' has a equipment slot value '".$slot_name."' not valid";
			return 0;
		}
		
		unless ($item_id =~ /^\d+$/) {
			$self->{error} = "List member '".$member."' has a equipment ID value '".$item_id."' not valid";
			return 0;
		}

		my $slot_is_var = 0;
		if ($slot_name =~ /(?:^|(?<=[^\\]))\$($variable_qr)$/) {
			my $var = $1;
			if ($var =~ /^\./) {
				$self->{error} = "System variables should not be used in automacros (The ones starting with a dot '.')";
				return 0;
			} else {
				$slot_is_var = 1;
				push ( @{ $self->{var_to_member_index_slot_name}{$var} }, $member_index );
				$var_exists_hash->{$var} = undef;
			}
		}
		
		my $id_is_var = 0;
		if ($item_id =~ /(?:^|(?<=[^\\]))\$($variable_qr)$/) {
			my $var = $1;
			if ($var =~ /^\./) {
				$self->{error} = "System variables should not be used in automacros (The ones starting with a dot '.')";
				return 0;
			} else {
				$id_is_var = 1;
				push ( @{ $self->{var_to_member_index_item_id}{$var} }, $member_index );
				$var_exists_hash->{$var} = undef;
			}
		}
		
		if ($slot_name eq 'arrow') {
			push (@{$self->{hooks}}, 'packet/inventory_items_stackable');
		} else {
			push (@{$self->{hooks}}, 'packet/inventory_items_nonstackable');
		}
		
		$self->{slot_name_to_member_to_check_array}{$slot_name}{$member_index} = undef;
		push (@{$self->{members_array}}, {slot_name => ($slot_is_var ? undef : $slot_name) , item_id => ($id_is_var ? undef : $item_id)});
		
	} continue {
		$member_index++;
	}
	
	foreach my $var (keys %{$var_exists_hash}) {
		push ( @{ $self->{variables} }, $var );
	}
	
	return 1;
}

sub update_vars {
	my ( $self, $var_name, $var_value ) = @_;
	
	my %members_index_changed;
	
	foreach my $member_index (@{$self->{var_to_member_index_slot_name}{$var_name}}) {
		if (defined $self->{members_array}[$member_index]{slot_name} && exists $self->{slot_name_to_member_to_check_array}{$self->{members_array}[$member_index]{slot_name}}{$member_index}) {
			delete $self->{slot_name_to_member_to_check_array}{$self->{members_array}[$member_index]{slot_name}}{$member_index};
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
			}
		} else {
			unless (exists $self->{slot_name_to_member_to_check_array}{$member->{slot_name}}{$changed_index}) {
				$self->{slot_name_to_member_to_check_array}{$member->{slot_name}}{$changed_index} = undef;
			}
			$recheck_index->{$member->{slot_name}}{$changed_index} = undef;
		}
	}
	
	if (!$self->{is_Fulfilled} || $changed_fulfilled_index) {
		$self->recheck_after_var_update($recheck_index);
	}
}

sub check_all_equips {
	my ( $self, $list ) = @_;
	$self->{fulfilled_slot} = undef;
	$self->{fulfilled_item} = undef;
	$self->{fulfilled_member_index} = undef;
	$self->{is_Fulfilled} = 0;
	foreach my $slot (keys %{$char->{equipment}}) {
		next unless (exists $list->{$slot});
		my @members = keys %{$list->{$slot}};
		my $equipment = $char->{equipment}{$slot};
		my $equipment_id = $equipment->{nameID};
		foreach my $member_index (@members) {
			my $member = $self->{members_array}->[$member_index];
			next unless ($equipment_id == $member->{item_id});
			$self->{fulfilled_slot} = $member->{slot_name};
			$self->{fulfilled_item} = $equipment;
			$self->{fulfilled_member_index} = $member_index;
			$self->{is_Fulfilled} = 1;
			last;
		}
	}
}

sub validate_condition {
	my ( $self, $callback_type, $callback_name, $args ) = @_;
	
	if ($callback_type eq 'hook') {
		if ($callback_name eq 'equipped_item') {
			return if ($self->{is_Fulfilled});
			return unless (exists $self->{slot_name_to_member_to_check_array}{$args->{slot}});
			
			my @members = keys %{$self->{slot_name_to_member_to_check_array}{$args->{slot}}};
			
			foreach my $member_index (@members) {
				my $member = $self->{members_array}->[$member_index];
				next unless ($args->{item}->{nameID} == $member->{item_id});
				$self->{fulfilled_slot} = $member->{slot_name};
				$self->{fulfilled_item} = $args->{item};
				$self->{fulfilled_member_index} = $member_index;
				$self->{is_Fulfilled} = 1;
				last;
			}

		} elsif ($callback_name eq 'unequipped_item') {
			return unless ($self->{is_Fulfilled});
			return unless ($self->{fulfilled_slot} eq $args->{slot});
			$self->check_all_equips($self->{slot_name_to_member_to_check_array});
			
		} elsif ($callback_name eq 'packet_mapChange') {
			$self->{fulfilled_slot} = undef;
			$self->{fulfilled_item} = undef;
			$self->{is_Fulfilled} = 0;
			
		} else {
			$self->check_all_equips($self->{slot_name_to_member_to_check_array});
			
		}
	
	} elsif ($callback_type eq 'variable') {
		$self->update_vars($callback_name, $args);
	}
}

#To be implemented
sub get_new_variable_list {
	my ($self) = @_;
	my $new_variables;
	
	$new_variables->{".".$self->{name}."Last"} = $self->{lastMap};
	
	return $new_variables;
}

1;
