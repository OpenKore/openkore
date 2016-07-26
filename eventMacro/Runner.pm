package eventMacro::Runner;

use strict;

require Exporter;
our @ISA = qw(Exporter);

use Time::HiRes qw( &time );
use Globals;
use AI;
use Log qw(message error warning debug);
use Text::Balanced qw/extract_bracketed/;
use Utils qw/existsInList/;
use List::Util qw(max min sum);

use eventMacro::Data;
use eventMacro::Core;
use eventMacro::FileParser qw(isNewCommandBlock);
use eventMacro::Utilities qw(cmpr refreshGlobal getnpcID getItemIDs getItemPrice getStorageIDs getInventoryIDs
	getPlayerID getMonsterID getVenderID getRandom getRandomRange getInventoryAmount getCartAmount getShopAmount
	getStorageAmount getVendAmount getConfig getWord q4rx q4rx2 getArgFromList getListLenght);
use eventMacro::Automacro;

sub new {
	my ($class, $name, $repeat, $interruptible, $overrideAI, $orphan, $delay, $macro_delay, $is_submacro) = @_;

	return undef unless ($eventMacro->{Macro_List}->getByName($name));
	
	my $self = bless {}, $class;
	
	$self->{Name} = $name;
	$self->{Paused} = 0;
	$self->{registered} = 0;
	$self->{finished} = 0;
	$self->{macro_block} = 0;
	
	$self->{subline_index} = undef;
	$self->{sublines_array} = [];
	$self->{lines_array} = $eventMacro->{Macro_List}->getByName($name)->get_lines();
	$self->{line_index} = 0;
	
	$self->{label} = {scanLabels($self->{lines_array})};
	
	$self->{time} = time;
	
	$self->{subcall} = undef;
	$self->{error} = undef;
	$self->{last_subcall_overrideAI} = undef;
	$self->{last_subcall_interruptible} = undef;
	$self->{last_subcall_orphan} = undef;
	
	debug "[eventMacro] Macro object '".$self->{Name}."' created.\n", "eventMacro", 2;
	
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

sub last_subcall_overrideAI {
	my ($self, $overrideAI) = @_;
	if (defined $overrideAI) {
		$self->{last_subcall_overrideAI} = $overrideAI;
	}
	return $self->{last_subcall_overrideAI};
}
	
sub last_subcall_interruptible {
	my ($self, $interruptible) = @_;
	if (defined $interruptible) {
		$self->{last_subcall_interruptible} = $interruptible;
	}
	return $self->{last_subcall_interruptible};
}
	
sub last_subcall_orphan {
	my ($self, $orphan) = @_;
	if (defined $orphan) {
		$self->{last_subcall_orphan} = $orphan;
		}
	return $self->{last_subcall_orphan};
}

sub last_subcall_name {
	my ($self, $name) = @_;
	if (defined $name) {
		$self->{last_subcall_name} = $name;
	}
	return $self->{last_subcall_name};
}

# sets or get interruptible flag
sub interruptible {
	my ($self, $interruptible) = @_;
	
	if (defined $interruptible) {
		
		if (defined $self->{interruptible} && $self->{interruptible} == $interruptible) {
			debug "[eventMacro] Macro '".$self->{Name}."' interruptible state is already '".$interruptible."'.\n", "eventMacro", 2;
		} else {
			debug "[eventMacro] Now macro '".$self->{Name}."' interruptible state is '".$interruptible."'.\n", "eventMacro", 2;
			$self->{interruptible} = $interruptible;
		}
		
		if (!defined $self->{subcall}) {
			debug "[eventMacro] Since this macro is the last in the macro tree we will validate automacro checking to interruptible.\n", "eventMacro", 2;
			$self->validate_automacro_checking_to_interruptible($interruptible);
		}
		
	}
	return $self->{interruptible};
}

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
		debug "[eventMacro] Macro '".$self->{Name}."' cannot change automacro checking state because the user forced it into another state.\n", "eventMacro", 2;
		return;
	}
	
	if ($interruptible == 0) {
		debug "[eventMacro] Macro '".$self->{Name}."' is now stopping automacro checking..\n", "eventMacro", 2;
		$eventMacro->set_automacro_checking_status(PAUSED_BY_EXCLUSIVE_MACRO);
	
	} elsif ($interruptible == 1) {
		debug "[eventMacro] Macro '".$self->{Name}."' is now starting automacro checking..\n", "eventMacro", 2;
		$eventMacro->set_automacro_checking_status(CHECKING_AUTOMACROS);
	}
}

# sets or gets override AI value
sub overrideAI {
	my ($self, $overrideAI) = @_;
	
	if (defined $overrideAI) {
		
		if (defined $self->{overrideAI} && $self->{overrideAI} == $overrideAI) {
			debug "[eventMacro] Macro '".$self->{Name}."' overrideAI state is already '".$overrideAI."'.\n", "eventMacro", 2;
		} else {
			debug "[eventMacro] Now macro '".$self->{Name}."' overrideAI state is '".$overrideAI."'.\n", "eventMacro", 2;
			$self->{overrideAI} = $overrideAI;
		}
		
		if (!defined $self->{subcall}) {
			debug "[eventMacro] Since this macro is the last in the macro tree we will validate AI queue to overrideAI.\n", "eventMacro", 2;
			$self->validate_AI_queue_to_overrideAI($overrideAI);
		}
		
	}
	return $self->{overrideAI};
}

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

# registers to AI queue
sub register {
	my ($self) = @_;
	debug "[eventMacro] Macro '".$self->{Name}."' is now registering itself to AI queue.\n", "eventMacro", 2;
	AI::queue('eventMacro');
	$self->{registered} = 1;
}

# unregisters from AI queue
sub unregister {
	my ($self) = @_;
	debug "[eventMacro] Macro '".$self->{Name}."' is now deleting itself from AI queue.\n", "eventMacro", 2;
	AI::clear('eventMacro');
	$self->{registered} = 0;
}

# sets or gets method for orphaned macros
sub orphan {
	my ($self, $orphan) = @_;
	
	if (defined $orphan) {
		
		if (defined $self->{orphan} && $self->{orphan} eq $orphan) {
			debug "[eventMacro] Macro '".$self->{Name}."' orphan method is already '".$orphan."'.\n", "eventMacro", 2;
		} else {
			debug "[eventMacro] Now macro '".$self->{Name}."' orphan method is '".$orphan."'.\n", "eventMacro", 2;
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

# sets or gets timeout for next command
sub timeout {
	my ($self, $timeout) = @_;
	if (defined $timeout) {
		$self->{timeout} = $timeout;
	}
	return { time => $self->{time}, timeout => $self->{timeout} };
}

# sets macro_delay timeout for this macro
sub macro_delay {
	my ($self, $macro_delay) = @_;
	if (defined $macro_delay) {
		$self->{macro_delay} = $macro_delay;
	}
	return $self->{macro_delay};
}

# checks register status
sub registered {
	my ($self) = @_;
	return $self->{registered};
}

sub repeat {
	my ($self, $repeat) = @_;
	if (defined $repeat) {
		debug "[eventMacro] Now macro '".$self->{Name}."' will repeat itself '".$repeat."' times.\n", "eventMacro", 2;
		$self->{repeat} = $repeat;
	}
	return $self->{repeat};
}

sub pause {
	my ($self) = @_;
	$self->{Paused} = 1;
}

sub unpause {
	my ($self) = @_;
	$self->{Paused} = 0;
}

sub is_paused {
	my ($self) = @_;
	return $self->{Paused};
}

sub get_name {
	my ($self) = @_;
	return $self->{Name};
}

sub clear_subcall {
	my ($self) = @_;
	debug "[eventMacro] Clearing submacro '".$self->{subcall}->{Name}."' from macro '".$self->{Name}."'.\n", "eventMacro", 2;
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

sub create_subcall {
	my ($self, $name, $repeat) = @_;
	debug "[eventMacro] Creating submacro '".$name."' on macro '".$self->{Name}."'.\n", "eventMacro", 2;
	$self->{subcall} = new eventMacro::Runner($name, $repeat, $self->interruptible, $self->overrideAI, $self->orphan, undef, $self->macro_delay, 1);
}

# destructor
sub DESTROY {
	my ($self) = @_;
	$self->unregister if (AI::inQueue('eventMacro') && !$self->{submacro});
}

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

# returns whether or not the macro finished
sub finished {
	my ($self) = @_;
	return $self->{finished}
}

# re-sets the timer
sub ok {
	my ($self) = @_;
	$self->{time} = time
}

# scans the script for labels
sub scanLabels {
	my $script = $_[0];
	my %labels;
	for (my $line = 0; $line < @{$script}; $line++) {
		if (${$script}[$line] =~ /^:/) {
			my ($label) = ${$script}[$line] =~ /^:(.*)/;
			$labels{$label} = $line
		}
		if (${$script}[$line] =~ /^while\s+/) {
			my ($label) = ${$script}[$line] =~ /\s+as\s+(.*)/;
			$labels{$label} = $line
		}
		if (${$script}[$line] =~ /^end\s+/) {
			my ($label) = ${$script}[$line] =~ /^end\s+(.*)/;
			$labels{"end ".$label} = $line
		}
	}
	return %labels
}

sub manage_script_end {
	my ($self) = @_;
	debug "[eventMacro] Macro '".$self->{Name}."' got to the end of its script.\n", "eventMacro", 2;
	if ($self->{repeat} > 1) {
		$self->{repeat}--;
		$self->{line_index} = 0;
		debug "[eventMacro] Repeating macro '".$self->{Name}."'. Remaining repeats: '".$self->{repeat}."'.\n", "eventMacro", 2;
	} else {
		$self->{finished} = 1;
		debug "[eventMacro] Macro '".$self->{Name}."' finished.\n", "eventMacro", 2;
	}
}

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

# returns and/or set the current line number
sub line_index {
	my ($self, $line_index) = @_;
	if (defined $line_index) {
		$self->{line_index} = $line_index;
	}
	return $self->{line_index};
}

# returns and/or set the current subline number
sub subline_index {
	my ($self, $subline_index) = @_;
	if (defined $subline_index) {
		$self->{subline_index} = $subline_index;
	}
	return $self->{subline_index};
}

# Gets the script of the given line
sub line_script {
	my ($self, $line_index) = @_;
	return @{$self->{lines_array}}[$line_index];
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

# Gets the script of the given subline
sub subline_script {
	my ($self, $subline_index) = @_;
	return @{$self->{sublines_array}}[$subline_index];
}

# Defines the sublines variables
sub create_sublines {
	my ($self) = @_;
	debug "[eventMacro] Line '".$self->{current_line}."' of index '".$self->line_index."' has sublines.\n", "eventMacro", 2;
	@{$self->{sublines_array}} = split(/\s*;\s*/, $self->{current_line});
	$self->subline_index(0);
}

# Undefines the sublines variables
sub end_of_sublines {
	my ($self) = @_;
	debug "[eventMacro] Finished all sublines of line '".$self->line_script($self->line_index)."' of index '".$self->line_index."', continuing with next line.\n", "eventMacro", 2;
	undef $self->{sublines_array};
	undef $self->{subline_index};
	$self->next_line;
}

# Sets the error message
sub error {
	my ($self, $error) = @_;
	if (defined $error) {
		$self->{error} = $error;
	}
	return $self->{error};
}

# Returns a more informative error message
sub error_message {
	my ($self) = @_;
	my $error_message = 
	  "[eventMacro] Error in macro '".$self->{Name}."'\n".
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

# processes next line
sub next {
	my $self = $_[0];
	
	#Checks if we reached the end of the script
	if ( $self->{line_index} == scalar (@{$self->{lines_array}}) ) {
		$self->manage_script_end();
		return "" if ($self->{finished});
	}
	
	#We must finish the subcall before returning to this macro
	return $self->manage_subcall() if (defined $self->{subcall});
	
	#End of subline script
	if (defined $self->subline_index && $self->subline_index == scalar(@{$self->{sublines_array}})) {
		$self->end_of_sublines;
		
		#End of subline script and end of macro script
		if ( $self->{line_index} == scalar (@{$self->{lines_array}}) ) {
			$self->manage_script_end();
			return "" if ($self->{finished});
		}
		
		$self->{current_line} = $self->line_script($self->line_index);
	
	#Inside subline script
	} elsif (defined $self->subline_index) {
		$self->{current_line} = $self->subline_script($self->subline_index);
		
	#Normal script
	} else {
		$self->{current_line} = $self->line_script($self->line_index);
	}
	
	#Start of subline script
	if ($self->{current_line} =~ /;/) {
		$self->create_sublines;
		$self->{current_line} = $self->subline_script($self->subline_index);
	}
	
	debug "[eventMacro] Executing macro '".$self->{Name}."', line index '".$self->line_index."'".(defined $self->subline_index ? ", subline index '".$self->subline_index."'" : '').".\n", "eventMacro", 2;
	debug "[eventMacro] ".(defined $self->subline_index ? "Subline" : 'Line')." script '".$self->{current_line}."'.\n", "eventMacro", 2;
	
	
	# TODO: separate line advancing and timeout setting

	# "If" postfix control
	if ($self->{current_line} =~ /.+\s+if\s*\(.*\)$/) {
		my ($text) = $self->{current_line} =~ /.+\s+if\s*\(\s*(.*)\s*\)$/;
		$text = $self->parse_command($text);
		return if (defined $self->error);
		my $savetxt = $self->particle($text);
		if ($self->multi($savetxt)) {
			$self->{current_line} =~ s/\s+if\s*\(.*\)$//;
		} else {
			$self->next_line;
			$self->timeout(0);
			return "";
		}
	}
	
	##########################################
	# jump to label: goto label
	if ($self->{current_line} =~ /^goto\s/) {
		my ($tmp) = $self->{current_line} =~ /^goto\s+([a-zA-Z][a-zA-Z\d]*)/;
		if (exists $self->{label}->{$tmp}) {
			$self->line_index($self->{label}->{$tmp});
		} else {
			$self->error("cannot find label $tmp");
			return;
		}
		$self->timeout(0);
	
	##########################################
	# declare block ending: end label
	} elsif ($self->{current_line} =~ /^end\s/) {
		my ($tmp) = $self->{current_line} =~ /^end\s+(.*)/;
		if (exists $self->{label}->{$tmp}) {
			$self->line_index($self->{label}->{$tmp});
		} else {
			$self->error("cannot find block start for $tmp");
			return;
		}
		$self->timeout(0);
		
	##########################################
	# macro block: begin
	} elsif ($self->{current_line} eq '[') {
		$self->{macro_block} = 1;
		$self->next_line;
		
	##########################################
	# macro block: end
	} elsif ($self->{current_line} eq ']') {
		$self->{macro_block} = 0;
		$self->timeout(0);
		$self->next_line;
	
	##########################################
	# if statement: if (foo = bar) goto label?
	# Unlimited If Statement by: ezza @ http://forums.openkore.com/
	} elsif ($self->{current_line} =~ /^if\s/) {
		my ($text, $then) = $self->{current_line} =~ /^if\s+\(\s*(.*)\s*\)\s+(goto\s+.*|call\s+.*|stop|{|)\s*/;

		# The main trick is parse all the @special keyword and vars 1st,
		$text = $self->parse_command($text);
		return if (defined $self->error);
		my $savetxt = $self->particle($text);
		if ($self->multi($savetxt)) {
			$self->newThen($then);
			return if (defined $self->error);
		} elsif ($then eq "{") { # If the condition is false because "if" this is not using the command block
			my $countBlockIf = 1;
			while ($countBlockIf) {
				$self->next_line;
				my $searchEnd = $self->line_script($self->line_index);
				
				if ($searchEnd =~ /^if.*{$/) {
					$countBlockIf++;
				} elsif (($searchEnd eq '}') || ($searchEnd =~ /^}\s*else\s*{$/ && $countBlockIf == 1)) {
					$countBlockIf--;
				} elsif ($searchEnd =~ /^}\s*elsif\s+\(\s*(.*)\s*\).*{$/ && $countBlockIf == 1) {
					# If the condition of 'elsif' is true, the commands of your block will be executed,
					#  if false, will not run.
					$text = $self->parse_command($1);
					return if (defined $self->error);
					$savetxt = $self->particle($text);
					if ($self->multi($savetxt)) {
						$countBlockIf--;
					}
				}
			}
		}
		$self->next_line;
		$self->timeout(0);

	##########################################
	# If arriving at a line 'else', 'elsif' or 'case', it should be skipped -
	#  it will never be activated if coming from a false 'if' or a previous 'case' has not been called
	} elsif ($self->{current_line} =~ /^}\s*else\s*{/ || $self->{current_line} =~ /^}\s*elsif.*{$/ || $self->{current_line} =~ /^case/ || $self->{current_line} =~ /^else/) {
		my $countCommandBlock = 1;
		while ($countCommandBlock) {
			$self->next_line;
			my $searchEnd = $self->line_script($self->line_index);
			
			if (isNewCommandBlock($searchEnd)) {
				$countCommandBlock++;
			} elsif ($searchEnd eq '}') {
				$countCommandBlock--;
			}
		}

		$self->timeout(0);

	##########################################
	# switch statement:
	} elsif ($self->{current_line} =~ /^switch.*{$/) {
		my ($firstPartCondition) = $self->{current_line} =~ /^switch\s*\(\s*(.*)\s*\)\s*{$/;

		my $countBlocks = 1;
		while ($countBlocks) {
			$self->next_line;
			my $searchNextCase = $self->line_script($self->line_index);
			
			if ($searchNextCase =~ /^else/) {
				my ($then) = $searchNextCase =~ /^else\s*(.*)/;
				$self->newThen($then);
				return if (defined $self->error);
				last;
			}
			
			my ($secondPartCondition, $then) = $searchNextCase =~ /^case\s*\(\s*(.*)\s*\)\s*(.*)/;
			next if (!$secondPartCondition);
			
			my $completCondition = $firstPartCondition . ' ' . $secondPartCondition;
			my $text = $self->parse_command($completCondition);
			return if (defined $self->error);
			my $savetxt = $self->particle($text);
			if ($self->multi($savetxt)) {
				$self->newThen($then);
				return if (defined $self->error);
				last;
			} elsif ($searchNextCase =~ /^case.*{$/) {
				my $countCommandBlock = 1;
				while ($countCommandBlock) {
					$self->next_line;
					my $searchEnd = $self->line_script($self->line_index);
					
					if (isNewCommandBlock($searchEnd)) {
						$countCommandBlock++;
					} elsif ($searchEnd eq '}') {
						$countCommandBlock--;
					}
				}
			}
		}
		
		$self->next_line;
		$self->timeout(0);
	
	##########################################
	# end block of "if" or "switch"
	} elsif ($self->{current_line} eq '}') {
		$self->next_line;
		$self->timeout(0);

	##########################################
	# while statement: while (foo <= bar) as label
	} elsif ($self->{current_line} =~ /^while\s/) {
		my ($text, $label) = $self->{current_line} =~ /^while\s+\(\s*(.*)\s*\)\s+as\s+(.*)/;
		my $text = $self->parse_command($text);
		return if (defined $self->error);
		my $savetxt = $self->particle($text);
		if (!$self->multi($savetxt)) {
			$self->line_index($self->{label}->{"end ".$label});
		}
		$self->next_line;
		$self->timeout(0);
		
	##########################################
	# set variable: $variable = value
	} elsif ($self->{current_line} =~ /^\$[a-z]/i) {
		my ($var, $val);
		if (($var, $val) = $self->{current_line} =~ /^\$([a-z][a-z\d]*?)\s+=\s+(.*)/i) {
			my $pval = $self->parse_command($val);
			return if (defined $self->error);
			if (defined $pval) {
				if ($pval =~ /^\s*(?:undef|unset)\s*$/i && $eventMacro->exists_var($var)) {
					$eventMacro->set_var($var, 'undef');
				} else {
					$eventMacro->set_var($var, $pval);
				}
			} else {
				$self->error("$val failed");
			}
		} elsif (($var, $val) = $self->{current_line} =~ /^\$([a-z][a-z\d]*?)([+-]{2})$/i) {
			if ($val eq '++') {
				if ($eventMacro->is_var_defined($var)) {
					$eventMacro->set_var($var, ($eventMacro->get_var($var)+1));
				} else {
					$eventMacro->set_var($var, 1);
				}
			} else {
				if ($eventMacro->is_var_defined($var)) {
					$eventMacro->set_var($var, ($eventMacro->get_var($var)-1));
				} else {
					$eventMacro->set_var($var, -1);
				}
			}
		} else {
			$self->error("unrecognized assignment");
		}
		$self->next_line;
		$self->timeout(0);
		
	##########################################
	# label definition: :label
	} elsif ($self->{current_line} =~ /^:/) {
		$self->next_line;
		$self->timeout(0)
		
	##########################################
	# returns command: do whatever
	} elsif ($self->{current_line} =~ /^do\s/) {
		my ($tmp) = $self->{current_line} =~ /^do\s+(.*)/;
		if ($tmp =~ /^macro\s+/) {
			my ($arg) = $tmp =~ /^macro\s+(.*)/;
			if ($arg =~ /^reset/) {
				$self->error("use 'release' instead of 'macro reset'");
			} elsif ($arg eq 'pause' || $arg eq 'resume') {
				$self->error("do not use 'macro pause' or 'macro resume' within a macro");
			} elsif ($arg =~ /^set\s/) {
				$self->error("do not use 'macro set'. Use \$foo = bar");
			} elsif ($arg eq 'stop') {
				$self->error("use 'stop' instead");
			} elsif ($arg !~ /^(?:list|status)$/) {
				$self->error("use 'call $arg' instead of 'macro $arg'");
			}
		} elsif ($tmp =~ /^ai\s+clear$/) {
			$self->error("do not mess around with ai in macros");
		}
		my $result = $self->parse_command($tmp);
		return if (defined $self->error);
		unless (defined $result) {
			$self->error("command $tmp failed");
			return;
		}
		$self->timeout($self->macro_delay);
		$self->next_line;
		return $result;
		
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
	# sub-routine command, still figuring out how to include unclever/fail sub-routine into the error msg
	} elsif ($self->{current_line} =~ /^(?:\w+)\s*\(.*?\)/) {
		$self->parse_perl_sub;
		
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

sub newThen {
	my ($self, $then) = @_;

	if ($then =~ /^goto\s/) {
		my ($label) = $then =~ /^goto\s+([a-zA-Z][a-zA-Z\d]*)$/;
		if (exists $self->{label}->{$label}) {
			$self->{line_index} = $self->{label}->{$label}
		} else {
			$self->error("cannot find label $label");
		}
		
	} elsif ($then =~ /^call\s+/) {
		my ($call_command) = $then =~ /^call\s+(.*)/;
		$self->parse_call($call_command);
		
	} elsif ($then eq "stop") {
		$self->{finished} = 1;
	}
}

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

sub parse_perl_sub {
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
	debug "[eventMacro] Stopping macro '".$self->{Name}."' because of stop command in macro script.\n", "eventMacro", 2;
	$self->{finished} = 1;
}

sub parse_pause {
	my ($self, $pause_command) = @_;
	if (defined $pause_command) {
		my $parsed_pause_command = $self->parse_command($pause_command);
		return if (defined $self->error);
		if (!defined $parsed_pause_command) {
			$self->error("pause value could not be defined");
		} elsif ($parsed_pause_command !~ /^\d+$/) {
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
	} elsif (!defined $eventMacro->{Automacro_List}->getByName($parsed_automacro_name)) {
		$self->error("could not find automacro with name '$parsed_automacro_name'");
	}
	return if (defined $self->error);
	
	my $automacro = $eventMacro->{Automacro_List}->getByName($parsed_automacro_name);
	
	if ($type == 1) {
		$automacro->disable();
	} else {
		$automacro->enable();
	}
	
	$self->timeout(0);
	$self->next_line;
}

sub parse_call {
	my ($self, $call_command) = @_;
	
	my $repeat_times;
	my $macro_name;
	
	if ($call_command =~ /\s/) {
		($macro_name, $repeat_times) = $call_command =~ /(.*?)\s+(.*)/;
		my $parsed_repeat_times = $self->parse_command($repeat_times);
		return if (defined $self->error);
		if (!defined $parsed_repeat_times) {
			$self->error("repeat value could not be defined");
		} elsif ($parsed_repeat_times !~ /^\d+$/) {
			$self->error("repeat value '$parsed_repeat_times' must be numeric");
		} elsif ($parsed_repeat_times <= 0) {
			$self->error("repeat value '$parsed_repeat_times' must be bigger than 0");
		}
		return if (defined $self->error);
		$repeat_times = $parsed_repeat_times;
	} else {
		$macro_name = $call_command;
		$repeat_times = 1;
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
	
	
	#my @new_params = substr($cparms, 2) =~ /"[^"]+"|\S+/g;
	#foreach my $p (1..@new_params) {
	#	$eventMacro->set_var(".param".$p,$new_params[$p-1]);
	#	$eventMacro->set_var(".param".$p,substr($eventMacro->get_var(".param".$p), 1, -1)) if ($eventMacro->get_var(".param".$p) =~ /^".*"$/);
	#}
}


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

	my @pair = $_[0] =~ /\@($macroKeywords)\s*\(\s*(.*)\s*\)/i;
	return $_[0] unless @pair;

	$pair[1] = parse_command($pair[1]);
	my $new = "@".$pair[0]."(".$pair[1].")";
	return $new;
}

sub bracket {
	# Scans $text for @special keywords

	my ($text, $dbg) = @_;
	my @brkt; my $i = 0;

	while ($text =~ /(\@)?($macroKeywords)?\s*\(\s*([^\)]+)\s*/g) {
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
	my @full = $_[0] =~ /(?:^|\s+)(\w+)s*((s*(.*?)s*).*)$/i;
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

# substitute variables
sub substitue_variables {
	my ($received) = @_;
	
	# variables
	$received =~ s/(?:^|(?<=[^\\]))\$(\.?[a-z][a-z\d]*)/$eventMacro->is_var_defined($1) ? $eventMacro->get_var($1) : ''/gei;

	return $received;
}

sub parse_keywords {
	my @full = $_[0] =~ /@($macroKeywords)s*((s*(.*?)s*).*)$/i;
	my @pair = ($full[0]);
	my ($bracketed) = extract_bracketed ($full[1], '()');
	return unless $bracketed;
	push @pair, substr ($bracketed, 1, -1);

	return unless @pair;
	if ($pair[0] eq 'arg') {
		return $_[0] =~ /\@(arg)\s*\(\s*(".*?",\s*(\d+|\$[a-zA-Z][a-zA-Z\d]*))\s*\)/
	} elsif ($pair[0] eq 'random') {
		return $_[0] =~ /\@(random)\s*\(\s*(".*?")\s*\)/
	}
	while ($pair[1] =~ /\@($macroKeywords)\s*\(/) {
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

	# refresh global vars only once per command line
	refreshGlobal();
	
	while (($keyword, $inside_brackets) = parse_keywords($command)) {
		$result = "_%_";
		# first parse _then_ substitute. slower but safer
		$parsed = substitue_variables($inside_brackets) unless ($keyword eq 'nick');
		my $randomized = 0;

		if ($keyword eq 'npc') {
			$result = getnpcID($parsed);
			
		} elsif ($keyword eq 'cart') {
			$result = getItemIDs($parsed, $::cart{'inventory'});
			
		} elsif ($keyword eq 'Cart') {
			$result = join ',', getItemIDs($parsed, $::cart{'inventory'});
			
		} elsif ($keyword eq 'inventory') {
			$result = getInventoryIDs($parsed);
			
		} elsif ($keyword eq 'Inventory') {
			$result = join ',', getInventoryIDs($parsed);
			
		} elsif ($keyword eq 'store') {
			$result = getItemIDs($parsed, \@::storeList);
			
		} elsif ($keyword eq 'storage') {
			($result) = getStorageIDs($parsed);
			
		} elsif ($keyword eq 'Storage') {
			$result = join ',', getStorageIDs($parsed);
			
		} elsif ($keyword eq 'player') {
			$result = getPlayerID($parsed);
			
		} elsif ($keyword eq 'monster') {
			$result = getMonsterID($parsed);
			
		} elsif ($keyword eq 'vender') {
			$result = getVenderID($parsed);
			
		} elsif ($keyword eq 'venderitem') {
			($result) = getItemIDs($parsed, \@::venderItemList);
			
		} elsif ($keyword eq 'venderItem') {
			$result = join ',', getItemIDs($parsed, \@::venderItemList);
			
		} elsif ($keyword eq 'venderprice') {
			$result = getItemPrice($parsed, \@::venderItemList);
			
		} elsif ($keyword eq 'venderamount') {
			$result = getVendAmount($parsed, \@::venderItemList);
			
		} elsif ($keyword eq 'random') {
			$result = getRandom($parsed); $randomized = 1;
			
		} elsif ($keyword eq 'rand') {
			$result = getRandomRange($parsed); $randomized = 1;
			
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
			$parsed = substitue_variables($inside_brackets);
			$result = q4rx2($parsed);
		}
		
		return unless defined $result;
		return $command if ($result eq '_%_');
		
		$inside_brackets = q4rx($inside_brackets);
		
		unless ($randomized) {
			$command =~ s/\@$keyword\s*\(\s*$inside_brackets\s*\)/$result/g
		} else {
			$command =~ s/\@$keyword\s*\(\s*$inside_brackets\s*\)/$result/
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
			$parsed = substitue_variables($val);
			my $sub1 = $sub."(".$parsed.")";
			$result = eval($sub1);
			return unless defined $result;
			$val = q4rx $val;		
			$command =~ s/$sub\s*\(\s*$val\s*\)/$result/g
		}
	}

	$command = substitue_variables($command);
	return $command;
}

1;