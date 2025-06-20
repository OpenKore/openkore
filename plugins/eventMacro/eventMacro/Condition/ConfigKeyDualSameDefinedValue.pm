package eventMacro::Condition::ConfigKeyDualSameDefinedValue;

use strict;

use base 'eventMacro::Condition';

use Globals qw( %config );

sub _hooks {
	['post_configModify','pos_load_config.txt','in_game'];
}

sub _parse_syntax {
	my ( $self, $condition_code ) = @_;
	
	$self->{fulfilled_value} = undef;
	
	my @members = split(/\s+/, $condition_code);
	
	if ( scalar @members != 2 || !defined $members[0] || !defined $members[1] ) {
		$self->{error} = "Value '$condition_code' should be 2 config keys";
		return 0;
	}
	
	$self->{key_1} = $members[0];
	$self->{key_2} = $members[1];
	
	$self->{key_1} = get_real_key($self->{key_1}) if ($self->{key_1} =~ /\./);
	$self->{key_2} = get_real_key($self->{key_2}) if ($self->{key_2} =~ /\./);
	
	return 1;
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

sub validate_condition {
	my ( $self, $callback_type, $callback_name, $args ) = @_;
	
	$self->check_keys;
	
	return $self->SUPER::validate_condition( (defined $self->{fulfilled_value} ? 1 : 0) );
}

sub check_keys {
	my ( $self ) = @_;
	$self->{fulfilled_value} = undef;
	
	return if (!exists $config{$self->{key_1}});
	return if (!exists $config{$self->{key_2}});
	return if (!defined $config{$self->{key_1}});
	return if (!defined $config{$self->{key_2}});
	
	return if ($config{$self->{key_1}} ne $config{$self->{key_2}});
	
	$self->{fulfilled_value} = $config{$self->{key_1}};
}

sub get_new_variable_list {
	my ($self) = @_;
	my $new_variables;
	
	$new_variables->{".".$self->{name}."LastKey1"} = $self->{key_1};
	$new_variables->{".".$self->{name}."LastKey2"} = $self->{key_2};
	$new_variables->{".".$self->{name}."LastValue"} = $self->{fulfilled_value};
	
	return $new_variables;
}

1;
