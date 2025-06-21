package eventMacro::Condition::ConfigKeyUndefined;

use strict;

use base 'eventMacro::Condition';

use Globals qw( %config );
use eventMacro::Utilities qw( find_variable );

sub _hooks {
	['post_configModify','pos_load_config.txt','in_game'];
}

sub _parse_syntax {
	my ( $self, $condition_code ) = @_;
	
	$self->{fulfilled_key} = undef;
	$self->{fulfilled_member_index} = undef;
	
	$self->{var_to_member_index} = {};
	$self->{members_array} = [];
	
	my $var_exists_hash = {};
	
	my $member_counter = 0;
	my @members = split(/\s*,\s*/, $condition_code);
	foreach my $member_index (0..$#members) {
		my $member = $members[$member_index];
		
		if (my $var = find_variable($member)) {
			if ($var->{display_name} =~ /^\./) {
				$self->{error} = "System variables should not be used in automacros (The ones starting with a dot '.')";
				return 0;
			} else {
				push ( @{ $self->{var_to_member_index}{$var->{display_name}} }, $member_index );
				$self->{members_array}->[$member_index] = undef;
				push(@{$self->{variables}}, $var) unless (exists $var_exists_hash->{$var->{display_name}});
				$var_exists_hash->{$var->{display_name}} = undef;
			}
		} else {
			$self->{members_array}->[$member_index] = $member;
		}
	}
	
	return 1;
}

sub update_vars {
	my ( $self, $var_name, $var_value ) = @_;
	foreach my $member_index ( @{ $self->{var_to_member_index}{$var_name} } ) {
		$self->{members_array}->[$member_index] = $var_value;
	}
}

sub validate_condition {
	my ( $self, $callback_type, $callback_name, $args ) = @_;
	
	if ($callback_type eq 'variable') {
		$self->update_vars($callback_name, $args);
	}
	
	$self->check_keys;
	
	return $self->SUPER::validate_condition( (defined $self->{fulfilled_key} ? 1 : 0) );
}

sub check_keys {
	my ( $self ) = @_;
	$self->{fulfilled_key} = undef;
	$self->{fulfilled_member_index} = undef;
	foreach my $member_index ( 0..$#{ $self->{members_array} } ) {
		my $key = $self->{members_array}->[$member_index];
		next unless (defined $key);
		$key = get_real_key($key) if ($key =~ /\./); #if have a dot, probably is a label
		next if (!exists $config{$key});
		next if (defined $config{$key});
		$self->{fulfilled_key} = $key;
		$self->{fulfilled_member_index} = $member_index;
		last;
	}
}

sub get_real_key {
	# Basic Support for "label" in blocks. Thanks to "piroJOKE" (from Commands.pm, sub cmdConf)
	$_[0] =~ s/\.+/\./; # Filter Out unnecessary dot's
	my ($label, $param) = split /\./, $_[0], 2; # Split the label from parameter
	foreach (keys %config) {
		if ($_ =~ /_\d+_label/){ # we only need those blocks which have labels
			if ($config{$_} eq $label) {
				my ($real_key, undef) = split /_label/, $_, 2;
				# "<label>.block" param support. Thanks to "vit"
				if ($param ne "block") {
					$real_key .= "_";
					$real_key .= $param;
				}
				return $real_key;
			}
		}
	}
	#if not found any label, return UNchanged key
	return $_[0];
}

sub get_new_variable_list {
	my ($self) = @_;
	my $new_variables;
			
	$new_variables->{".".$self->{name}."LastKey"} = $self->{fulfilled_key};
	$new_variables->{".".$self->{name}."LastMemberIndex"} = $self->{fulfilled_member_index};
	
	return $new_variables;
}

1;
