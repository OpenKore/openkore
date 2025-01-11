package eventMacro::Condition::JobIDNot;

use strict;

use base 'eventMacro::Condition';

use Globals qw( $char );
use eventMacro::Utilities qw( find_variable );

sub _hooks {
	['Network::Receive::map_changed','in_game','sprite_job_change'];
}

sub _parse_syntax {
	my ( $self, $condition_code ) = @_;
	
	$self->{not_wanted_id} = undef;
	
	if (my $var = find_variable($condition_code)) {
		if ($var =~ /^\./) {
			$self->{error} = "System variables should not be used in automacros (The ones starting with a dot '.')";
			return 0;
		} else {
			push ( @{ $self->{variables} }, $var );
		}
	} elsif ($condition_code =~ /^(\d+)$/) {
		$self->{not_wanted_id} = $1;
	} else {
		$self->{error} = "Job ID '".$condition_code."' must be a ID number or a variable";
		return 0;
	}
	
	return 1;
}

sub update_vars {
	my ( $self, $var_name, $var_value ) = @_;
	if ($var_value =~ /^\d+$/) {
		$self->{not_wanted_id} = $var_value;
	} else {
		$self->{not_wanted_id} = undef;
	}
}

sub validate_condition {
	my ( $self, $callback_type, $callback_name, $args ) = @_;
	
	if ($callback_type eq 'variable') {
		$self->update_vars($callback_name, $args);
	}
	
	if (!defined $self->{not_wanted_id}) {
		return $self->SUPER::validate_condition(0);
	} else {
		return $self->SUPER::validate_condition( ($self->{not_wanted_id} != $char->{jobID} ? 1 : 0) );
	}
}

sub get_new_variable_list {
	my ($self) = @_;
	my $new_variables;
	
	$new_variables->{".".$self->{name}."Last"} = $self->{not_wanted_id};
	
	return $new_variables;
}

1;
