package eventMacro::Condition::NpcNameUpdate;

use strict;
use Globals;
use Utils;

use eventMacro::Data;

use base 'eventMacro::Conditiontypes::RegexConditionEvent';

sub _hooks {
	['npcNameUpdate'];
}

sub validate_condition {
	my ( $self, $callback_type, $callback_name, $args ) = @_;
	
	if ($callback_type eq 'hook') {
		$self->{npc} = $args->{npc};
		return $self->SUPER::validate_condition( $self->validator_check( $self->{npc}->{name} ) );
		
	} elsif ($callback_type eq 'variable') {
		$self->update_validator_var($callback_name, $args);
	}
}

sub get_new_variable_list {
	my ($self) = @_;
	my $new_variables;
	
	my $actor = $monsters{$self->{id}};
	
	$new_variables->{".".$self->{name}."Last"."Name"} = $self->{npc}->{name};
	$new_variables->{".".$self->{name}."Last"."Pos"} = sprintf("%d %d %s", $self->{npc}->{pos_to}{x}, $self->{npc}->{pos_to}{y}, $field->baseName);
	$new_variables->{".".$self->{name}."Last"."BinId"} = $self->{npc}->{binID};
	$new_variables->{".".$self->{name}."Last"."Dist"} = distance($char->{pos_to}, $self->{npc}->{pos_to});
	$new_variables->{".".$self->{name}."Last"."Type"} = $self->{npc}->{type};
	
	return $new_variables;
}

sub usable {
	1;
}

1;