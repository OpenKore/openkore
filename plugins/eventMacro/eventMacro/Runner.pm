package eventMacro::Runner;

use strict;

require Exporter;
our @ISA = qw(Exporter);

use Time::HiRes qw( &time );
use Globals;
use AI;
use Log qw(message error warning debug);
use Text::Balanced qw/extract_bracketed/;
use Utils qw/existsInList parseArgs/;
use List::Util qw(max min sum);

use eventMacro::Data;
use eventMacro::Core;
use eventMacro::FileParser qw(isNewCommandBlock);
use eventMacro::Utilities qw(cmpr getnpcID getItemIDs getItemPrice getStorageIDs getInventoryIDs getInventoryTypeIDs
	getPlayerID getMonsterID getVenderID getRandom getRandomRange getInventoryAmount getCartAmount getShopAmount
	getStorageAmount getVendAmount getConfig getWord q4rx q4rx2 getArgFromList get_pattern find_variable get_key_or_index getQuestStatus
	find_hash_and_get_keys find_hash_and_get_values);
use eventMacro::Automacro;

# Creates the object
sub new {
	my ($class, $name, $caller_name, $repeat, $interruptible, $self_interruptible, $overrideAI, $orphan, $delay, $macro_delay, $is_submacro) = @_;

	return undef unless ($eventMacro->{Macro_List}->getByName($name));

	my $self = bless {}, $class;

	$self->{name} = $name;
	$self->{caller_name} = $caller_name;
	$self->{Paused} = 0;
	$self->{registered} = 0;
	$self->{finished} = 0;
	$self->{macro_block} = 0;

	$self->{lines_array} = $eventMacro->{Macro_List}->getByName($name)->get_lines();
	$self->{line_index} = 0;

	$self->{label} = {scanLabels($self->{lines_array})};
	$self->{block} = scanBlocks($self->{lines_array});

	$self->{time} = time;

	$self->{current_line} = undef;
	$self->{subcall} = undef;
	$self->{error} = undef;
	$self->{last_subcall_overrideAI} = undef;
	$self->{last_subcall_interruptible} = undef;
	$self->{last_subcall_orphan} = undef;

	debug "[eventMacro] Macro object '".$self->{name}."' created.\n", "eventMacro", 2;

	if ($is_submacro) {
		$self->{submacro} = 1;
		$eventMacro->{Macro_Runner}->last_subcall_name($self->get_name);
	} else {
		$self->{submacro} = 0;
		$self->last_subcall_name($self->get_name);
	}

	if (defined $repeat && $repeat =~ /^\d+$/) {
		$self->repeat($repeat);
	} else {
		$self->repeat(1);
	}

	if (defined $interruptible && $interruptible =~ /^[01]$/) {
		$self->interruptible($interruptible);
	} else {
		$self->interruptible(1);
	}

	if (defined $self_interruptible && $self_interruptible =~ /^[01]$/) {
		$self->self_interruptible($self_interruptible);
	} else {
		$self->self_interruptible(0);
	}

	if (defined $overrideAI && $overrideAI =~ /^[01]$/) {
		$self->overrideAI($overrideAI);
	} else {
		$self->overrideAI(0);
	}

	if (defined $orphan && $orphan =~ /^(?:terminate(?:_last_call)?|reregister(?:_safe)?)$/) {
		$self->orphan($orphan);
	} else {
		$self->orphan($config{eventMacro_orphans});
	}

	if (defined $delay && $delay =~ /^[\d\.]*\d+$/) {
		$self->timeout($delay);
	} else {
		$self->timeout(0);
	}

	if (defined $macro_delay && $macro_delay =~ /^[\d\.]*\d+$/) {
		$self->macro_delay($macro_delay);
	} else {
		$self->macro_delay($timeout{eventMacro_delay}{timeout});
	}

	return $self
}

# Sets/Gets the overrideAI value of the last subcall
sub last_subcall_overrideAI {
	my ($self, $overrideAI) = @_;
	if (defined $overrideAI) {
		$self->{last_subcall_overrideAI} = $overrideAI;
	}
	return $self->{last_subcall_overrideAI};
}

# Sets/Gets the interruptible value of the last subcall
sub last_subcall_interruptible {
	my ($self, $interruptible) = @_;
	if (defined $interruptible) {
		$self->{last_subcall_interruptible} = $interruptible;
	}
	return $self->{last_subcall_interruptible};
}

# Sets/Gets the orphan method of the last subcall
sub last_subcall_orphan {
	my ($self, $orphan) = @_;
	if (defined $orphan) {
		$self->{last_subcall_orphan} = $orphan;
		}
	return $self->{last_subcall_orphan};
}

# Sets/Gets the name of the last subcall
sub last_subcall_name {
	my ($self, $name) = @_;
	if (defined $name) {
		$self->{last_subcall_name} = $name;
	}
	return $self->{last_subcall_name};
}

# Sets/Gets the current interruptible flag
sub interruptible {
	my ($self, $interruptible) = @_;

	if (defined $interruptible) {

		if (defined $self->{interruptible} && $self->{interruptible} == $interruptible) {
			debug "[eventMacro] Macro '".$self->{name}."' interruptible state is already '".$interruptible."'.\n", "eventMacro", 2;
		} else {
			debug "[eventMacro] Now macro '".$self->{name}."' interruptible state is '".$interruptible."'.\n", "eventMacro", 2;
			$self->{interruptible} = $interruptible;
		}

		if (!defined $self->{subcall}) {
			debug "[eventMacro] Since this macro is the last in the macro tree we will validate automacro checking to interruptible.\n", "eventMacro", 2;
			$self->validate_automacro_checking_to_interruptible($interruptible);
		}

	}
	return $self->{interruptible};
}

# Sets/Gets the current self_interruptible flag
sub self_interruptible {
	my ($self, $self_interruptible) = @_;

	if (defined $self_interruptible) {

		if (defined $self->{self_interruptible} && $self->{self_interruptible} == $self_interruptible) {
			debug "[eventMacro] Macro '".$self->{name}."' self_interruptible state is already '".$self_interruptible."'.\n", "eventMacro", 2;
		} else {
			debug "[eventMacro] Now macro '".$self->{name}."' self_interruptible state is '".$self_interruptible."'.\n", "eventMacro", 2;
			$self->{self_interruptible} = $self_interruptible;
		}

	}
	return $self->{self_interruptible};
}

# Makes sure the automacro checking state is compatible with this macro interruptible
sub validate_automacro_checking_to_interruptible {
	my ($self, $interruptible) = @_;

	my $checking_status = $eventMacro->get_automacro_checking_status();

	if (!$self->{submacro}) {
		$self->last_subcall_interruptible($interruptible);
	} else {
		$eventMacro->{Macro_Runner}->last_subcall_interruptible($interruptible);
	}

	if (($checking_status == CHECKING_AUTOMACROS && $interruptible == 1) || ($checking_status == PAUSED_BY_EXCLUSIVE_MACRO && $interruptible == 0)) {
		debug "[eventMacro] No need to change automacro checking status because it already is compatible with this macro.\n", "eventMacro", 2;
		return;
	}

	if ($checking_status != CHECKING_AUTOMACROS && $checking_status != PAUSED_BY_EXCLUSIVE_MACRO) {
		debug "[eventMacro] Macro '".$self->{name}."' cannot change automacro checking state because the user forced it into another state.\n", "eventMacro", 2;
		return;
	}

	if ($interruptible == 0) {
		debug "[eventMacro] Macro '".$self->{name}."' is now stopping automacro checking..\n", "eventMacro", 2;
		$eventMacro->set_automacro_checking_status(PAUSED_BY_EXCLUSIVE_MACRO);

	} elsif ($interruptible == 1) {
		debug "[eventMacro] Macro '".$self->{name}."' is now starting automacro checking..\n", "eventMacro", 2;
		$eventMacro->set_automacro_checking_status(CHECKING_AUTOMACROS);
	}
}

# Sets/Gets the current override AI value
sub overrideAI {
	my ($self, $overrideAI) = @_;

	if (defined $overrideAI) {

		if (defined $self->{overrideAI} && $self->{overrideAI} == $overrideAI) {
			debug "[eventMacro] Macro '".$self->{name}."' overrideAI state is already '".$overrideAI."'.\n", "eventMacro", 2;
		} else {
			debug "[eventMacro] Now macro '".$self->{name}."' overrideAI state is '".$overrideAI."'.\n", "eventMacro", 2;
			$self->{overrideAI} = $overrideAI;
		}

		if (!defined $self->{subcall}) {
			debug "[eventMacro] Since this macro is the last in the macro tree we will validate AI queue to overrideAI.\n", "eventMacro", 2;
			$self->validate_AI_queue_to_overrideAI($overrideAI);
		}

	}
	return $self->{overrideAI};
}

# Makes sure the AI queue state is compatible with this macro overrideAI
sub validate_AI_queue_to_overrideAI {
	my ($self, $overrideAI) = @_;

	my $is_in_AI_queue = AI::inQueue('eventMacro');

	if (!$self->{submacro}) {
		$self->last_subcall_overrideAI($overrideAI);
	} else {
		$eventMacro->{Macro_Runner}->last_subcall_overrideAI($overrideAI);
	}

	if (($is_in_AI_queue && $overrideAI == 0) || (!$is_in_AI_queue && $overrideAI == 1)) {
		debug "[eventMacro] No need to add/clear AI_queue because it already is compatible with this macro.\n", "eventMacro", 2;
		return;
	}

	if ($overrideAI == 0) {
		$self->register;

	} elsif ($overrideAI == 1) {
		$self->unregister;
	}
}

# Registers to AI queue
sub register {
	my ($self) = @_;
	debug "[eventMacro] Macro '".$self->{name}."' is now registering itself to AI queue.\n", "eventMacro", 2;
	if (AI::is("NPC")) {
		splice(@AI::ai_seq, 1, 0, 'eventMacro');
		splice(@AI::ai_seq_args, 1, 0, {});
	} else {
		AI::queue('eventMacro');
	}
	$self->{registered} = 1;
}

# Unregisters from AI queue
sub unregister {
	my ($self) = @_;
	debug "[eventMacro] Macro '".$self->{name}."' is now deleting itself from AI queue.\n", "eventMacro", 2;
	AI::clear('eventMacro');
	$self->{registered} = 0;
}

# Sets/Gets the current orphan method
sub orphan {
	my ($self, $orphan) = @_;

	if (defined $orphan) {

		if (defined $self->{orphan} && $self->{orphan} eq $orphan) {
			debug "[eventMacro] Macro '".$self->{name}."' orphan method is already '".$orphan."'.\n", "eventMacro", 2;
		} else {
			debug "[eventMacro] Now macro '".$self->{name}."' orphan method is '".$orphan."'.\n", "eventMacro", 2;
			$self->{orphan} = $orphan;
		}

		if (!defined $self->{subcall}) {
			if (!$self->{submacro}) {
				$self->last_subcall_orphan($orphan);
			} else {
				$eventMacro->{Macro_Runner}->last_subcall_orphan($orphan);
			}
		}
	}
	return $self->{orphan};
}

# Sets/Gets the current timeout
sub timeout {
	my ($self, $timeout) = @_;
	if (defined $timeout) {
		$self->{timeout} = $timeout;
	}
	return { time => $self->{time}, timeout => $self->{timeout} };
}

# Sets/Gets the current macro delay
sub macro_delay {
	my ($self, $macro_delay) = @_;
	if (defined $macro_delay) {
		$self->{macro_delay} = $macro_delay;
	}
	return $self->{macro_delay};
}

# Returns true if the macro is registered to AI queue
sub registered {
	my ($self) = @_;
	return $self->{registered};
}

# Sets/Gets the current repeat count
sub repeat {
	my ($self, $repeat) = @_;
	if (defined $repeat) {
		debug "[eventMacro] Now macro '".$self->{name}."' will repeat itself '".$repeat."' times.\n", "eventMacro", 2;
		$self->{repeat} = $repeat;
	}
	return $self->{repeat};
}

# Pauses the macro
sub pause {
	my ($self) = @_;
	$self->{Paused} = 1;
}

# Unpauses the macro
sub unpause {
	my ($self) = @_;
	$self->{Paused} = 0;
}

# Returns true if the macro is paused
sub is_paused {
	my ($self) = @_;
	return $self->{Paused};
}

# Returns the macro name
sub get_name {
	my ($self) = @_;
	return $self->{name};
}

# Returns the name of the automacro that called this macro
sub get_caller_name {
	my ($self) = @_;
	return $self->{caller_name};
}

# Deletes the subcall object
sub clear_subcall {
	my ($self) = @_;
	debug "[eventMacro] Clearing submacro '".$self->{subcall}->{name}."' from macro '".$self->{name}."'.\n", "eventMacro", 2;
	$self->validate_automacro_checking_to_interruptible($self->interruptible);
	$self->validate_AI_queue_to_overrideAI($self->overrideAI);
	#since we do not need a validate_orphan function we do it here
	if ($self->{subcall}->orphan ne $self->orphan) {
		debug "[eventMacro] Returning orphan method from '".$self->{subcall}->orphan."' to '".$self->orphan."'.\n", "eventMacro", 2;
		if (!$self->{submacro}) {
			$self->last_subcall_orphan($self->orphan);
		} else {
			$eventMacro->{Macro_Runner}->last_subcall_orphan($self->orphan);
		}
	} else {
		debug "[eventMacro] No need to change orphan method because it already is compatible with this macro.\n", "eventMacro", 2;
	}
	if ($self->{submacro}) {
		$eventMacro->{Macro_Runner}->last_subcall_name($self->get_name);
	} else {
		$self->last_subcall_name($self->get_name);
	}
	undef $self->{subcall};
}

# Creates a subcall object
sub create_subcall {
	my ($self, $name, $repeat) = @_;
	debug "[eventMacro] Creating submacro '".$name."' on macro '".$self->{name}."'.\n", "eventMacro", 2;
	$self->{subcall} = new eventMacro::Runner($name, $self->get_caller_name, $repeat, $self->interruptible, $self->self_interruptible, $self->overrideAI, $self->orphan, undef, $self->macro_delay, 1);
}

# destructor
sub DESTROY {
	my ($self) = @_;
	$self->unregister if (AI::inQueue('eventMacro') && !$self->{submacro});
}

# TODO: Check this
# sets or gets macro block flag
sub macro_block {
	my ($self, $macro_block) = @_;
	
	my $value;
	if (defined $macro_block) {
		$self->{macro_block} = $macro_block;
		$value = $self->{macro_block};
		
	} else {
		if (defined $self->{subcall}) {
			$value = $self->{subcall}->macro_block;
		} else {
			$value = $self->{macro_block};
		}
	}

	return $value;
}

# TODO: Check this
# returns whether or not the macro finished
sub finished {
	my ($self) = @_;
	return $self->{finished}
}

# TODO: Check this
# re-sets the timer
sub ok {
	my ($self) = @_;
	$self->{time} = time
}

# TODO: Check this
# Scans the script for labels
sub scanLabels {
	my $script = $_[0];
	my %labels;
	for (my $line = 0; $line < @{$script}; $line++) {
		if (${$script}[$line] =~ /^:/) {
			my ($label) = ${$script}[$line] =~ /^:(.*)/;
			$labels{$label} = $line
		}
	}
	return %labels
}

# Scans the script for blocks
sub scanBlocks {
	my $script = $_[0];
	my $blocks = {};
	my $block_starts = [];

	for (my $line = 0; $line < @{$script}; $line++) {
		if ($script->[$line] =~ /^(if|switch|while|case)\s+\(.*\)\s+{$|^(else)\s+.*{/) {
			push @$block_starts, { type => $1 || $2, start => $line };
		} elsif ($script->[$line] eq '}') {
			my $block = pop @$block_starts;
			$block->{end} = $line;
			$blocks->{end_to_start}{$line} = $block;
			$blocks->{start_to_end}{$block->{start}} = $block;
		}
	}
	$blocks;
}

# Decides what to do when we get to the end of a macro script
sub manage_script_end {
	my ($self) = @_;
	debug "[eventMacro] Macro '".$self->{name}."' got to the end of its script.\n", "eventMacro", 2;
	if ($self->{repeat} > 1) {
		$self->{repeat}--;
		$self->{line_index} = 0;
		debug "[eventMacro] Repeating macro '".$self->{name}."'. Remaining repeats: '".$self->{repeat}."'.\n", "eventMacro", 2;
	} else {
		$self->{finished} = 1;
		debug "[eventMacro] Macro '".$self->{name}."' finished.\n", "eventMacro", 2;
	}
}

# Makes sure the subcall is over before continuing with this macro
sub manage_subcall {
	my ($self) = @_;
	my $subcall_return = $self->{subcall}->next;
	if (defined $subcall_return) {
		my $subcall_timeout = $self->{subcall}->timeout;
		$self->timeout($subcall_timeout->{timeout});
		$self->{time} = $subcall_timeout->{time};
		if ($self->{subcall}->finished) {
			$self->clear_subcall;
		}
		return $subcall_return;
	} else {
		#if subcall->next returned undef an error was set
		$self->error($self->{subcall}->error);
		return;
	}
}

# Sets/Gets the current line index
sub line_index {
	my ($self, $line_index) = @_;
	if (defined $line_index) {
		$self->{line_index} = $line_index;
	}
	return $self->{line_index};
}

# Gets the script of the given line
sub line_script {
	my ($self, $line_index) = @_;
	return @{$self->{lines_array}}[$line_index];
}

# Advances a line
sub next_line {
	my ($self) = @_;
	$self->{line_index}++;
}

# Sets/Gets the error message
sub error {
	my ($self, $error) = @_;
	if (defined $error) {
		$self->{error} = $error;
	}
	return $self->{error};
}

# Returns an informative error message
sub error_message {
	my ($self) = @_;
	my $error_message =
	  "[eventMacro] Error in macro '".$self->{name}."'\n".
	  "[eventMacro] Line index of the error '".$self->line_index."'\n".
	  "[eventMacro] Script of the line '".$self->line_script($self->line_index)."'\n";

	$error_message .= "[eventMacro] Error message '".$self->error."'\n";
	return $error_message;
}

# Decides the next script to be read
sub define_current_line {
	my ($self) = @_;

	#End of script
	if ( $self->{line_index} == scalar (@{$self->{lines_array}}) ) {
		$self->manage_script_end();
		if ($self->{finished}) {
			$self->{current_line} = undef;
			return;
		}
		$self->define_current_line;

	#Normal script
	} else {
		$self->{current_line} = $self->line_script($self->line_index);
	}
}

# This loop is responsible for getting the next macro command script.
# All 'if', 'else', 'goto', 'while', etc, will checked here.
sub define_next_valid_command {
	my ($self) = @_;

	my $check_need = 1;
	DEFINE_COMMAND: while () {

		######################################
		# Get next script line
		######################################
		if ($check_need) {
			$self->define_current_line;
			return "" if ($self->{finished});
			debug "[eventMacro] Checking macro '".$self->{name}."', line index '".$self->line_index."' for a macro command.\n", "eventMacro", 3;
			debug "[eventMacro] Script '".$self->{current_line}."'.\n", "eventMacro", 3;
		} else {
			debug "[eventMacro] Rechecking macro '".$self->{name}."', line index '".$self->line_index."' for a macro command after it was cleaned.\n", "eventMacro", 3;
			debug "[eventMacro] New cleaned script '".$self->{current_line}."'.\n", "eventMacro", 3;
			$check_need = 1;
		}

		######################################
		# While statement: while (foo <= bar) {
		######################################
		if ($self->{current_line} =~ /^while\s*\(/) {
			my ($condition_text) = $self->{current_line} =~ /^while\s*(\(.*\))\s+{$/;

			debug "[eventMacro] Script is the start of a while 'block'.\n", "eventMacro", 3;

			my ($result) = $self->parse_and_check_condition_text($condition_text);
			return if (defined $self->error);

			if ($result == 1) {
				debug "[eventMacro] Condition of 'while' is true.\n", "eventMacro", 3;
				debug "[eventMacro] Entering true 'while' 'block'.\n", "eventMacro", 3;
			} else {
				debug "[eventMacro] Condition of 'while' is false.\n", "eventMacro", 3;
				debug "[eventMacro] Moving to the end of 'while' loop.\n", "eventMacro", 3;
				$self->line_index($self->{block}{start_to_end}{$self->line_index}{end});
			}
			$self->next_line;

		######################################
		# Postfix 'if'
		######################################
		} elsif ($self->{current_line} =~ /.+\s+if\s*\(.*\)$/) {
			my ($condition_text) = $self->{current_line} =~ /.+\s+if\s*(\(.*\))$/;

			debug "[eventMacro] Script is a command with a postfixed 'if'.\n", "eventMacro", 3;

			my ($result) = $self->parse_and_check_condition_text($condition_text);
			return if (defined $self->error);
			if ($result) {
				debug "[eventMacro] Condition of 'if' is true, cleaning 'if' and rechecking line.\n", "eventMacro", 3;
				$self->{current_line} =~ s/\s+if\s*\(.*\)$//;
				$check_need = 0;
				next DEFINE_COMMAND;
			} else {
				debug "[eventMacro] Condition of 'if' is false, ignoring command.\n", "eventMacro", 3;
				$self->next_line;
			}

		######################################
		# Initial 'if'
		######################################
		} elsif ($self->{current_line} =~ /^if\s*\(/) {

			debug "[eventMacro] Script is a 'if' condition.\n", "eventMacro", 3;

			my ($result, $post_if) = $self->parse_and_check_condition_text($self->{current_line});
			return if (defined $self->error);
			if ($result == 1) {
				debug "[eventMacro] Condition of 'if' is true.\n", "eventMacro", 3;
				if ($post_if ne "{") {
					debug "[eventMacro] Code after the 'if' is a command, cleaning 'if' and rechecking line.\n", "eventMacro", 3;
					$self->{current_line} = $post_if;
					$check_need = 0;
					next DEFINE_COMMAND;
				} else {
					debug "[eventMacro] Entering true 'if' block.\n", "eventMacro", 3;
				}

			} else {
				debug "[eventMacro] Condition of 'if' is false.\n", "eventMacro", 3;
				if ($post_if eq "{") {
					debug "[eventMacro] There's a block after it to be cleaned.\n", "eventMacro", 3;

					my $block_count = 1;
					CHECK_IF: while ($block_count > 0) {

						$self->next_line;
						$self->define_current_line;

						if ($self->{finished}) {
							$self->{finished} = 0;
							$self->error("All 'if' blocks must be closed before the end of the macro)");
							return;
						}

						#Start of another if/switch/case/while block
						if ( $self->{current_line} =~ /^(if|switch|case|while|else).*{$/ ) {
							$block_count++;

						#End of an if block or start of else block
						} elsif ($self->{current_line} =~ /^}\s*else\s*{$/ && $block_count == 1) {
							debug "[eventMacro] Entering true 'else' block after false 'if' block.\n", "eventMacro", 3;
							last CHECK_IF;

						#End of an if block or start of else block
						} elsif ($self->{current_line} eq '}') {
							$block_count--;

						#Elsif check
						} elsif ( $self->{current_line} =~ /^}\s*elsif\s*(\(.*\)).*{$/ && $block_count == 1 ) {
							($result) = $self->parse_and_check_condition_text($1);
							return if (defined $self->error);
							debug "[eventMacro] Found an 'elsif' block inside an 'if' block.\n", "eventMacro", 3;
							debug "[eventMacro] Script of 'elsif' block: '".$self->{current_line}."'.\n", "eventMacro", 3;

							if ($result) {
								debug "[eventMacro] Condition of 'elsif' is true, entering 'elsif' block.\n", "eventMacro", 3;
								last CHECK_IF;
							} else {
								debug "[eventMacro] Condition of 'elsif' is false, cleaning 'elsif' block.\n", "eventMacro", 3;
								next;
							}
						}

						debug "[eventMacro] Cleaning line '".$self->{current_line}."' inside 'if' block.\n", "eventMacro", 3;

					}
				} else {
					debug "[eventMacro] Code after 'if' is a command, ignoring it and moving to next line\n", "eventMacro", 3;
				}
			}
			$self->next_line;

		######################################
		# Switch statement
		######################################
		} elsif ($self->{current_line} =~ /^switch.*{$/) {

			# this regex may look wrong, but it's not
			# when the line is "switch ( $name ) {" for example, i want to get only "( $name" whitout the closing parenthesis
			# the reason is because the closing parenthesis will come from $second_part on case block :D
			my ($first_part) = $self->{current_line} =~ /^switch\s*(\(.*)\)\s*{$/;

			debug "[eventMacro] Script is a 'switch' block, searching all 'case' and 'else' blocks.\n", "eventMacro", 3;

			SWITCH: while () {
				$self->next_line;
				$self->define_current_line;

				if ($self->{finished}) {
					$self->{finished} = 0;
					$self->error("All 'switch' blocks must be closed before the end of the macro)");
					return;
				}

				debug "[eventMacro] Script inside 'switch' block is '".$self->{current_line}."'.\n", "eventMacro", 3;

				#Else on switch
				if ($self->{current_line} =~ /^else/) {
					my ($after_else) = $self->{current_line} =~ /^else\s*(.*)/;
					debug "[eventMacro] Found valid 'else' inside 'switch' block.\n", "eventMacro", 3;

					if ($after_else ne "{") {
						debug "[eventMacro] Code after the 'else' is a command, cleaning 'else' and rechecking line.\n", "eventMacro", 3;
						$self->{current_line} =~ s/^else\s*//;
						$check_need = 0;
						next DEFINE_COMMAND;
					} else {
						debug "[eventMacro] Entering true 'else' block inside 'switch' block.\n", "eventMacro", 3;
						$self->next_line;
						last SWITCH;
					}

				#Case on switch
				} elsif ($self->{current_line} =~ /^case/) {

					debug "[eventMacro] Found a 'case' block inside a 'switch' block.\n", "eventMacro", 3;

					# and on this part i am not getting the opening parenthsis, just the closing one
					# example: "case (= nipodemos) {" the regex will get only "= nipodemos) {"
					# the reason is because the opening parenthsis are coming from first part on switch block
					# creating the complete sentence "($name = nipodemos) {"
					my ($second_part) = $self->{current_line} =~ /^case\s*\(\s*(.*)/;

					unless ($second_part) {
						$self->error("All 'case' blocks must have a condition");
						return;
					}

					my $complete_condition = $first_part . $second_part ;
					debug "[eventMacro] complete condition is: '".$complete_condition."'.\n", "eventMacro", 3;
					my ($result, $after_case) = $self->parse_and_check_condition_text($complete_condition);
					return if (defined $self->error);
					unless ($after_case) {
						$self->error("All 'case' blocks must have a macro command or a block after it");
						return;
					}

					#True case check
					if ($result == 1) {
						debug "[eventMacro] Condition of 'case' is true.\n", "eventMacro", 3;
						if ($after_case ne "{") {
							debug "[eventMacro] Code after the 'case' is a command, cleaning 'case' and rechecking line.\n", "eventMacro", 3;
							$self->{current_line} =~ s/^case\s*\(.*\)\s*//;
							$check_need = 0;
							next DEFINE_COMMAND;
						} else {
							debug "[eventMacro] Entering true 'case' block.\n", "eventMacro", 3;
							$self->next_line;
							last SWITCH;
						}

					} else {
						debug "[eventMacro] Condition of 'case' is false.\n", "eventMacro", 3;
						if ($after_case eq "{") {
							debug "[eventMacro] There's a 'case' block to be cleaned.\n", "eventMacro", 3;
							my $block_count = 1;
							while ($block_count > 0) {
								$self->next_line;
								$self->define_current_line;

								if ($self->{finished}) {
									$self->{finished} = 0;
									$self->error("All 'case' blocks must be closed before the end of the macro");
									return;
								}

								debug "[eventMacro] Cleaning line '".$self->{current_line}."' inside 'case' block.\n", "eventMacro", 3;

								if (isNewCommandBlock($self->{current_line})) {
									$block_count++;
								} elsif ($self->{current_line} eq '}') {
									$block_count--;
								}
							}

						} else {
							debug "[eventMacro] There is a command after case, ignoring it\n", "eventMacro", 3;
						}

						#if after clean case block exist a '}', that means end of switch block
						if ($self->line_script(($self->line_index + 1)) eq '}') {
							debug "[eventMacro] End of 'switch' block\n", "eventMacro", 3;
							last SWITCH;
						}
					}
				} else {
					$self->error("Only 'else' and 'case' blocks are allowed inside switch blocks");
					return;
				}
			}

		######################################
		# If arriving at a line 'else' or 'elsif'
		######################################
		} elsif ($self->{current_line} =~ /^}\s*else\s*{/ || $self->{current_line} =~ /^}\s*elsif.*{$/) {

			debug "[eventMacro] Script is a not important condition block ('else' or 'elsif') after an 'if' block, cleaning it.\n", "eventMacro", 3;

			my $open_blocks = 1;
			while ($open_blocks > 0) {

				$self->next_line;
				$self->define_current_line;

				if ($self->{finished}) {
					$self->{finished} = 0;
					$self->error("All 'else' and 'elsif' blocks must be closed before the end of the macro)");
					return;
				}

				debug "[eventMacro] Cleaning line '".$self->{current_line}."' inside 'else' or 'elsif' block.\n", "eventMacro", 3;

				if (isNewCommandBlock($self->{current_line})) {
					$open_blocks++;
				} elsif ($self->{current_line} eq '}') {
					$open_blocks--;
				}
			}
			$self->next_line;

		######################################
		# Switch arriving at a line 'else' or 'case'
		######################################
		} elsif ($self->{current_line} =~ /^case/ || $self->{current_line} =~ /^else/) {
			my (undef, $after_case) = $self->{current_line} =~ /^(case\s*\(.*\)|else)\s*(.*)/;

			debug "[eventMacro] Script is a not important condition block ('else' or 'case') after an 'switch' block, cleaning it.\n", "eventMacro", 3;

			if ($after_case eq "{") {
				debug "[eventMacro] There's a 'case' or 'else' block to be cleaned.\n", "eventMacro", 3;
				my $block_count = 1;
				while ($block_count > 0) {
					$self->next_line;
					$self->define_current_line;

					if ($self->{finished}) {
						$self->{finished} = 0;
						$self->error("All 'case' and 'else' blocks must be closed before the end of the macro");
						return;
					}

					debug "[eventMacro] Cleaning line '".$self->{current_line}."' inside 'case' or 'else' block.\n", "eventMacro", 3;

					if (isNewCommandBlock($self->{current_line})) {
						$block_count++;
					} elsif ($self->{current_line} eq '}') {
						$block_count--;
					}
				}
			} else {
				debug "[eventMacro] After 'case' or 'else' there is a command, ignoring it.\n", "eventMacro", 3;
			}
			$self->next_line;

		######################################
		# Macro block: begin
		######################################
		} elsif ($self->{current_line} eq '[') {
			debug "[eventMacro] Script is the start of a macro block.\n", "eventMacro", 3;
			$self->{macro_block} = 1;
			$self->next_line;

		######################################
		# Macro block: end
		######################################
		} elsif ($self->{current_line} eq ']') {
			debug "[eventMacro] Script is the end of a macro block.\n", "eventMacro", 3;
			$self->{macro_block} = 0;
			$self->next_line;

		######################################
		# End block of "if", "switch" or "while"
		######################################
		} elsif ($self->{current_line} eq '}') {
			if ($self->{block}{end_to_start}{$self->line_index}{type} eq 'while') {
				debug "[eventMacro] Script is the end of a while 'block', moving to its start.\n", "eventMacro", 3;
				$self->line_index($self->{block}{end_to_start}{$self->line_index}{start});
			} else {
				debug "[eventMacro] Script is the end of a not important block (if or switch).\n", "eventMacro", 3;
				$self->next_line;
			}

		######################################
		# Label statement
		######################################
		} elsif ($self->{current_line} =~ /^:/) {
			debug "[eventMacro] Script is a label definition.\n", "eventMacro", 3;
			$self->next_line;

		######################################
		# Goto flow command
		######################################
		} elsif ($self->{current_line} =~ /^goto\s/) {
			my ($label) = $self->{current_line} =~ /^goto\s+([a-zA-Z][a-zA-Z\d_]*)/;
			if (exists $self->{label}->{$label}) {
				debug "[eventMacro] Script is a goto flow command.\n", "eventMacro", 3;
				$self->line_index($self->{label}->{$label});
			} else {
				$self->error("Cannot find label '$label'");
				return;
			}

		######################################
		# End (Should be a command)
		######################################
		} else {
			debug "[eventMacro] Next valid macro command found: '".$self->{current_line}."'.\n", "eventMacro", 3;
			last DEFINE_COMMAND;
		}
	}
}

# Processes next line of macro script
sub next {
	my $self = $_[0];

	#We must finish the subcall before returning to this macro
	return $self->manage_subcall if (defined $self->{subcall});

	#   All non command lines must be checked and parsed in only one 'next' cycle
	# define_next_valid_command makes sure the current line is a valid macro command
	# all flow control ('if', 'else', 'goto', 'while', etc) must be parsed by it.
	$self->define_next_valid_command;
	return if (defined $self->error);
	return "" if ($self->{finished});

	#Some debug messages
	debug "[eventMacro] Executing macro '".$self->{name}."', line index '".$self->line_index.".\n", "eventMacro", 2;
	debug "[eventMacro] Line script '".$self->{current_line}."'.\n", "eventMacro", 2;

	##########################################
	# set variable: variable = value
	if ($self->{current_line} =~ /^$general_variable_qr/i) {
		my $line = $self->{current_line};

		my $variable;
		my $value;
		if ($line =~ /^($general_wider_variable_qr)\s*([+-]{2}|=\s*.*)/) {
			$variable = $1;
			$value = $2;
			if ($variable =~ /^[\$\@\%]\./) {
				$self->error("You can't change the value of read-only variables");
				return;
			}
		} else {
			$self->error("Could not separate variable name from value");
			return;
		}

		my $var;
		my $display_name;

		if (my $var_hash = $self->find_and_define_key_index($variable)) {
			return if (defined $self->error);
			$var = $var_hash->{var};

		} else {
			return if (defined $self->error);
			$var = find_variable($1);
			if (defined $self->error) {
				return;
			} elsif (!defined $var) {
				$self->error("Could not define variable type");
				return;
			}
		}

		if ($var->{type} eq 'scalar' || $var->{type} eq 'accessed_array' || $var->{type} eq 'accessed_hash') {

			my $complement = (exists $var->{complement} ? $var->{complement} : undef);

			if ($value =~ /^=\s*(.*)/i) {
				my $val = $self->parse_command($1);

				if (defined $self->error) {
					return;

				} elsif (!defined $val) {
					$self->error("$val failed");
					return;

				} else {
					$eventMacro->set_var(
						$var->{type},
						$var->{real_name},
						($val =~ /^\s*(?:undef|unset)\s*$/i ? ('undef'):($val)),
						1,
						$complement
					);
				}

			} elsif ($value =~ /^([+-]{2})$/i) {
				my $change = (($1 eq '++') ? (1) : (-1));

				my $old_value = ($eventMacro->defined_var($var->{type}, $var->{real_name}, $complement) ? ($eventMacro->get_var($var->{type}, $var->{real_name}, $complement)) : 0);
				$eventMacro->set_var(
					$var->{type},
					$var->{real_name},
					($old_value + $change),
					1,
					$complement
				);

			} else {
				$self->error("unrecognized assignment");
				return;
			}

		} elsif ($var->{type} eq 'array' || $var->{type} eq 'hash') {
			if ($value =~ /^=\s*(.*)/i) {
				my $value = $1;

				if ($value =~ /(?:undef|unset)/) {
					$eventMacro->clear_array($var->{real_name}) if ($var->{type} eq 'array');
					$eventMacro->clear_hash($var->{real_name}) if ($var->{type} eq 'hash');

				} elsif ($value =~ /^\((.*)\)$/) {
					my @members = split(/\s*,\s*/, $1);

					if ($var->{type} eq 'array') {
						$eventMacro->set_full_array($var->{real_name}, \@members);

					} else {
						my %hash;
						foreach my $hash_member (@members) {
							if ($hash_member =~ /(.*\S)\s*=>\s*(\S.*)/) {
								my $key = $1;
								my $value = $2;
								$hash{$key} = $value;
							} else {
								$self->error("Bad syntax in hash key definition");
								return;
							}
						}
						$eventMacro->set_full_hash($var->{real_name}, \%hash);
					}

				} elsif ($value =~ /\w+\s*\(.*\)$/) {
					my $real_value = $self->parse_command($value);
					if ( (ref($real_value) eq 'ARRAY' || ref($real_value) eq 'HASH')  && $var->{type} eq 'hash') {

						#if is a array ref, have to convert into a hash ref
						if (ref($real_value) eq 'ARRAY') {
							my %hash = @{$real_value};
							$real_value = \%hash;
						}
						$eventMacro->set_full_hash($var->{real_name}, $real_value);

					} elsif (ref($real_value) eq '' && $real_value && $var->{type} eq 'array') {
						#elsif real value is defined is because something were returned, so it will make an array of that
						my @array = split (/,/, $real_value);
						$eventMacro->set_full_array($var->{real_name}, \@array);

					} elsif((ref($real_value) eq 'ARRAY' || ref($real_value) eq 'SCALAR') && $var->{type} eq 'array') {
						$eventMacro->set_full_array($var->{real_name}, $real_value);

					} else {
						# $real_value not defined, some error happened
						$self->error("Unable to set array or hash, empty value! (value: '$real_value')");
						return;
					}
				}

			} else {
				$self->error("unrecognized assignment");
				return;
			}
		}
		$self->next_line;
		$self->timeout(0);

	##########################################
	# manage array: push|unshift|shift|pop(@array[,new_member])
	} elsif ($self->{current_line} =~ /^$macro_keywords_character(push|unshift|pop|shift)/i) {
		$self->parse_command($self->{current_line});
		return if (defined $self->error);
		$self->timeout(0);
		$self->next_line;

	##########################################
	# manage hash: delete($hash{new_member})
	} elsif ($self->{current_line} =~ /^$macro_keywords_character(delete)/i) {
		$self->parse_command($self->{current_line});
		return if (defined $self->error);
		$self->timeout(0);
		$self->next_line;

	##########################################
	# returns command: do whatever
	} elsif ($self->{current_line} =~ /^do\s/) {
		my ($do_command) = $self->{current_line} =~ /^do\s+(.*)/;
		my $result = $self->parse_do($do_command);
		return $result if (defined $result);

	##########################################
	# log command
	} elsif ($self->{current_line} =~ /^(log|warning|error)\s+(.*)/) {
		my ($type, $log_text) = ($1, $2);
		$self->parse_log($type, $log_text);

	##########################################
	# pause command
	} elsif ($self->{current_line} =~ /^pause/) {
		my ($pause_command) = $self->{current_line} =~ /^pause\s*(.*)/;
		$self->parse_pause($pause_command);

	##########################################
	# stop command
	} elsif ($self->{current_line} eq "stop") {
		$self->stop_command();

	##########################################
	# release command
	} elsif ($self->{current_line} =~ /^release\s+/) {
		my ($release_command) = $self->{current_line} =~ /^release\s+(.*)/;
		$self->parse_release_and_lock($release_command, 2);

	##########################################
	# lock command
	} elsif ($self->{current_line} =~ /^lock\s+/) {
		my ($lock_command) = $self->{current_line} =~ /^lock\s+(.*)/;
		$self->parse_release_and_lock($lock_command, 1);

	##########################################
	# call command
	} elsif ($self->{current_line} =~ /^call\s+/) {
		my ($call_command) = $self->{current_line} =~ /^call\s+(.*)/;
		$self->parse_call($call_command);
		$self->timeout(0);

	##########################################
	# set command
	} elsif ($self->{current_line} =~ /^set\s+/) {
		my ($parameter, $new_value) = $self->{current_line} =~ /^set\s+(\w+)\s+(.*)$/;
		$self->parse_set($parameter, $new_value);

	##########################################
	# include command
	} elsif ($self->{current_line} =~ /^include\s+/) {
		my ($key, $param) = $self->{current_line} =~ /^include\s+(\w+)\s+(.*)$/;
		$self->parse_include($key, $param);

	##########################################
	# sub-routine command, still figuring out how to include unclever/fail sub-routine into the error msg
	} elsif ($self->{current_line} =~ /^(?:\w+)\s*\(.*?\)/) {
		$self->perl_sub_command;

	##########################################
	# unrecognized line
	} else {
		$self->error("Unrecognized macro command");
	}

	##########################################
	# For some reason returning undef is an error while returning an empty string is fine.
	if (defined $self->error) {
		return;
	} else {
		return "";
	}
}

sub parse_and_check_condition_text {
	my ($self, $line_script) = @_;

	#think on this possible statment:
	# if ( ( 1 = 1 ) && ( foo != bar ) ) {
	#this code will create an array of groups os parenthesis, starting by the smaller, until the bigger
	#so it will be like:
	#$group[0] = "( 1 = 1 )"
	#$group[1] = "( foo != bar )"
	#$group[2] = "( ( 1 = 1 ) && ( foo != bar) )"
	#so each group will be treated separetedly
	my @characters = split //, $line_script;

	my ($parenthesis_count,
		$in_regex,
		$in_quote,
		@start_of_group,
		$token,
		$ignore_next_closing_parenthesis,
		$start_of_macro_keyword,
		@groups,
		$start_of_variable,
	);

	CHAR: for (my $i = 0; $i < @characters ; $i++) {
		my $previous_char = $characters[$i-1];
		my $current_char  = $characters[$i];
		my $next_char     = $characters[$i+1];

		#end of regex if found a '/' and it's not a \/
		if (defined $in_regex) {
			if ($current_char eq '/' && $previous_char ne "\\") {
				undef $in_regex;
			}

		#end of quoted string if found a " and it's not a \"
		} elsif (defined $in_quote) {
			if ($current_char eq '"' && $previous_char ne "\\") {
				undef $in_quote;
			}

		#ignore if is inside a regex or if found a escaped \"
		} elsif (!defined $in_quote && $current_char eq '"') {
			unless ($previous_char eq "\\" || defined $in_regex) {
				$in_quote = 1;
			}

		#ignore if is inside a quoted_string or if found a escaped one '\/'
		} elsif (!defined $in_regex && $current_char eq '/') {
			unless ($previous_char eq '\\' || defined $in_quote) {
				$in_regex = 1;
			}

		#save every char on $token, until a space or special charecter appear
		#eventually it will become a macro_keyword or sub
		} elsif ( $current_char =~ /\w/) {
			if (!defined $start_of_variable) {
				if ($next_char =~ /\W/ && length($token) < 2) {
					undef $token if defined $token;
					next CHAR;
				} else {
					$token .= $current_char;
				}
			}

		} elsif ($current_char =~ /\s/) {

			# if a token is defined, then it can be a macro_keyword or a sub
			# but is treated on other case statement
			# if not, then undef token and start_of_macro_keyword and start_of_variable
			unless (defined $token && length($token) >= 3 && $next_char eq '(') {
				undef $start_of_macro_keyword;
				undef $token;
				undef $start_of_variable;
			}

		#this case block is only to prevent $token to save variables, which is useless
		#$token is meant to save only macro_keywords and subs
		} elsif ($current_char eq '$' || $current_char eq '@' || $current_char eq '%') {
			unless ($previous_char eq "\\") {
				$start_of_variable = 1;
			}

		} elsif ($current_char eq '&' ) {

			#ignore if is quoted string or regex or found a &&
			if ($previous_char eq '&' || $next_char eq '&') {
				undef $token                  if defined $token;
				undef $start_of_macro_keyword if defined $start_of_macro_keyword;

			#if is a & followed by a letter or number, is problably a macro keyword
			} elsif ($previous_char ne '&' && $next_char =~ /\w/) {
				undef $token;
				$start_of_macro_keyword = 1;

			# throw error
			} else {
				$self->error("unsupported '&' in statment (maybe you put just only one '&' instead of two?)");
				return;
			}

		} elsif ( $current_char eq '|' ) {

			#ignore if inside a quoted string or a regex
			if ($previous_char eq '|' || $next_char eq '|') {
				undef $token                  if defined $token;
				undef $start_of_macro_keyword if defined $start_of_macro_keyword;

			#else throw error
			} else {
				$self->error("unsupported '|' in statment (maybe you put only one '|' instead of two?)");
				return;
			}
		} elsif ( $current_char eq ')' ) {

			undef $start_of_macro_keyword if defined $start_of_macro_keyword;
			undef $token                  if defined $token;

			#this is when the ) is a closing pharenthesis of a macrokeyword or a sub
			#example: &npc(154 89) <--- this closing pharentesis will not be considered as a group end
			if ($ignore_next_closing_parenthesis > 0) {
				$ignore_next_closing_parenthesis--;
				next CHAR;
			}

			#end of the group
			$parenthesis_count--;
			if ($parenthesis_count < 0) {
				$self->error("missing at least one opening parenthesis or too many closing parenthesis");
				return;
			}

			#currently there is something that have to change:
			#start, end and lenght of group is only used on the main group (the entire statement)
			#the other groups those informations are irrelevant, so it shouldn't be stored
			my $lenght = ($i + 1) - $start_of_group[-1];
			my $script = substr ($line_script, $start_of_group[-1], $lenght);
			push @groups, {
				start => pop @start_of_group, #get last value of array
				end => $i+1,
				length => $lenght,
				script => $script
			};

			#end of entire statement
			if ($parenthesis_count == 0) {
				last CHAR;
			}

		} elsif ($current_char eq '(' ) {

			#oh, this might be a macro keyword or sub!
			if ($token && length($token) >= 3) {

				#probably a macro_keyword
				if (defined $start_of_macro_keyword) {
					#yeah it is
					if ($macroKeywords =~ /\b$token\b/) {
						$ignore_next_closing_parenthesis++;
						undef $token;
						undef $start_of_macro_keyword;
						next CHAR;

					#macro_keyword not found, probably typo
					} else {
						$self->error("unknown macro_keyword '&$token' (maybe you typed wrong?)");
						return;
					}

				#problably is a sub
				} else {
					my $sub_found;
					foreach (@{ $eventMacro->{subs_list} }) {

						#it is a sub!
						if ( $token eq $_) { #sub name
							$sub_found = 1;
							$ignore_next_closing_parenthesis++;
							undef $token;
							next CHAR;
						}
					}

					if (!$sub_found) {
						$self->error("unknown sub '$token' (maybe you typed wrong?)");
						return;
					}
				}
				undef $start_of_macro_keyword;
				undef $token;

			#it is nothing, so it will be ignored
			} else {
				undef $token;
				undef $start_of_macro_keyword;
			}

			push (@start_of_group, $i);
			$parenthesis_count++;
		}
	} #for loop end

	#its error time
	#multiple checks of commom errors
	if (defined $in_regex) {
		$self->error("unclosed regex found, please check your code\n");
		return;
	} elsif (defined $in_quote) {
		$self->error("unclosed quote found, please check your code\n");
		return;
	} elsif (defined $start_of_macro_keyword) {
		$self->error("unclosed macro_keyword found, please check your code");
		return;
	} elsif ($parenthesis_count > 0) {
		$self->error("unclosed parenthesis found, please check your code");
		return;
	}

	#the last group in the array is always the full statement
	#so post_if is what lies after end of main group
	my $post_if = substr ($line_script, $groups[-1]{end}+1);
	$post_if    =~ s/^\s+|\s+$//g;
	my $result  = $self->parse_condition_text_groups(\@groups);
	return if defined $self->error;

	return $result, $post_if;
}

sub parse_condition_text_groups {
	my ($self, $groups) = @_;
	my $result;

	#when it is a simple statemente, with only one group, then parse it 1 time only
	if ( scalar @{$groups} == 1) {
		$result = $self->parse_single_group($groups->[-1]->{script});
		return if (defined $self->error);

	#when it is a complex statement, with more than one group, parse each one of them
	#then replace the group byt its result on entire statement
	} else {
		my $entire_statement = pop @{$groups}; #original unparsed statement

		#now we will parse one group at a time, since it has more than one
		foreach my $group ( @{ $groups } ) {
			my $script = $group->{script};
			my $parsed = $self->parse_single_group($script);
			return if defined $self->error;
			#after parse a group, remove it from original script and replace by it's result
			$entire_statement->{script} =~ s/\Q$script\E/$parsed/;

		}
		#now that were parsed other groups inside result, lets parse result itself
		$result = $self->parse_single_group($entire_statement->{script});
		return if defined $self->error;
	}

	return $result;
}

sub parse_single_group {
	my ($self, $script) = @_;
	my @characters = split (//, $script);
	my ($negate, $first, $condition, $second);
	my $in_quote;
	my $in_regex;

	CHAR: for (my $i = 0; $i < @characters; $i++) {
		my $previous_char = $characters[$i-1];
		my $current_char = $characters[$i];
		my $next_char = $characters[$i+1];
		my $result;

		#end of regex if found a '/' and it's not a \/
		if (defined $in_regex) {
			if ($current_char eq '/' && $previous_char ne "\\") {
				undef $in_regex;
			}

		#end of quoted string if found a " and it's not a \"
		} elsif (defined $in_quote) {
			if ($current_char eq '"' && $previous_char ne "\\") {
				undef $in_quote;
			}

		#ignore if is inside a regex or if found a escaped\"
		} elsif (!defined $in_quote && $current_char eq '"') {
			unless ($previous_char eq "\\" || defined $in_regex) {
				$in_quote = 1;
			}

		#ignore if is inside a quoted_string or if found a escaped one '\/'
		} elsif (!defined $in_regex && $current_char eq '/') {
			unless ($previous_char eq '\\' || defined $in_quote) {
				$in_regex = 1;
			}

		#if there is no other char after ')', that is really end of group
		#it will be parsed unless is inside a quoted string or a regex
		} elsif ($current_char eq ')' && !defined $next_char) {
			#end of group that is being parsed
			$result = $self->resolve_statement($negate, $first, $condition, $second);
			return if (defined $self->error);

			$script =~ s/\Q$negate$first$condition$second\E/$result/
			or $self->error("NOT POSSIBLE TO MAKE SUBSTITUTION of '$negate$first$condition$second' in '$script', report to creators of eventMacro\n");
			return if (defined $self->error);


			$script = $self->resolve_multi_and_remove_parenthesis($script);
			return if (defined $self->error);
			undef $negate;
			undef $first;
			undef $condition;
			undef $second;

			return $script;

		#means it is the beginning of script, always a '(''
		} elsif ( $current_char eq '(' && $i == 0) {
			next CHAR;

		#if next char is also a & means that were found a '&&', that means that there is one statement to be parsed
		#if next char is also a | means that were found a '||', that means that there is one statement to be parsed
		} elsif ( ($current_char eq '&' && $next_char eq '&') || ($current_char eq '|' && $next_char eq '|') ) {
			$result = $self->resolve_statement($negate, $first, $condition, $second);
			return if (defined $self->error);

			$script =~ s/\Q$negate$first$condition$second\E/$result/
			or $self->error("NOT POSSIBLE TO MAKE SUBSTITUTION of '$negate$first$condition$second' in '$script', report to creators of eventMacro\n");
			return if (defined $self->error);

			undef $negate;
			undef $first;
			undef $condition;
			undef $second;
			$i++; #intentional, it is to skip the next &
			next CHAR;

		#special characters found, problably is $condition
		} elsif ( $current_char =~ /[=!~><]/ ) {

			if ( !defined $first || $first =~ /^\s+$/) {
				#if found a special character before first be defined, can only be two things
				#its the $negate char or it's a typo
				if ($current_char eq '!') {
					$negate = $first . '!'; #first is here only to get the whitespace
					undef $first; #clean spaces inside $first, they were passed to $negate
					next CHAR;
				} else {
					$self->error("Error in statement '$script': not expected '$current_char' here (use quotes if condition have special characters)");
					return;
				}

			#a condition
			} elsif ( defined $first && !defined $condition ) {
				$condition .= $current_char;
				if ($next_char =~ /[=!~><]/ ) {
					$condition .= $next_char;
					$i++;
				}
				next CHAR;

			#if there is already a condition, then is certainly an error
			} elsif ( defined $first && defined $condition) {
				$self->{errror} = "Error in statement '$script': not expected to have '$current_char' at index '$i' (use quotes if condition have special characters)";
				return;
			}
		}


		if (!defined $condition) {
			$first .= $current_char;
		} elsif ( defined $first && defined $condition ) {
			$second .= $current_char;
		}

	} #end of for loop

	#in theory should never gets here, so it's better to leave a error message case it gets here
	$self->error("unknown error found while parsing at sub parse_single_group, please create an issue on github about this");
	return;
}

sub parse_include {
	my ($self, $key, $param) = @_;

	my $parsed_key = $self->parse_command($key);
	my $parsed_param = $self->parse_command($param);
	return if (defined $self->error);

	if (!defined $parsed_key || !defined $parsed_param) {
		$self->error("Could not define include command");
		return;
	}

	if (
	($parsed_key ne 'list' && $parsed_key ne 'on' && $parsed_key ne 'off') ||
	($parsed_key eq 'list' && defined $parsed_param) ||
	(($parsed_key eq 'on' || $parsed_key eq 'off') && !defined $parsed_param)
	) {
		$self->error("Invalid include syntax");
		return;
	}
	$eventMacro->include($parsed_key, $parsed_param);

	$self->timeout($self->macro_delay);
	$self->next_line;
}

sub parse_do {
	my ($self, $do_command) = @_;
	my $parsed_command = $self->parse_command($do_command);
	return if (defined $self->error);

	unless (defined $parsed_command) {
		$self->error("Could not define do command");
		return;
	}

	if ($parsed_command =~ /^eventMacro\s+/) {
		$self->error("Do not use command 'eventMacro' inside macros");
	} elsif ($parsed_command =~ /^ai\s+clear$/) {
		$self->error("do not use 'ai clear' inside macros");
	}
	return if (defined $self->error);
	$self->timeout($self->macro_delay);
	$self->next_line;
	return $parsed_command;
}

#From here functions are intended to parse/execute macro commands
sub parse_log {
	my ($self, $type, $log_text) = @_;
	my $parsed_log = $self->parse_command($log_text);
	#type can be message, warning or error
	#log_text have the text that will be printed

	return if (defined $self->error);
	unless (defined $parsed_log) {
		$self->error("Could not define log value");
	} else {
		$type = "message" if $type eq "log";
		if (my $sub_ref = Log->can($type)) {
			$sub_ref->("[eventmacro $type] $parsed_log\n", "eventMacro");
		} else {
			$self->error("Unknown error found while trying to print '$type' log. Report to developers");
			return;
		}
	}
	$self->timeout($self->macro_delay);
	$self->next_line;
}

sub perl_sub_command {
	my ($self) = @_;
	$self->parse_command($self->{current_line});
	return if (defined $self->error);
	$self->timeout(0);
	$self->next_line;
}

sub parse_set {
	my ($self, $parameter, $new_value) = @_;
	if ($parameter eq 'macro_delay') {
		if ($new_value !~ /^[\d\.]*\d+$/) {
			$self->error("macro_delay parameter should be a number (decimals are accepted). Given value: '$new_value'");
		} else {
			$self->macro_delay($new_value);
		}
	} elsif ($parameter eq 'repeat') {
		if ($new_value !~ /^\d+$/) {
			$self->error("repeat parameter should be a number. Given value: '$new_value'");
		} else {
			$self->repeat($new_value);
		}
	} elsif ($parameter eq 'overrideAI') {
		if ($new_value !~ /^[01]$/) {
			$self->error("overrideAI parameter should be '0' or '1'. Given value: '$new_value'");
		} else {
			$self->overrideAI($new_value);
		}
	} elsif ($parameter eq 'exclusive') {
		if ($new_value !~ /^[01]$/) {
			$self->error("exclusive parameter should be '0' or '1'. Given value: '$new_value'");
		} else {
			$self->interruptible($new_value?0:1);
		}
	} elsif ($parameter eq 'self_interruptible') {
		if ($new_value !~ /^[01]$/) {
			$self->error("self_interruptible parameter should be '0' or '1'. Given value: '$new_value'");
		} else {
			$self->self_interruptible($new_value);
		}
	} elsif ($parameter eq 'orphan') {
		if ($new_value !~ /^(terminate|terminate_last_call|reregister|reregister_safe)$/) {
			$self->error("orphan parameter should be 'terminate', 'terminate_last_call', 'reregister' or 'reregister_safe'. Given value: '$new_value'");
		} else {
			$self->orphan($new_value);
		}
	} else {
		$self->error("Unrecognized parameter (supported parameters: 'macro_delay', 'repeat', 'overrideAI', 'exclusive', 'orphan')");
	}
	return if (defined $self->error);
	$self->timeout(0);
	$self->next_line;
}

sub stop_command {
	my ($self) = @_;
	debug "[eventMacro] Stopping macro '".$self->{name}."' because of stop command in macro script.\n", "eventMacro", 2;
	$self->{finished} = 1;
}

sub parse_pause {
	my ($self, $pause_command) = @_;
	if (defined $pause_command) {
		my $parsed_pause_command = $self->parse_command($pause_command);
		return if (defined $self->error);
		if (!defined $parsed_pause_command) {
			$self->error("pause value could not be defined");
		} elsif ($parsed_pause_command !~ /^\d+(?:\.\d+)?$/) {
			$self->error("pause value '$parsed_pause_command' must be numeric");
		} else {
			$self->timeout($parsed_pause_command);
		}
	} else {
		$self->timeout($self->macro_delay);
	}
	$self->next_line;
}

#Type 1 is lock
#Type 2 is release
sub parse_release_and_lock {
	my ($self, $release_command, $type) = @_;

	my $parsed_automacro_name = $self->parse_command($release_command);
	return if (defined $self->error);

	if (!defined $parsed_automacro_name) {
		$self->error("automacro name could not be defined");
	}
	return if (defined $self->error);

	if ($parsed_automacro_name eq 'all') {
		if ($type == 1) {
			$eventMacro->disable_all_automacros();
		} else {
			$eventMacro->enable_all_automacros();
		}

	} else {
		my $automacro = $eventMacro->{Automacro_List}->getByName($parsed_automacro_name);
		if (!defined $automacro) {
			$self->error("could not find automacro with name '$parsed_automacro_name'");
		}

		if ($type == 1) {
			$eventMacro->disable_automacro($automacro);
		} else {
			$eventMacro->enable_automacro($automacro);
		}
	}

	$self->timeout(0);
	$self->next_line;
}

sub parse_call {
	my ($self, $call_command) = @_;

	# Perform substitutions on the macro, so that macros can be called by variable.
	# For example:
	#   $macro = foo
	#   $value = bar
	#   call $macro $value baz
	$call_command = $self->substitue_variables( $call_command );

	my $macro_name   = $call_command;
	my $repeat_times = 1;
	if ( $call_command =~ /\s+/ ) {
	    my @params;
		( $macro_name, @params ) = parseArgs( $call_command );

		# Update $.param[n] with the values from the call.
		$eventMacro->set_full_array( ".param", \@params);
	}

	my $parsed_macro_name = $self->parse_command($macro_name);
	return if (defined $self->error);

	if (!defined $parsed_macro_name) {
		$self->error("macro name could not be defined");
	} elsif (!defined $eventMacro->{Macro_List}->getByName($parsed_macro_name)) {
		$self->error("could not find macro with name '$parsed_macro_name'");
	}
	return if (defined $self->error);

	$self->create_subcall($parsed_macro_name, $repeat_times);

	unless (defined $self->{subcall}) {
		$self->error("failed to create subcall '$parsed_macro_name'");
		return;
	}

	$self->timeout($self->macro_delay);
	$self->next_line;
}

sub resolve_statement {
	my ($self, $negate, $first, $cond, $last) = @_;

	#remove trailing whitespaces of beggining and end
	$first =~ s/^\s+|\s+$//g;
	$cond  =~ s/^\s+|\s+$//g;
	$last  =~ s/^\s+|\s+$//g;

	#remove quotes
	$first =~ s/^"(.+)"$/\1/;
	$last  =~ s/^"(.+)"$/\1/;

	#remove backslashes
	$first =~ s/\\([\/\"\'])/\1/;
	$last  =~ s/\\([\/\"\'])/\1/;

	my ($parsed_first, $parsed_last);


	#if none of them are defined, throw error
	if ( $first eq '' && $cond eq '' && $last eq '' ) {
		$self->error("syntax error in if statement (is empty?)");
		return;

	#if $first and $cond are defined and missing $last, throw error
	} elsif ( $first ne '' && $cond ne '' && $last eq '' ) {
		$self->error("Last argument doesn't exist (1st: '$first', cond: '$cond', last: '$last')");
		return;

	#if $cond and $last are defined, but missing $first, throw error
	} elsif ( $first eq '' && $cond ne '' && $last ne '' ) {
		$self->error("First argument doesn't exist (1st: '$first', cond: '$cond', last: '$last')");
		return;

	#if only first is defined, parse only first then
	} elsif ( $first ne '' && $cond eq '' && $last eq '' ) {
		$parsed_first = $self->parse_command($first);
		return if (defined $self->error);

	#if all of them are defined, then is ok and the statement will be tested
	} elsif ($first ne '' && $cond ne '' && $last ne '') {
		$parsed_first = $self->parse_command($first);
		$parsed_last  = $self->parse_command($last);
		return if (defined $self->error);
	}
	my $result = cmpr($parsed_first, $cond, $parsed_last);

	#if sub cmpr gave some error, result will be empty
	#else will be 0 or 1
	if ($result eq '') {
		$self->error("error shown above while comparing values on sub resolve_statement");
		return;
	}

	#if $negate is defined, then return the opposite result
	if (defined $negate) {
		return ($result ? 0 : 1);
	} else {
		return $result;
	}
}

sub resolve_multi_and_remove_parenthesis {
	my ($self, $text) = @_;
	my ($i, $n) = (0, 0);
	my %save;
	$text =~ s/\(|\)//g; #here we dont need the parenthesis anymore
	while ($text =~ /(\|{2}|\&{2})/g) {
		# Check if we put the wrong '&&' or '||' in the statement
		# Logically, each clean statement(none-bracket statement),
		# cant use the simbol '&&' or '||' together. Infact, it must be saperated
		# by using round brackets '(' and ')' in the 1st place

		$save{$i} = $1;
		if ($i > 0) {
			$n = $i - 1;
			if ($save{$i} ne $save{$n}) {
				my $s = $text;
				#$s =~ s/($save{$i})/\($1\) <-- HERE/g;    # Later maybe? ;p
				$self->error("Wrong Conditions: ($save{$n} vs $save{$i})");
				return;
			}
		}
		$i++
	}

	if ($save{$n} eq "||" && $i > 0) {
		my @split = split(/\s*\|{2}\s*/, $text);
		foreach my $e (@split) {
			next if $e eq "0";
			return 1 if $e eq "1";
		}
		return 0

	} elsif ($save{$n} eq "&&" && $i > 0) {
		my @split = split(/\s*\&{2}\s*/, $text);
		foreach my $e (@split) {
			next if $e eq "1";
			return 0 if $e eq "0";
			return 0
		}
		return 1

	} elsif ($i == 0) {
		return $text if $text =~ /^[0-1]$/;

	} else {
		$self->error("Could not resolve multi, report this error on github\n");
		return;
	}
}

#From here functions are meant to parse code and check order (I haven't even looked at them yet)
sub refined_macroKeywords {
	# To make sure if there is really no more &special keywords

	my @pair = $_[0] =~ /$macro_keywords_character($macroKeywords)\s*\(\s*(.*)\s*\)/i;
	return $_[0] unless @pair;

	$pair[1] = parse_command($pair[1]);
	my $new = $macro_keywords_character.$pair[0]."(".$pair[1].")";
	return $new;
}

# parses all macro perl sub-routine found in the macro script
sub parse_perl_subs {
	my ($command) = @_;
	my @full = $command =~ /(?:^|\s+)(\w+)\s*(\(\s*(.*?)\s*\).*)$/i;
	my @pair = ($full[0]);
	my ($bracketed) = extract_bracketed ($full[1], '()');
	return unless $bracketed;
	push @pair, substr ($bracketed, 1, -1);

	return unless @pair;

	while ($pair[1] =~ /(?:^|\s+)(\w+)\s*\(/) {
		@pair = parse_perl_subs ($pair[1])
	}

	return @pair
}

# Returns 0 if no key of index was found, otherwise return a hash of the format:
# %hash = (real_name => parsed_var_name, original_name => original_var_name, var => var)
sub find_and_define_key_index {
	my ($self, $text) = @_;

	if ($text =~ /(?:^|(?<=[^\\]))\$($valid_var_characters)(\[|\{)(.+)$/) {
		my $name = $1;
		my $open_bracket = $2;

		my $type = ($open_bracket eq '[' ? 'array' : 'hash');
		my $close_bracket = (($type eq 'hash') ? '}' : ']');

		my $rest = $3;

		my $key_index = get_key_or_index($open_bracket, $close_bracket, $rest);
		if (!defined $key_index) {
			$self->error("Could not define key of hash or index of array");
			return;

		} elsif ($key_index eq '') {
			$self->error("Empty key of hash or index of array");
			return;
		}

		my $parsed_key_index = $self->parse_command($key_index);
		if (defined $self->error) {
			return;
		} elsif (!defined $parsed_key_index) {
			$self->error("Could not parse key or index code");
			return;

		} elsif ($parsed_key_index eq '') {
			$self->error("Empty key of hash or index of array after parsing");
			return;

		} elsif ($type eq 'hash' && $parsed_key_index !~ /[a-zA-Z\d_]+/) {
			$self->error("Invalid syntax in key of hash (only use letters and numbers)");
			return;

		} elsif ($type eq 'array' && $parsed_key_index !~ /\d+/) {
			$self->error("Invalid syntax in index of array (only use numbers)");
			return;
		}

		my $real_name = ('$'.$name.$open_bracket.$parsed_key_index.$close_bracket);

		my $original_name = ('$'.$name.$open_bracket.$key_index.$close_bracket);

		my $var = find_variable($real_name);
		if (!defined $var) {
			$self->error("Could not define variable type");
			return;
		}
		return {real_name => $real_name, original_name => $original_name, var => $var};
	}
}

# substitute variables
sub substitue_variables {
	my ($self, $received, $get_entire_array_or_hash) = @_;

	my $remaining = $received;
	my $substituted;

	VAR: while ($remaining =~ /(?:^|(?<=[^\\]))$general_variable_qr/) {

		#accessed arrays and hashes
		if (my $var_hash = $self->find_and_define_key_index($remaining)) {
			return if (defined $self->error);
			my $var = $var_hash->{var};
			my $regex_name = quotemeta($var_hash->{original_name});

			if ($remaining =~ /^(.*?)(?:^|(?<=[^\\]))$regex_name(.*?)$/) {
				my $before_var = $1;
				my $after_var = $2;
				my $var_value = $eventMacro->get_var($var->{type}, $var->{real_name}, $var->{complement});
				$var_value = '' unless (defined $var_value);

				$remaining = $before_var.$var_value.$after_var;

			} else {
				$self->error("Could not find detected variable in code");
				return;
			}
			next VAR;

		} elsif ($remaining =~ /(?:^|(?<=[^\\]))($scalar_variable_qr|$array_variable_qr|$hash_variable_qr)/) {
			return if (defined $self->error);
			my $var = find_variable($1);

			my $regex_name = quotemeta($var->{display_name});
			if ($remaining =~ /^(.*?)(?:^|(?<=[^\\]))$regex_name(.*?)$/) {
				my $before_var = $1;
				my $after_var = $2;
				my $var_value;
				if ($var->{type} eq 'scalar') {
					$var_value = $eventMacro->get_scalar_var($var->{real_name});

				} elsif ($var->{type} eq 'array') {
					if ($get_entire_array_or_hash) {
						$var_value = $var->{display_name};
					} else {
						$var_value = $eventMacro->get_array_size($var->{real_name});
					}

				} elsif ($var->{type} eq 'hash') {
					if ($get_entire_array_or_hash) {
						$var_value = $var->{display_name};
					} else {
						$var_value = $eventMacro->get_hash_size($var->{real_name});
					}
				}
				$var_value = '' unless (defined $var_value);

				$substituted = $substituted . $before_var . $var_value;
				$remaining = $after_var;

			} else {
				$self->error("Could not find detected variable in code");
				return;
			}
			next VAR;
		}
	}

	$substituted .= $remaining;

	#Remove backslashes
	$substituted =~ s/\\($scalar_variable_qr|$array_variable_qr|$hash_variable_qr)/$1/g;

	return $substituted;
}



sub parse_keywords {
	my ($command) = @_;
	my @full = $command =~ /$macro_keywords_character($macroKeywords)\s*(\(\s*(.*?)\s*\).*)$/i;
	my @pair = ($full[0]);
	my ($bracketed) = extract_bracketed ($full[1], '()');
	return unless $bracketed;
	push @pair, substr ($bracketed, 1, -1);

	return unless @pair;
	if ($pair[0] eq 'arg') {
		return $command =~ /$macro_keywords_character(arg)\s*\(\s*(".*?",\s*(\d+|\$[a-zA-Z][a-zA-Z\d_]*))\s*\)/
	} elsif ($pair[0] eq 'random') {
		return $command =~ /$macro_keywords_character(random)\s*\(\s*(".*?")\s*\)/
	}
	while ($pair[1] =~ /$macro_keywords_character($macroKeywords)\s*\(/) {
		@pair = parse_keywords ($pair[1])
	}
	return @pair
}

# command line parser for macro
# returns undef if something went wrong, else the parsed command or "".
sub parse_command {
	my ($self, $command) = @_;
	return "" unless defined $command;
	my ($keyword, $inside_brackets, $parsed, $result, $sub, $val);

	while (($keyword, $inside_brackets) = parse_keywords($command)) {
		$result = "_%_";

		#if $keyword is different of every key inside qw(), then we will substitue variables
		unless (grep{$_ eq $keyword} qw(nick push unshift pop shift delete exists defined split keys values)) {
			$parsed = $self->substitue_variables($inside_brackets);
		}
		my $only_replace_once = 0;

		if ($keyword eq 'npc') {
			$result = getnpcID($parsed);

		} elsif ($keyword eq 'cart') {
			$result = (getItemIDs($parsed, $char->cart))[0];

		} elsif ($keyword eq 'Cart') {
			$result = join ',', getItemIDs($parsed, $char->cart);

		} elsif ($keyword eq 'inventory') {
			$result = (getInventoryIDs($parsed))[0];

		} elsif ($keyword eq 'Inventory') {
			$result = join ',', getInventoryIDs($parsed);

		} elsif ($keyword eq 'InventoryType') {
			$result = join ',', getInventoryTypeIDs($parsed);

		} elsif ($keyword eq 'store') {
			$result = (getItemIDs($parsed, $storeList))[0];

		} elsif ($keyword eq 'storage') {
			$result = (getStorageIDs($parsed))[0];

		} elsif ($keyword eq 'Storage') {
			$result = join ',', getStorageIDs($parsed);

		} elsif ($keyword eq 'player') {
			$result = getPlayerID($parsed);

		} elsif ($keyword eq 'monster') {
			$result = getMonsterID($parsed);

		} elsif ($keyword eq 'vender') {
			$result = getVenderID($parsed);

		} elsif ($keyword eq 'venderitem') {
			$result = (getItemIDs($parsed, $venderItemList))[0];

		} elsif ($keyword eq 'venderItem') {
			$result = join ',', getItemIDs($parsed, $venderItemList);

		} elsif ($keyword eq 'venderprice') {
			$result = getItemPrice($parsed, $venderItemList->getItems);

		} elsif ($keyword eq 'venderamount') {
			$result = getVendAmount(getItemIDs($parsed, $venderItemList), $venderItemList->getItems);

		} elsif ($keyword eq 'random') {
			$result = getRandom($parsed);
			$only_replace_once = 1;

		} elsif ($keyword eq 'rand') {
			$result = getRandomRange($parsed);
			$only_replace_once = 1;

		} elsif ($keyword eq 'invamount') {
			$result = getInventoryAmount($parsed);

		} elsif ($keyword eq 'cartamount') {
			$result = getCartAmount($parsed);

		} elsif ($keyword eq 'shopamount') {
			$result = getShopAmount($parsed);

		} elsif ($keyword eq 'storamount') {
			$result = getStorageAmount($parsed);

		} elsif ($keyword eq 'config') {
			$result = getConfig($parsed);

		} elsif ($keyword eq 'arg') {
			$result = getWord($parsed);

		} elsif ($keyword eq 'eval') {
			$result = eval($parsed) unless $Settings::lockdown;

		} elsif ($keyword eq 'listitem') {
			$result = getArgFromList($parsed);

		} elsif ($keyword eq 'strip') {
			$parsed =~ s/\(|\)//g;
			$result = $parsed;

		} elsif ($keyword eq 'split') {
			my ($pattern, $string) = get_pattern($inside_brackets);
			my @values = split($pattern, $self->substitue_variables($string));
			$result = join (',', @values);

		} elsif ($keyword eq 'keys') {
			$result = join ',', find_hash_and_get_keys($inside_brackets);;

		} elsif ($keyword eq 'values') {
			$result = join ',', find_hash_and_get_values($inside_brackets);

		} elsif ($keyword eq 'nick') {
			$parsed = $self->substitue_variables($inside_brackets);
			$result = q4rx2($parsed);

		} elsif ($keyword eq 'push' || $keyword eq 'unshift' || $keyword eq 'pop' || $keyword eq 'shift') {
			$result = $self->manage_array($keyword, $inside_brackets);
			return if (defined $self->error);
			$only_replace_once = 1;

		} elsif ($keyword eq 'exists' || $keyword eq 'delete') {
			$result = $self->manage_hash($keyword, $inside_brackets);
			return if (defined $self->error);
			$only_replace_once = 1;

		} elsif ($keyword eq 'defined') {
			$result = $self->parse_defined($inside_brackets);
			return if (defined $self->error);
			$only_replace_once = 1;

		} elsif ( $keyword eq 'questStatus' ) {
			$result = getQuestStatus( $parsed )->{$parsed} || 'unknown';

		} elsif ( $keyword eq 'questInactiveCount' ) {
			$result = grep { $_ eq 'inactive' } values %{ getQuestStatus( split /\s*,\s*/, $parsed ) };

		} elsif ( $keyword eq 'questIncompleteCount' ) {
			$result = grep { $_ eq 'incomplete' } values %{ getQuestStatus( split /\s*,\s*/, $parsed ) };

		} elsif ( $keyword eq 'questCompleteCount' ) {
			$result = grep { $_ eq 'complete' } values %{ getQuestStatus( split /\s*,\s*/, $parsed ) };

		}

		return unless defined $result;
		return $command if ($result eq '_%_');

		$inside_brackets = q4rx($inside_brackets);

		unless ($only_replace_once) {
			$command =~ s/$macro_keywords_character$keyword\s*\(\s*$inside_brackets\s*\)/$result/g
		} else {
			$command =~ s/$macro_keywords_character$keyword\s*\(\s*$inside_brackets\s*\)/$result/
		}
	}

	unless ($Settings::lockdown) {
		# any round bracket(pair) found after parse_keywords sub-routine were treated as macro perl sub-routine
		undef $result; undef $parsed;
		while (($sub, $val) = parse_perl_subs($command)) {
			my $sub_error = 1;
			foreach my $e (@perl_name) {
				if ($e eq $sub) {
					$sub_error = 0;
				}
			}
			if ($sub_error) {
				$self->error("Unrecognized --> $sub <-- Sub-Routine");
				return "";
			}
			$parsed = $self->substitue_variables($val, 1);

			#spliting $parsed to check if there is an array or hash
			my (@array_holder, %hash_holder);
			foreach (split /\s*,\s*/ , $parsed) {
				#if don't have quotation marks and it is not a number or a variable, add the quotation marks
				if ($_ !~ /"[^"]+"/ && $_ !~ /^\s*\d+\s*$/ && $_ !~ /$array_variable_qr|$hash_variable_qr/) {
					$parsed =~ s/$_/"$_"/;

				#elsif it is a variable or a number but has quotation marks, remove it
				} elsif ($_ =~ /"\s*$array_variable_qr\s*"|"\s*$hash_variable_qr\s*"/ || $_ =~ /"\s*\d+\s*"/) {
					#first remove quotation from $_
					$_ =~ s/\"//g;
					#after remove quotation from $parsed, using the $_ to find the correct place to remove
					$parsed =~ s/\"$_\"/$_/;
					#strange but it works
				}

				if (my $var = find_variable($_)) {
					#there is an array or a hash to pass to sub
					if ($var->{type} eq 'array') {
						#if array exists, gets the content and insert on array holder
						#then insert array_holder on $parsed
						if ($eventMacro->{Array_Variable_List_Hash}{ $var->{real_name}}) {
							@array_holder = @{ $eventMacro->{Array_Variable_List_Hash}{$var->{real_name}} };
							$parsed =~ s/$var->{real_name}/array_holder/;
						} else {
							$self->error("Array '" . $var->{display_name} . "' does not exist");
						}

					} elsif ($var->{type} eq 'hash') {
						#if hash exists, gets the content and insert on hash holder
						#then insert hash_holder on $parsed
						if ($eventMacro->{Hash_Variable_List_Hash}{$var->{real_name}}) {
							%hash_holder = %{ $eventMacro->{Hash_Variable_List_Hash}{$var->{real_name}} };
							$parsed =~ s/$var->{real_name}/hash_holder/;
						} else {
							$self->error(("Hash '" . $var->{display_name} . "' does not exist"));
						}
					} else {
						$self->error("Could not define variable type on calling sub");
						return "";
					}
				}
			}
			my $sub1 = 'main::'.$sub.'('.$parsed.')';
			my @testArray = eval($sub1);
			if ($@) {
				warning "[eventMacro] Error in eval '".$@."'\n";
			}
			return unless scalar(@testArray);
			if (scalar(@testArray) > 1 ) {
				#if this is true, user returned an array or hash that is not a reference
				#but the code demands a reference
				$result = \@testArray;
			} else {
				#can be a normal scalar value, or a reference to anything
				$result = $testArray[0];
			}
			if (ref($result) eq 'ARRAY' || ref($result) eq 'HASH' || ref($result) eq 'SCALAR') {
				return $result;
			}
			$val = q4rx $val;
			$command =~ s/$sub\s*\(\s*$val\s*\)/$result/g
		}
	}

	$command = $self->substitue_variables($command);
	return $command;
}

sub parse_defined {
	my ($self, $inside_brackets) = @_;

	my $var;
	if (my $var_hash = $self->find_and_define_key_index($inside_brackets)) {
		return if (defined $self->error);
		$var = $var_hash->{var};

	} else {
		return if (defined $self->error);
		$var = find_variable($inside_brackets);
	}

	if (!defined $var) {
		$self->error("Could not define variable type");
		return;

	} elsif ($var->{type} ne 'accessed_hash' && $var->{type} ne 'accessed_array' && $var->{type} ne 'scalar') {
		$self->error("defined function can only be used on scalars, hashes with keys or arrays with indexes, you trie to use it in a ".$var->{type});
		return;
	}

	my $complement = (exists $var->{complement} ? $var->{complement} : undef);

	return ($eventMacro->defined_var($var->{type}, $var->{real_name}, $complement));
}

sub manage_hash {
	my ($self, $keyword, $inside_brackets) = @_;

	if (my $var_hash = $self->find_and_define_key_index($inside_brackets)) {
		return if (defined $self->error);
		my $var = $var_hash->{var};
		if ($var->{type} ne 'accessed_hash') {
			$self->error("Bad exists syntax, variable not a hash name/key pair");
			return;
		}

		if ($keyword eq 'exists') {
			return ($eventMacro->exists_hash($var->{real_name}, $var->{complement}));

		} elsif ($keyword eq 'delete') {
			my $result = $eventMacro->delete_key($var->{real_name}, $var->{complement});
			$result = '' unless (defined $result);
			return $result;
		}

	} else {
		return if (defined $self->error);
		$self->error("Function '".$keyword."' must have a hash and a hash key as argument");
		return;
	}
}

sub manage_array {
	my ($self, $keyword, $inside_brackets) = @_;

	my @args = split(/\s*,\s*/, $inside_brackets, 2);
	my ($var);

	if ($args[0] =~ /^($array_variable_qr)/i) {
		$var = find_variable($1);
		if (defined $self->error) {
			return;
		} elsif (!defined $var) {
			$self->error("Could not define variable type in array manage");
			return;
		}
	} else {
		$self->error("'$args[0]' is not a valid array name");
		return;
	}

	my $parsed = $self->parse_command($args[1]);

	my $result;

	if ($keyword eq 'push') {
		if (@args != 2) {
			$self->error("push sintax must be 'push(\@var_name, new_member)'");
			return;
		}
		$result = $eventMacro->push_array($var->{real_name}, $parsed);

	} elsif ($keyword eq 'unshift') {
		if (@args != 2) {
			$self->error("unshift sintax must be 'unshift(\@var_name, new_member)'");
			return;
		}
		$result = $eventMacro->unshift_array($var->{real_name}, $parsed);

	} elsif ($keyword eq 'pop') {
		if (@args != 1) {
			$self->error("pop sintax must be 'pop(\@var_name)'");
			return;
		}
		$result = $eventMacro->pop_array($var->{real_name});

	} elsif ($keyword eq 'shift') {
		if (@args != 1) {
			$self->error("shift sintax must be 'shift(\@var_name)'");
			return;
		}
		$result = $eventMacro->shift_array($var->{real_name});
	} else {
		$self->error("Unknown array keyword used '".$keyword."'");
		return;
	}

	$result = '' unless (defined $result);
	return $result;
}

1;
