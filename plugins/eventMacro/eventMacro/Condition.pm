package eventMacro::Condition;

use strict;
use eventMacro::Data qw( $eventMacro EVENT_TYPE STATE_TYPE );
use Log qw(message error warning debug);

# Import the validators so our child classes do not have to.
use eventMacro::Validator::NumericComparison;
use eventMacro::Validator::ListMemberCheck;
use eventMacro::Validator::RegexCheck;

sub new {
	my ($class, $condition_code, $automacro_index) = @_;
	my $self = bless {}, $class;
	
	$self->{name} = ($class =~ /([^:]+)$/)[0];
	$self->{variables} = [];
	$self->{error}  = undef;
	$self->{automacro_index} = $automacro_index;
	
	#False by default
	$self->{is_Fulfilled} = 0;

	$self->{hooks} = [ @{ $self->_hooks } ];
	
	$self->{dynamic_hooks} = [ @{ $self->_dynamic_hooks } ];

	$self->_parse_syntax( $condition_code );

	return $self;
}

sub get_hooks {
	my ($self) = @_;
	return $self->{hooks};
}

sub get_index {
	my ($self) = @_;
	return $self->{listIndex};
}

# For '$add_or_remove' value '0' is for delete and '1' is for add.
sub add_or_remove_dynamic_hooks {
	my ($self, $add_or_remove) = @_;
	foreach my $hook ( @{$self->{dynamic_hooks}} ) {
		$eventMacro->manage_dynamic_hook_add_and_delete($hook, $self->{automacro_index}, $self->{listIndex}, $add_or_remove);
	}
}

sub get_variables {
	my ($self) = @_;
	return $self->{variables};
}

sub get_name {
	my ($self) = @_;
	return $self->{name};
}

sub validate_condition {
	my ( $self, $result ) = @_;
	return (defined $result ? $result : 0) if ($self->condition_type == EVENT_TYPE);
	if (defined $result) {
		$self->is_fulfilled($result);
	}
	return $self->is_fulfilled;
}

sub is_fulfilled {
	my ($self, $new_value) = @_;
	if (defined $new_value) {
		if ($new_value == 0 || $new_value == 1) {
			$self->{is_Fulfilled} = $new_value;
		} else {
			error "[eventMacro] For some reason something tried to change the fulfilled state of condition '".$self->{name}."' in automacro '".$self->{Automacro_List}->get($self->{automacro_index})->get_name."' to a value that's neither 0 or 1 ('".$new_value."')\n";
		}
	}
	return $self->{is_Fulfilled};
}

sub error {
	my ( $self ) = @_;
	$self->{error};
}

# Default: No variables.
sub get_new_variable_list {
	{};
}

# Default: No hooks.
sub _hooks {
	[];
}

# Default: No hooks.
sub _dynamic_hooks {
	[];
}

# Default: No syntax parsing, always succeed.
sub _parse_syntax {
	1;
}

# Default: State type
sub condition_type {
	STATE_TYPE;
}

# Default: false
sub is_unique_condition {
	0;
}

1;
