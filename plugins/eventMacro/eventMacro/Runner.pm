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
	getStorageAmount getVendAmount getConfig getWord q4rx q4rx2 getArgFromList getListLenght find_variable get_key_or_index getQuestStatus);
use eventMacro::Automacro;

# Creates the object
sub new {
	my ($class, $name, $repeat, $interruptible, $overrideAI, $orphan, $delay, $macro_delay, $is_submacro) = @_;

	return undef unless ($eventMacro->{Macro_List}->getByName($name));
	
	my $self = bless {}, $class;
	
	$self->{name} = $name;
	$self->{Paused} = 0;
	$self->{registered} = 0;
	$self->{finished} = 0;
	$self->{macro_block} = 0;
	
	$self->{subline_index} = undef;
	$self->{sublines_array} = [];
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
	$self->{subcall} = new eventMacro::Runner($name, $repeat, $self->interruptible, $self->overrideAI, $self->orphan, undef, $self->macro_delay, 1);
}

# destructor
sub DESTROY {
	my ($self) = @_;
	$self->unregister if (AI::inQueue('eventMacro') && !$self->{submacro});
}

# TODO: Check this
# sets or gets macro block flag
sub macro_block {
	my $script = $_[0];
	do {
		if (defined $_[1]) {
			$script->{macro_block} = $_[1];
		} else {
			return $script->{macro_block} if $script->{macro_block};
		}
	} while $script = $script->{subcall};
	
	return $_[1];
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
		if ($script->[$line] =~ /^(if|switch|while)\s+\(.*\)\s+{$/) {
			push @$block_starts, { type => $1, start => $line };
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

# Sets/Gets the current subline index
sub subline_index {
	my ($self, $subline_index) = @_;
	if (defined $subline_index) {
		$self->{subline_index} = $subline_index;
	}
	return $self->{subline_index};
}

# Gets the script of the given subline
sub subline_script {
	my ($self, $subline_index) = @_;
	return @{$self->{sublines_array}}[$subline_index];
}

# Defines the sublines variables
sub sublines_start {
	my ($self) = @_;
	my $full_line = $self->line_script($self->line_index);
	debug "[eventMacro] Line '".$full_line."' of index '".$self->line_index."' has sublines.\n", "eventMacro", 2;
	@{$self->{sublines_array}} = split(/\s*;\s*/, $full_line);
	$self->subline_index(0);
}

# Undefines the sublines variables
sub sublines_end {
	my ($self) = @_;
	debug "[eventMacro] Finished all sublines of line '".$self->line_script($self->line_index)."' of index '".$self->line_index."', continuing with next line.\n", "eventMacro", 2;
	undef $self->{sublines_array};
	undef $self->{subline_index};
	$self->next_line;
}

# Advances a line or a subline
sub next_line {
	my ($self) = @_;
	if (defined $self->{subline_index}) {
		$self->{subline_index}++;
	} else {
		$self->{line_index}++;
	}
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
	if (defined $self->subline_index) {
		$error_message .= 
		  "[eventMacro] Subline index of the error '".$self->subline_index."'\n".
		  "[eventMacro] Script of the subline '".$self->subline_script($self->subline_index)."'\n";
	}
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
	
	#Inside subline script
	} elsif (defined $self->subline_index) {
	
		#End of subline script
		if ($self->subline_index == scalar(@{$self->{sublines_array}})) {
			$self->sublines_end;
			$self->define_current_line;
		} else {
			$self->{current_line} = $self->subline_script($self->subline_index);
		}
		
	#Start of subline script
	} elsif ($self->line_script($self->line_index) =~ /;/) {
		$self->sublines_start();
		$self->{current_line} = $self->subline_script($self->subline_index);
		
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
			debug "[eventMacro] Checking macro '".$self->{name}."', line index '".$self->line_index."'".(defined $self->subline_index ? ", subline index '".$self->subline_index."'" : '')." for a macro command.\n", "eventMacro", 3;
			debug "[eventMacro] Script '".$self->{current_line}."'.\n", "eventMacro", 3;
		} else {
			debug "[eventMacro] Rechecking macro '".$self->{name}."', line index '".$self->line_index."'".(defined $self->subline_index ? ", subline index '".$self->subline_index."'" : '')." for a macro command after it was cleaned.\n", "eventMacro", 3;
			debug "[eventMacro] New cleaned script '".$self->{current_line}."'.\n", "eventMacro", 3;
			$check_need = 1;
		}
		
		######################################
		# While statement: while (foo <= bar) as label
		######################################
		if ($self->{current_line} =~ /^while\s/) {
			my ($condition_text) = $self->{current_line} =~ /^while\s+\(\s*(.*)\s*\)\s+{$/;
			
			debug "[eventMacro] Script is the start of a while 'block'.\n", "eventMacro", 3;
			
			my $result = $self->parse_and_check_condition_text($condition_text);
			return if (defined $self->error);
				
			if ($result) {
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
			my ($condition_text) = $self->{current_line} =~ /.+\s+if\s*\(\s*(.*)\s*\)$/;
			
			debug "[eventMacro] Script is a command with a postfixed 'if'.\n", "eventMacro", 3;
			
			my $result = $self->parse_and_check_condition_text($condition_text);
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
		} elsif ($self->{current_line} =~ /^if\s/) {
			my ($condition_text, $post_if) = $self->{current_line} =~ /^if\s+\(\s*(.*)\s*\)\s+(goto\s+.*|call\s+.*|stop|{|)\s*/;

			debug "[eventMacro] Script is a 'if' condition.\n", "eventMacro", 3;
			
			my $result = $self->parse_and_check_condition_text($condition_text);
			return if (defined $self->error);
			
			if ($result) {
				debug "[eventMacro] Condition of 'if' is true.\n", "eventMacro", 3;
				if ($post_if ne "{") {
					debug "[eventMacro] Code after the 'if' is a command, cleaning 'if' and rechecking line.\n", "eventMacro", 3;
					$self->{current_line} =~ s/^if\s*\(.*\)\s*//;
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
						
						#Start of another if block
						if ( $self->{current_line} =~ /^if.*{$/ ) {
							$block_count++;
							
						#End of an if block or start of else block
						} elsif ($self->{current_line} =~ /^}\s*else\s*{$/ && $block_count == 1) {
							debug "[eventMacro] Entering true 'else' block after false 'if' block.\n", "eventMacro", 3;
							last CHECK_IF;
							
						#End of an if block or start of else block
						} elsif ($self->{current_line} eq '}') {
							$block_count--;
							
						#Elsif check
						} elsif ( $self->{current_line} =~ /^}\s*elsif\s+\(\s*(.*)\s*\).*{$/ && $block_count == 1 ) {
							$result = $self->parse_and_check_condition_text($1);
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
						
						debug "[eventMacro] Cleaning [sub]line '".$self->{current_line}."' inside 'if' block.\n", "eventMacro", 3;
						
					}
				}
			}
			$self->next_line;
		
		######################################
		# Switch statement
		######################################
		} elsif ($self->{current_line} =~ /^switch.*{$/) {
			my ($first_part) = $self->{current_line} =~ /^switch\s*\(\s*(.*)\s*\)\s*{$/;

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
					my ($second_part, $after_case) = $self->{current_line} =~ /^case\s*\(\s*(.*)\s*\)\s*(.*)/;
					
					debug "[eventMacro] Found a 'case' block inside a 'switch' block.\n", "eventMacro", 3;
					debug "[eventMacro] Script of 'switch' block: '".$self->{current_line}."'.\n", "eventMacro", 3;
					
					unless ($second_part) {
						$self->error("All 'case' blocks must have a condition");
						return;
					}
					unless ($after_case) {
						$self->error("All 'case' blocks must have a macro command or a block after it");
						return;
					}
					
					my $complete_condition = $first_part . ' ' . $second_part;
				
					my $result = $self->parse_and_check_condition_text($complete_condition);
					return if (defined $self->error);
					
					#True case check
					if ($result) {
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
								
								debug "[eventMacro] Cleaning [sub]line '".$self->{current_line}."' inside 'case' block.\n", "eventMacro", 3;
								
								if (isNewCommandBlock($self->{current_line})) {
									$block_count++;
								} elsif ($self->{current_line} eq '}') {
									$block_count--;
								}
							}
						}
					}
				} else {
					$self->error("Only 'else' and 'case' blocks are allowed inside swtich blocks");
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
				
				debug "[eventMacro] Cleaning [sub]line '".$self->{current_line}."' inside 'else' or 'elsif' block.\n", "eventMacro", 3;
				
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
								
					debug "[eventMacro] Cleaning [sub]line '".$self->{current_line}."' inside 'case' or 'else' block.\n", "eventMacro", 3;
					
					if (isNewCommandBlock($self->{current_line})) {
						$block_count++;
					} elsif ($self->{current_line} eq '}') {
						$block_count--;
					}
				}
			} else {
				debug "[eventMacro] After 'case' or 'else' there was a command, ignoring it.\n", "eventMacro", 3;
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
			my ($label) = $self->{current_line} =~ /^goto\s+([a-zA-Z][a-zA-Z\d]*)/;
			if (exists $self->{label}->{$label}) {
				debug "[eventMacro] Script is a goto flow command.\n", "eventMacro", 3;
				if (defined $self->{subline_index}) {
					debug "[eventMacro] Finishing prematurely sublines of line '".$self->line_script($self->line_index)."' of index '".$self->line_index."' because of flow command.\n", "eventMacro", 2;
					undef $self->{sublines_array};
					undef $self->{subline_index};
				}
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

	#   All non command [sub]lines must be checked and parsed in only one 'next' cycle
	# define_next_valid_command makes sure the current line is a valid macro command
	# all flow control ('if', 'else', 'goto', 'while', etc) must be parsed by it.
	$self->define_next_valid_command;
	return if (defined $self->error);
	return "" if ($self->{finished});
	
	#Some debug messages
	debug "[eventMacro] Executing macro '".$self->{name}."', line index '".$self->line_index."'".(defined $self->subline_index ? ", subline index '".$self->subline_index."'" : '').".\n", "eventMacro", 2;
	debug "[eventMacro] ".(defined $self->subline_index ? "Subline" : 'Line')." script '".$self->{current_line}."'.\n", "eventMacro", 2;
		
	##########################################
	# set variable: variable = value
	if ($self->{current_line} =~ /^($general_variable_qr)/i) {
		my $line = $self->{current_line};
		
		my $variable;
		my $value;
		if ($line =~ /^(\$$valid_var_characters(?:\[.+?\]|\{.+?\})?|\@$valid_var_characters|\%$valid_var_characters)\s*([+-]{2}|=\s*(.*))/) {
			$variable = $1;
			$value = $2;
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
					
				} elsif ($var->{type} eq 'array' && $value =~ /^$macro_keywords_character(?:split)\(\s*(.*?)\s*\)$/) {
					my ( $pattern, $var_str ) = parseArgs( "$1", undef, ',' );
					$var_str =~ s/^\s+|\s+$//gos;
					my $split_var = find_variable( $var_str );
					$self->error( 'Variable not recognized' ), return if !$split_var;
					$eventMacro->set_full_array( $var->{real_name}, [ split $pattern, $eventMacro->get_split_var( $split_var ) ] );
				} elsif ($var->{type} eq 'array' && $value =~ /^$macro_keywords_character(keys|values)\(($hash_variable_qr)\)$/) {
					my $type = $1;
					my $var2 = find_variable($2);
					if (defined $self->error) {
						return;
					} elsif (!defined $var2) {
						$self->error("Could not define variable type in keys/values array setting");
						return;
					}
					
					my @new_array;
					if ($type eq 'keys') {
						@new_array = @{$eventMacro->get_hash_keys($var2->{real_name})};
						
					} elsif ($type eq 'values') {
						@new_array = @{$eventMacro->get_hash_values($var2->{real_name})};
					}
					
					$eventMacro->set_full_array($var->{real_name}, \@new_array);
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
	} elsif ($self->{current_line} =~ /^log\s+/) {
		my ($log_command) = $self->{current_line} =~ /^log\s+(.*)/;
		$self->parse_log($log_command);
		
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
	my ($self, $condition_text) = @_;
	
	my $parsed_text = $self->parse_command($condition_text);
	return if (defined $self->error);
	
	my $particle_text = $self->particle($parsed_text);
	
	if ($self->multi($particle_text)) {
		return 1;
	} else {
		return 0;
	}
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
	my ($self, $log_command) = @_;
	my $parsed_log = $self->parse_command($log_command);
	return if (defined $self->error);
	
	unless (defined $parsed_log) {
		$self->error("Could not define log value");
	} else {
		message "[eventmacro log] $parsed_log\n", "eventMacro";
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
	} elsif ($parameter eq 'orphan') {
		if ($new_value !~ /(terminate|terminate_last_call|reregister|reregister_safe)/) {
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


#From here functions are meant to parse code and check order (I haven't even looked at them yet)
sub statement {
	my ($self, $temp_multi) = @_;
	my ($first, $cond, $last) = $temp_multi =~ /^\s*"?(.*?)"?\s+([<>=!~]+?)\s+"?(.*?)"?\s*$/;
	if (!defined $first || !defined $cond || !defined $last) {
		$self->error("syntax error in if statement");
	} else {
		my $pfirst = $self->parse_command(refined_macroKeywords($first));
		my $plast = $self->parse_command(refined_macroKeywords($last));
		return if (defined $self->error);
		unless (defined $pfirst && defined $plast) {
			$self->error("either '$first' or '$last' has failed");
		} elsif (cmpr($pfirst, $cond, $plast)) {
			return 1;
		}
	}
	return 0
}

sub particle {
	# I need to test this main code alot becoz it will be disastrous if something goes wrong
	# in the if statement block below

	my ($self, $text) = @_;
	my @brkt;

	if ($text =~ /\(/) {
		@brkt = $self->txtPosition($text);
		$brkt[0] = $self->multi($brkt[0]) if !bracket($brkt[0]) && $brkt[0] =~ /[\(\)]/ eq "";
		$text = extracted($text, @brkt);
	}

	unless ($text =~ /\(/) {return $text}
	$text = $self->particle($text);
}

sub multi {
	my ($self, $text) = @_;
	my ($i, $n, $ok, $ok2) = (0, 0, 1, 0);
	my %save;

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
				$ok = 0;
				#$s =~ s/($save{$i})/\($1\) <-- HERE/g;    # Later maybe? ;p
				$self->error("Wrong Conditions: ($save{$n} vs $save{$i})");
			}
		}
		$i++
	}

	if ($save{$n} eq "||" && $ok && $i > 0) {
		my @split = split(/\s*\|{2}\s*/, $text);
		foreach my $e (@split) {
			next if $e eq "0";
			return 1 if $e eq "1";
			return 1 if $self->statement($e);
		}
		return 0
	}
	elsif ($save{$n} eq "&&" && $ok && $i > 0) {
		my @split = split(/\s*\&{2}\s*/, $text);
		foreach my $e (@split) {
			next if $e eq "1";
			return 0 if $e eq "0";
			next if $self->statement($e);
			return 0
		}
		return 1
	}
	elsif ($i == 0) {
		return $text if $text =~ /^[0-1]$/;
		return $self->statement($text)
	}
}

sub txtPosition {
	# This sub will deal which bracket is belongs to which statement,
	# Using this, will capture the most correct statement to be checked 1st before the next statement,
	# Ex: ((((1st statement)2nd statement)3rd statement)4th statement)
	# will return: $new[0] = "1st statement", $new[1] = 4, $new[2] = 16
   
	my ($self, $text) = @_;
	my ($start, $i) = (0, 0);
	my (@save, @new, $first, $last);
	my @w = split(//, $text);

	foreach my $e (@w) {
		if ($e eq ")" && $start) {
			 $last = $i; last
		}
		elsif ($e eq "(") {
			if ($start) {undef @save; undef $first}
			$start = 1; $first = $i;
		}
		else {if ($start) {push @save, $e}}
		$i++
	}

	$self->error("You probably missed 1 or more closing round-\nbracket ')' in the statement") if !defined $last;

	$new[0] = join('', @save);
	$new[1] = $first;
	$new[2] = $last;
	return @new
}

sub extracted {
	# Normally we just do substract s/// or s///g or using while grouping for s{}{} to delete or replace...
	# but for some cases, the perl substract is failed... atleast for this text
	# ex: $text = "(1 || 0) && 1 && 0" (or I might missed some info for the substract function?)
	# so, below code will simply ignore the (1 || 0) but will replace it with $brkt[0] which is either 1 or 0,
	# in return, the new $text will be in this format: $text = "1 && 1 && 0" if the $brkt[0] happened to be 1.

	my ($text, @brkt) = @_;
	my @save;
	my @w = split(//, $text);

	my $txt_length = scalar(@w);

	for (my $i = 0; $i < $txt_length; $i++) {
		if ($i == $brkt[1]) {push @save, $brkt[0]; next}
		next if $i > $brkt[1] && $i <= $brkt[2];
		push @save, $w[$i];
		next
	}
	
	$text = join('', @save);
	return $text
}

sub refined_macroKeywords {
	# To make sure if there is really no more @special keywords

	my @pair = $_[0] =~ /$macro_keywords_character($macroKeywords)\s*\(\s*(.*)\s*\)/i;
	return $_[0] unless @pair;

	$pair[1] = parse_command($pair[1]);
	my $new = $macro_keywords_character.$pair[0]."(".$pair[1].")";
	return $new;
}

sub bracket {
	# Scans $text for @special keywords

	my ($text, $dbg) = @_;
	my @brkt; my $i = 0;

	while ($text =~ /($macro_keywords_character)?($macroKeywords)?\s*\(\s*([^\)]+)\s*/g) {
		my ($first, $second, $third) = ($1, $2, $3);
		unless (defined $first && defined $second && !bracket($third, 1)) {
			message "Bracket Detected: $text <-- HERE\n", "menu" if ($dbg);
			$brkt[$i] = 1;
		} else {
			$brkt[$i] = 0;
		}
		$i++;
	}

	foreach my $e (@brkt) {
		if ($e == 1) {
			return 1;
		}
	}

	return 0;
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
			
		} elsif ($type eq 'hash' && $parsed_key_index !~ /[a-zA-Z\d]+/) {
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
	my ($self, $received) = @_;
	
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
					$var_value = $eventMacro->get_array_size($var->{real_name});
					
				} elsif ($var->{type} eq 'hash') {
					$var_value = $eventMacro->get_hash_size($var->{real_name});
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
		return $command =~ /$macro_keywords_character(arg)\s*\(\s*(".*?",\s*(\d+|\$[a-zA-Z][a-zA-Z\d]*))\s*\)/
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
		
		# first parse _then_ substitute. slower but safer
		if ($keyword ne 'nick' && $keyword ne 'push' && $keyword ne 'unshift' && $keyword ne 'pop' && $keyword ne 'shift' && $keyword ne 'exists' && $keyword ne 'delete' && $keyword ne 'defined') {
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
			$result = getVendAmount($parsed, $venderItemList->getItems);
			
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
			
		} elsif ($keyword eq 'listlength') {
			$result = getListLenght($parsed);
			
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
			$parsed = $self->substitue_variables($val);
			my $sub1 = "main::".$sub."(".$parsed.")";
			$result = eval($sub1);
			if ($@) {
				message "[eventMacro] Error in eval '".$@."'\n";
			}
			return unless defined $result;
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
