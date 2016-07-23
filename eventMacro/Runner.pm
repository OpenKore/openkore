# $Id: Script.pm r6782 2009-07-24 16:36:00Z ezza $
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

our ($rev) = q$Revision: 6782 $ =~ /(\d+)/;

# constructor
sub new {
	my ($class, $name, $repeat, $lastname, $lastline, $interruptible, $overrideAI, $orphan, $delay, $macro_delay, $is_submacro) = @_;

	return undef unless ($eventMacro->{Macro_List}->getByName($name));
	
	my $self = bless {}, $class;
	
	$self->{Name} = $name;
	$self->{Paused} = 0;
	$self->{registered} = 0;
	$self->{mainline_delay} = undef;
	$self->{subline_delay} = undef;
	$self->{result} = undef;
	$self->{time} = time;
	$self->{finished} = 0;
	$self->{lines_array} = $eventMacro->{Macro_List}->getByName($name)->get_lines();
	$self->{line_number} = 0;
	$self->{label} = {scanLabels($self->{lines_array})};
	$self->{subcall} = undef;
	$self->{error} = undef;
	$self->{macro_block} = 0;
	
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
		$self->repeat(0);
	}
	
	if (defined $lastname && defined $lastline) {
		$self->{lastname} = $lastname;
		$self->{lastline} = $lastline
	} else {
		$self->{lastname} = undef;
		$self->{lastline} = undef;
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
	if (defined $overrideAI) {$self->{last_subcall_overrideAI} = $overrideAI}
	return $self->{last_subcall_overrideAI};
}
	
sub last_subcall_interruptible {
	my ($self, $interruptible) = @_;
	if (defined $interruptible) {$self->{last_subcall_interruptible} = $interruptible}
	return $self->{last_subcall_interruptible};
}
	
sub last_subcall_orphan {
	my ($self, $orphan) = @_;
	if (defined $orphan) {$self->{last_subcall_orphan} = $orphan}
	return $self->{last_subcall_orphan};
}

sub last_subcall_name {
	my ($self, $name) = @_;
	if (defined $name) {$self->{last_subcall_name} = $name}
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
	if (defined $timeout) {$self->{timeout} = $timeout}
	return { time => $self->{time}, timeout => $self->{timeout} };
}

# sets macro_delay timeout for this macro
sub macro_delay {
	my ($self, $macro_delay) = @_;
	if (defined $macro_delay) {$self->{macro_delay} = $macro_delay}
	return $self->{macro_delay};
}

# checks register status
sub registered {
	my ($self) = @_;
	return $self->{registered};
}

sub repeat {
	my ($self, $repeat) = @_;
	if (defined $repeat) {$self->{repeat} = $repeat}
	return $self->{repeat};
}

sub restart {
	my ($self) = @_;
	$self->repeat($self->repeat-1);
	$self->line_number(0);
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
	my ($self, $name, $repeat, $lastname, $lastline) = @_;
	debug "[eventMacro] Creating submacro '".$name."' on macro '".$self->{Name}."'.\n", "eventMacro", 2;
	$self->{subcall} = new eventMacro::Runner($name, $repeat, $lastname, $lastline, $self->interruptible, $self->overrideAI, $self->orphan, undef, $self->macro_delay, 1);
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

# returns and/or set the current line number
sub line_number {
	my ($self, $line_number) = @_;
	if (defined $line_number) {$self->{line_number} = $line_number}
	return $self->{line_number};
}

sub next_line {
	my ($self) = @_;
	$self->{line_number}++;
}

sub line_script {
	my ($self, $line_number) = @_;
	return @{$self->{lines_array}}[$line_number];
}

sub error {
	my ($self, $error) = @_;
	if (defined $error) {$self->{error} = $error}
	return $self->{error};
}

sub error_message {
	my ($self, $error) = @_;
	if (defined $error) {$self->{error_message} = "[eventMacro] Error in line '".$self->line_number."': '".$error."'.\n"}
	return $self->{error_message};
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

# processes next line
sub next {
	my $self = $_[0];
	
	#We must finish the sbucall before returning to this macro
	if (defined $self->{subcall}) {
		my $subcall_return = $self->{subcall}->next;
		if (defined $subcall_return) {
			my $subcall_timeout = $self->{subcall}->timeout;
			$self->timeout($subcall_timeout->{timeout});
			$self->{time} = $subcall_timeout->{time};
			if ($self->{subcall}->finished) {
				if ($self->{subcall}->repeat == 0) {$self->{finished} = 1}
				$self->clear_subcall;
			}
			return $subcall_return;
		} else {
			#if subcall->next returned undef an error was set
			$self->error($self->{subcall}->error);
			return;
		}
	}
	
	if (defined $self->{mainline_delay} && defined $self->{subline_delay}) {
		$self->line_number($self->{mainline_delay});
	}
	
	#get next line script
	my $current_line = $self->line_script($self->line_number);
	
	#TODO discover wtf does this do
	if (!defined $current_line) {
		if (defined $self->{lastname} && defined $self->{lastline}) {
			if ($self->repeat > 1) {
				$self->restart;
			} else {
				$self->line_number($self->{lastline} + 1);
				$self->{Name} = $self->{lastname};
				$self->{lines_array} = $eventMacro->{Macro_List}->getByName($self->{Name})->get_lines();
				($self->{lastline}, $self->{lastname}) = undef;
				$self->{finished} = 1;
			}
			$current_line = $self->line_script($self->line_number);
		} else {
			if ($self->repeat > 1) {
				$self->restart;
			} else {
				$self->{finished} = 1;
			}
			return "";
		}
	}
	
	# TODO: separate line advancing and timeout setting

	# "If" postfix control
	if ($current_line =~ /.+\s+if\s*\(.*\)$/) {
		my ($text) = $current_line =~ /.+\s+if\s*\(\s*(.*)\s*\)$/;
		$text = $self->parseCmd($text);
		return if (defined $self->error);
		my $savetxt = $self->particle($text);
		if ($self->multi($savetxt)) {
			$current_line =~ s/\s+if\s*\(.*\)$//;
		} else {
			$self->next_line;
			$self->timeout(0);
			return "";
		}
	}
	
	##########################################
	# jump to label: goto label
	if ($current_line =~ /^goto\s/) {
		my ($tmp) = $current_line =~ /^goto\s+([a-zA-Z][a-zA-Z\d]*)/;
		if (exists $self->{label}->{$tmp}) {
			$self->line_number($self->{label}->{$tmp});
		} else {
			$self->error("cannot find label $tmp");
			return;
		}
		$self->timeout(0);
	
	##########################################
	# declare block ending: end label
	} elsif ($current_line =~ /^end\s/) {
		my ($tmp) = $current_line =~ /^end\s+(.*)/;
		if (exists $self->{label}->{$tmp}) {
			$self->line_number($self->{label}->{$tmp});
		} else {
			$self->error("cannot find block start for $tmp");
			return;
		}
		$self->timeout(0);
		
	##########################################
	# macro block: begin
	} elsif ($current_line eq '[') {
		$self->{macro_block} = 1;
		$self->next_line;
		
	##########################################
	# macro block: end
	} elsif ($current_line eq ']') {
		$self->{macro_block} = 0;
		$self->timeout(0);
		$self->next_line;
	
	##########################################
	# if statement: if (foo = bar) goto label?
	# Unlimited If Statement by: ezza @ http://forums.openkore.com/
	} elsif ($current_line =~ /^if\s/) {
		my ($text, $then) = $current_line =~ /^if\s+\(\s*(.*)\s*\)\s+(goto\s+.*|call\s+.*|stop|{|)\s*/;

		# The main trick is parse all the @special keyword and vars 1st,
		$text = $self->parseCmd($text);
		return if (defined $self->error);
		my $savetxt = $self->particle($text);
		if ($self->multi($savetxt)) {
			$self->newThen($then);
			return if (defined $self->error);
		} elsif ($then eq "{") { # If the condition is false because "if" this is not using the command block
			my $countBlockIf = 1;
			while ($countBlockIf) {
				$self->next_line;
				my $searchEnd = $self->line_script($self->line_number);
				
				if ($searchEnd =~ /^if.*{$/) {
					$countBlockIf++;
				} elsif (($searchEnd eq '}') || ($searchEnd =~ /^}\s*else\s*{$/ && $countBlockIf == 1)) {
					$countBlockIf--;
				} elsif ($searchEnd =~ /^}\s*elsif\s+\(\s*(.*)\s*\).*{$/ && $countBlockIf == 1) {
					# If the condition of 'elsif' is true, the commands of your block will be executed,
					#  if false, will not run.
					$text = $self->parseCmd($1);
					return if (defined $self->error);
					$savetxt = $self->particle($text);
					if ($self->multi($savetxt)) {
						$countBlockIf--;
					}
				}
			}
		}
		$self->next_line;
		$self->timeout(0)

	##########################################
	# If arriving at a line 'else', 'elsif' or 'case', it should be skipped -
	#  it will never be activated if coming from a false 'if' or a previous 'case' has not been called
	} elsif ($current_line =~ /^}\s*else\s*{/ || $current_line =~ /^}\s*elsif.*{$/ || $current_line =~ /^case/ || $current_line =~ /^else/) {
		my $countCommandBlock = 1;
		while ($countCommandBlock) {
			$self->next_line;
			my $searchEnd = $self->line_script($self->line_number);
			
			if (isNewCommandBlock($searchEnd)) {
				$countCommandBlock++;
			} elsif ($searchEnd eq '}') {
				$countCommandBlock--;
			}
		}

		$self->timeout(0)

	##########################################
	# switch statement:
	} elsif ($current_line =~ /^switch.*{$/) {
		my ($firstPartCondition) = $current_line =~ /^switch\s*\(\s*(.*)\s*\)\s*{$/;

		my $countBlocks = 1;
		while ($countBlocks) {
			$self->next_line;
			my $searchNextCase = $self->line_script($self->line_number);
			
			if ($searchNextCase =~ /^else/) {
				my ($then) = $searchNextCase =~ /^else\s*(.*)/;
				$self->newThen($then);
				return if (defined $self->error);
				last;
			}
			
			my ($secondPartCondition, $then) = $searchNextCase =~ /^case\s*\(\s*(.*)\s*\)\s*(.*)/;
			next if (!$secondPartCondition);
			
			my $completCondition = $firstPartCondition . ' ' . $secondPartCondition;
			my $text = $self->parseCmd($completCondition);
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
					my $searchEnd = $self->line_script($self->line_number);
					
					if (isNewCommandBlock($searchEnd)) {
						$countCommandBlock++;
					} elsif ($searchEnd eq '}') {
						$countCommandBlock--;
					}
				}
			}
		}
		
		$self->next_line;
		$self->timeout(0)
	
	##########################################
	# end block of "if" or "switch"
	} elsif ($current_line eq '}') {
		$self->next_line;
		$self->timeout(0)

	##########################################
	# while statement: while (foo <= bar) as label
	} elsif ($current_line =~ /^while\s/) {
		my ($text, $label) = $current_line =~ /^while\s+\(\s*(.*)\s*\)\s+as\s+(.*)/;
		my $text = $self->parseCmd($text);
		return if (defined $self->error);
		my $savetxt = $self->particle($text);
		if (!$self->multi($savetxt)) {
			$self->line_number($self->{label}->{"end ".$label});
		}
		$self->next_line;
		$self->timeout(0)
	##########################################
	# set variable: $variable = value
	} elsif ($current_line =~ /^\$[a-z]/i) {
		my ($var, $val);
		if ($current_line =~ /;/) {
			$self->run_sublines($current_line);
			return if (defined $self->error);
		} else {
			if (($var, $val) = $current_line =~ /^\$([a-z][a-z\d]*?)\s+=\s+(.*)/i) {
				my $pval = $self->parseCmd($val);
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
			} elsif (($var, $val) = $current_line =~ /^\$([a-z][a-z\d]*?)([+-]{2})$/i) {
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
		$self->timeout(0) unless defined $self->{mainline_delay} && defined $self->{subline_delay};
		return $self->{result} if $self->{result}
		}
	##########################################
	# label definition: :label
	} elsif ($current_line =~ /^:/) {
		$self->next_line;
		$self->timeout(0)
	##########################################
	# returns command: do whatever
	} elsif ($current_line =~ /^do\s/) {
		if ($current_line =~ /;/ && $current_line =~ /^do eval/ eq "") {
			$self->run_sublines($current_line);
			return if (defined $self->error);
			unless (defined $self->{mainline_delay} && defined $self->{subline_delay}) {
				$self->timeout($self->macro_delay);
				$self->next_line;
			}
			if ($self->{result}) {
				return $self->{result};
			}
		} else {
			my ($tmp) = $current_line =~ /^do\s+(.*)/;
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
			my $result = $self->parseCmd($tmp);
			return if (defined $self->error);
			unless (defined $result) {
				$self->error("command $tmp failed");
				return;
			}
			$self->timeout($self->macro_delay);
			$self->next_line;
			return $result;
		}
	##########################################
	# log command
	} elsif ($current_line =~ /^log\s+/) {
		if ($current_line =~ /;/) {
			$self->run_sublines($current_line);
			return if (defined $self->error);
		} else {
			my ($tmp) = $current_line =~ /^log\s+(.*)/;
			my $result = $self->parseCmd($tmp);
			return if (defined $self->error);
			unless (defined $result) {
				$self->error = ("$tmp failed");
			} else {
				message "[eventmacro log] $result\n", "eventMacro";
			}
		}
		$self->next_line;
		$self->timeout($self->macro_delay) unless defined $self->{mainline_delay} && defined $self->{subline_delay};
		return $self->{result} if $self->{result}
	##########################################
	# pause command
	} elsif ($current_line =~ /^pause/) {
		if ($current_line =~ /;/) {
			$self->run_sublines($current_line);
			return if (defined $self->error);
			$self->timeout($self->macro_delay) unless defined $self->{mainline_delay} && defined $self->{subline_delay}
		}
		else {
			my ($tmp) = $current_line =~ /^pause\s*(.*)/;
			if (defined $tmp) {
				my $result = $self->parseCmd($tmp);
				return if (defined $self->error);
				unless (defined $result) {
					$self->error("$tmp failed");
				} else {
					$self->timeout($result);
				}
			} else {
				$self->timeout($self->macro_delay);
			}
		}
		$self->next_line;
		return $self->{result} if $self->{result}
	##########################################
	# stop command
	} elsif ($current_line eq "stop") {
		$self->{finished} = 1
	##########################################
	# release command
	} elsif ($current_line =~ /^release\s+/) {
		if ($current_line =~ /;/) {
			$self->run_sublines($current_line);
			return if (defined $self->error);
		} else {
			my ($tmp) = $current_line =~ /^release\s+(.*)/;
			my $automacro = $eventMacro->{Automacro_List}->getByName($self->parseCmd($tmp));
			if (!$automacro) {
				return if (defined $self->error);
				$self->error("releasing $tmp failed");
			} else {
				$automacro->enable();
			}
		}
		$self->next_line;
		$self->timeout(0) unless defined $self->{mainline_delay} && defined $self->{subline_delay};
		return $self->{result} if $self->{result}
	##########################################
	# lock command
	} elsif ($current_line =~ /^lock\s+/) {
		if ($current_line =~ /;/) {
			$self->run_sublines($current_line);
			return if (defined $self->error);
		} else {
			my ($tmp) = $current_line =~ /^lock\s+(.*)/;
			my $automacro = $eventMacro->{Automacro_List}->getByName($self->parseCmd($tmp));
			if (!$automacro) {
				return if (defined $self->error);
				$self->error("locking $tmp failed");
			} else {
				$automacro->disable();
			}
		}
		$self->next_line;
		$self->timeout(0) unless defined $self->{mainline_delay} && defined $self->{subline_delay};
		return $self->{result} if $self->{result}
	##########################################
	# call command
	} elsif ($current_line =~ /^call\s+/) {
		my ($tmp) = $current_line =~ /^call\s+(.*)/;
		my $name = $tmp;
		my $args;
		my $cparms;
		
		my $calltimes = 1;
		
		if ($tmp =~ /\s/) {
			($name, $args) = $tmp =~ /^(\S+?)\s+(.+)/;
			my ($times);
			if ($args =~ /(\d+)\s+(--.*)/) {
				($times, $cparms) = $args =~ /(\d+)?\s+?(--.*)?/;
				$times = $self->parseCmd($args);
				$cparms = $self->parseCmd($args);
			} elsif ($args =~ /^\d+/) {
				$times = $self->parseCmd($args);
			}  elsif ($args =~ /^--.*/) {
				$cparms = $self->parseCmd($args);
			}

			return if (defined $self->error);
			if (defined $times && $times =~ /\d+/) { $calltimes = $times; }; # do we have a valid repeat value?
		}
		
		$self->create_subcall($name, $calltimes, undef, undef);
		
		unless (defined $self->{subcall}) {
			$self->error("failed to call script");
		} else {
			my @new_params = substr($cparms, 2) =~ /"[^"]+"|\S+/g;
			foreach my $p (1..@new_params) {
				$eventMacro->set_var(".param".$p,$new_params[$p-1]);
				$eventMacro->set_var(".param".$p,substr($eventMacro->get_var(".param".$p), 1, -1)) if ($eventMacro->get_var(".param".$p) =~ /^".*"$/);
			}
			$self->next_line; # point to the next line to be executed in the caller
			$self->timeout($self->macro_delay);
		}
	##########################################
	# set command
	} elsif ($current_line =~ /^set\s+/) {
		if ($current_line =~ /;/) {
			$self->run_sublines($current_line);
			return if (defined $self->error);
		} else {
			my ($var, $val) = $current_line =~ /^set\s+(\w+)\s+(.*)$/;
			if ($var eq 'macro_delay' && $val =~ /^[\d\.]*\d+$/) {
				$self->macro_delay($val);
			} elsif ($var eq 'repeat' && $val =~ /^\d+$/) {
				$self->repeat($val);
			} elsif ($var eq 'overrideAI' && $val =~ /^[01]$/) {
				$self->overrideAI($val);
			} elsif ($var eq 'exclusive' && $val =~ /^[01]$/) {
				$self->interruptible($val?0:1);
			} elsif ($var eq 'orphan' && $val =~ /^(?:terminate|reregister(?:_safe)?)$/) {
				$self->orphan($val);
			} else {
				$self->error("unrecognized key or wrong value");
			}
		}
		$self->next_line;
		$self->timeout(0) unless defined $self->{mainline_delay} && defined $self->{subline_delay};
		return $self->{result} if $self->{result}
	##########################################
	# sub-routine command, still figuring out how to include unclever/fail sub-routine into the error msg
	} elsif ($current_line =~ /^(?:\w+)\s*\(.*?\)/) {
		if ($current_line =~ /;/) {
			$self->run_sublines($current_line);
		} else {
			$self->parseCmd($current_line);
		}
		return if (defined $self->error);
		$self->next_line;
		$self->timeout(0) unless defined $self->{mainline_delay} && defined $self->{subline_delay};
		return $self->{result} if $self->{result}
	##########################################
	# unrecognized line
	} else {
		$self->error("syntax error");
	}
	
	if (defined $self->error) {
		return;
	} else {
		return "";
	}
}


sub run_sublines {
	my ($self, $real_line) = @_;
	my ($i, $real_num, @sub_line) = (0, $self->{line_number}, undef);
	my @split = split(/\s*;\s*/, $real_line);
	my ($dvar, $var, $val, $list);
	
	foreach my $e (@split) {
		next if $e eq "";
		if (defined $self->{subline_delay} && $i < $self->{subline_delay}) {
			$i++;
			next;
		}
		if (defined $self->{subline_delay} && $i == $self->{subline_delay}) {
			$self->timeout(0);
			($self->{mainline_delay}, $self->{subline_delay}, $self->{result}) = undef;
			$i++;
			next;
		}
		

		# set variable: $variable = value
		if ($e =~ /^\$[a-z]/i) {
			if (($var, $val) = $e =~ /^\$([a-z][a-z\d]*?)\s+=\s+(.*)/i) {
				my $pval = $self->parseCmd($val);
				if (defined $self->error) {
					$self->error("Error in line $real_num: $real_line\n[macro] $self->{Name} error in sub-line $i: ".$self->error);
					last;
				}
				if (defined $pval) {
					if ($pval =~ /^\s*(?:undef|unset)\s*$/i && $eventMacro->exists_var($var)) {
						$eventMacro->set_var($var, 'undef')
					} else {
						$eventMacro->set_var($var,$pval)
					}
				} else {
					$self->error("Error in line $real_num: $real_line\n[macro] $self->{Name} error in sub-line $i: $e failed");
					last;
				}
			} elsif (($var, $val) = $e =~ /^\$([a-z][a-z\d]*?)([+-]{2})$/i) {
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
				$self->error("Error in line $real_num: $real_line\n[macro] $self->{Name} error in sub-line $i: unrecognized assignment in ($e)");
				last;
			}
			$i++;
			next;
		# stop command
		} elsif ($e eq "stop") {
			$self->{finished} = 1;
			last;
		
		# set command
		} elsif (($var, $val) = $e =~ /^set\s+(\w+)\s+(.*)$/) {
			if ($var eq 'macro_delay' && $val =~ /^[\d\.]*\d+$/) {
				$self->macro_delay($val);
			} elsif ($var eq 'repeat' && $val =~ /^\d+$/) {
				$self->repeat($val);
			} elsif ($var eq 'overrideAI' && $val =~ /^[01]$/) {
				$self->overrideAI($val);
			} elsif ($var eq 'exclusive' && $val =~ /^[01]$/) {
				$self->interruptible($val)?0:1;
			} elsif ($var eq 'orphan' && $val =~ /^(?:terminate(?:_last_call)?|reregister(?:_safe)?)$/) {
				$self->orphan($val);
			} else {
				$self->error("Error in line $real_num: $real_line\n[macro] $self->{Name} error in sub-line $i: unrecognized key or wrong value in ($e)");
				last;
			}
				
		# lock command
		} elsif ($e =~ /^lock\s+/) {
			my ($tmp) = $e =~ /^lock\s+(.*)/;
			my $automacro = $eventMacro->{Automacro_List}->getByName($self->parseCmd($tmp));
			if (!$automacro) {
				if (defined $self->error) {
					$self->error("Error in line $real_num: $real_line\n[macro] $self->{Name} error in sub-line $i: ".$self->error);
					last;
				}
				$self->error("Error in line $real_num: $real_line\n[macro] $self->{Name} error in sub-line $i: locking $tmp failed in ($e)");
				last;
			} else {
				$automacro->disable();
			}
			
				
		# release command
		} elsif ($e =~ /^release\s+/) {
			my ($tmp) = $e =~ /^release\s+(.*)/;
			my $automacro = $eventMacro->{Automacro_List}->getByName($self->parseCmd($tmp));
			if (!$automacro) {
				if (defined $self->error) {
					$self->error("Error in line $real_num: $real_line\n[macro] $self->{Name} error in sub-line $i: ".$self->error);
					last;
				}
				$self->error("Error in line $real_num: $real_line\n[macro] $self->{Name} error in sub-line $i: releasing $tmp failed in ($e)");
				last;
			} else {
				$automacro->enable();
			}
		
		# pause command
		} elsif ($e =~ /^pause/) {
			my ($tmp) = $e =~ /^pause\s*(.*)/;
			if (defined $tmp) {
				my $result = $self->parseCmd($tmp);
				if (defined $self->error) {
					$self->error("Error in line $real_num: $real_line\n[macro] $self->{Name} error in sub-line $i: ".$self->error);
					last;
				}
				unless (defined $result) {
					$self->error("Error in line $real_num: $real_line\n[macro] $self->{Name} error in sub-line $i: $tmp failed in ($e)");
					last;
				} else {
					$self->timeout($result);
				}
			} else {
				$self->timeout($self->macro_delay);
			}
			$self->{mainline_delay} = $real_num;
			$self->{subline_delay} = $i;
			last;
		
		# log command
		} elsif ($e =~ /^log\s+/) {
			my ($tmp) = $e =~ /^log\s+(.*)/;
			my $result = $self->parseCmd($tmp);
			if (defined $self->error) {
				$self->error("Error in line $real_num: $real_line\n[macro] $self->{Name} error in sub-line $i:".$self->error);
				last;
			}
			unless (defined $result) {
				$self->error("Error in line $real_num: $real_line\n[macro] $self->{Name} error in sub-line $i: $tmp failed in ($e)");
				last;
			} else {
				message "[eventMacro log] $result\n", "eventMacro"
			}
			$self->timeout($self->macro_delay);
			$self->{mainline_delay} = $real_num;
			$self->{subline_delay} = $i;
			last
		}
		
		# do command
		elsif ($e =~ /^do\s/) {
			my ($tmp) = $e =~ /^do\s+(.*)/;
			if ($tmp =~ /^macro\s+/) {
				my ($arg) = $tmp =~ /^macro\s+(.*)/;
				if ($arg =~ /^reset/) {
					$self->error("Error in line $real_num: $real_line\n[macro] $self->{Name} error in sub-line $i: use 'release' instead of 'macro reset'")
				} elsif ($arg eq 'pause' || $arg eq 'resume') {
					$self->error("Error in line $real_num: $real_line\n[macro] $self->{Name} error in sub-line $i: do not use 'macro pause' or 'macro resume' within a macro")
				} elsif ($arg =~ /^set\s/) {
					$self->error("Error in line $real_num: $real_line\n[macro] $self->{Name} error in sub-line $i: do not use 'macro set'. Use \$foo = bar")
				} elsif ($arg eq 'stop') {
					$self->error("Error in line $real_num: $real_line\n[macro] $self->{Name} error in sub-line $i: use 'stop' instead")
				} elsif ($arg !~ /^(?:list|status)$/) {
					$self->error("Error in line $real_num: $real_line\n[macro] $self->{Name} error in sub-line $i: use 'call $arg' instead of 'macro $arg'")
				}
			} elsif ($tmp =~ /^eval\s+/) {
				$self->error("Error in line $real_num: $real_line\n[macro] $self->{Name} error in sub-line $i: do not mix eval in the sub-line")
			} elsif ($tmp =~ /^ai\s+clear$/) {
				$self->error("Error in line $real_num: $real_line\n[macro] $self->{Name} error in sub-line $i: do not mess around with ai in macros")
			}
			my $result = $self->parseCmd($tmp);
			if (defined $self->error) {
				$self->error("Error in line $real_num: $real_line\n[macro] $self->{Name} error in sub-line $i: ".$self->error);
				last;
			}
			unless (defined $result) {
				$self->error("Error in line $real_num: $real_line\n[macro] $self->{Name} error in sub-line $i: command $tmp failed");
				last;
			}
			$self->timeout($self->macro_delay);
			$self->{mainline_delay} = $real_num;
			$self->{subline_delay} = $i;
			$self->{result} = $result;
			last
							
		# "call", "[", "]", ":", "if", "while", "end" and "goto" commands block
		} elsif ($e =~ /^(?:call|\[|\]|:|if|end|goto|while)\s*/i) {
			$self->error("Line $real_num sub-line $i\n[Reason:] Use saperate line for HERE --> $e <-- HERE");
			last
		# sub-routine
		} elsif (my ($sub) = $e =~ /^(\w+)\s*\(.*?\)$/) {
			$self->parseCmd($e);
			$self->error("Error in line $real_num: $real_line\n[macro] $self->{Name} error in sub-line $i: ".$self->error) if defined $self->error;
			last;
		
		##################### End ##################
		} else {
			message "Error in $self->{line_number}: $real_line\nWarning: Ignoring Unknown Command in sub-line $i: ($e)\n", "menu";
		}
		$i++
	}
}

sub newThen {
	my ($self, $then) = @_;

	if ($then =~ /^goto\s/) {
		my ($tmp) = $then =~ /^goto\s+([a-zA-Z][a-zA-Z\d]*)$/;
		if (exists $self->{label}->{$tmp}) {
			$self->{line_number} = $self->{label}->{$tmp}
		} else {
			$self->error("cannot find label $tmp");
		}
	} elsif ($then =~ /^call\s+/) {
		my ($tmp) = $then =~ /^call\s+(.*)/;
		if ($tmp =~ /\s/) {
			my ($name, $times) = $tmp =~ /(.*?)\s+(.*)/;
			my $ptimes = $self->parseCmd($times);
			return if (defined $self->error);
			if (defined $ptimes && $ptimes =~ /^\d+$/) {
				if ($ptimes > 0) {
					$self->create_subcall($name, $ptimes, $self->{Name}, $self->{line_number});
				} else {
					$self->create_subcall($name, 0, undef, undef);
				}
			} else {
				$self->error("$ptimes must be numeric");
			}
		} else {
			$self->create_subcall($tmp, 1, undef, undef);
		}
		unless (defined $self->{subcall}) {
			$self->error("failed to call script");
		} else {
			$self->timeout($self->macro_delay);
		}
	} elsif ($then eq "stop") {
		$self->{finished} = 1;
	}
}


sub statement {
	my ($self, $temp_multi) = @_;
	my ($first, $cond, $last) = $temp_multi =~ /^\s*"?(.*?)"?\s+([<>=!~]+?)\s+"?(.*?)"?\s*$/;
	if (!defined $first || !defined $cond || !defined $last) {
		$self->error("syntax error in if statement");
	} else {
		my $pfirst = $self->parseCmd(refined_macroKeywords($first));
		my $plast = $self->parseCmd(refined_macroKeywords($last));
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

	$self->error("You probably missed 1 or more closing round-\nbracket ')' in the statement.") if !defined $last;

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

	$pair[1] = parseCmd($pair[1]);
	my $new = "@".$pair[0]."(".$pair[1].")";	#sorry! cheap code ;p
	return $new
}

sub bracket {
	# Scans $text for @special keywords

	my ($text, $dbg) = @_;
	my @brkt; my $i = 0;

	while ($text =~ /(\@)?($macroKeywords)?\s*\(\s*([^\)]+)\s*/g) {
		my ($first, $second, $third) = ($1, $2, $3);
		unless (defined $first && defined $second && !bracket($third, 1)) {
			message "Bracket Detected: $text <-- HERE\n", "menu" if $dbg;
			$brkt[$i] = 1
		}
		else {$brkt[$i] = 0}
		$i++
	}

	foreach my $e (@brkt) {
		if ($e == 1) {return 1}
	}

	return 0
}

sub parseKw {
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
		@pair = parseKw ($pair[1])
	}
	return @pair
}

# parses all macro perl sub-routine found in the macro script
sub parseSub {
	#Taken from sub parseKw :D
	my @full = $_[0] =~ /(?:^|\s+)(\w+)s*((s*(.*?)s*).*)$/i;
	my @pair = ($full[0]);
	my ($bracketed) = extract_bracketed ($full[1], '()');
	return unless $bracketed;
	push @pair, substr ($bracketed, 1, -1);

	return unless @pair;

	while ($pair[1] =~ /(?:^|\s+)(\w+)\s*\(/) {
		@pair = parseSub ($pair[1])
	}

	return @pair
}

# substitute variables
sub subvars {
# should be working now
	my ($pre, $nick) = @_;
	my ($var, $tmp);
	
	# variables
	$pre =~ s/(?:^|(?<=[^\\]))\$(\.?[a-z][a-z\d]*)/$eventMacro->is_var_defined($1) ? $eventMacro->get_var($1) : ''/gei;
	
	# doublevars
	$pre =~ s/\$\{(.*?)\}/$eventMacro->is_var_defined("#$1") ? $eventMacro->get_var("#$1") : ''/gei;

	return $pre
}

# command line parser for macro
# returns undef if something went wrong, else the parsed command or "".
sub parseCmd {
	my ($self, $cmd) = @_;
	return "" unless defined $cmd;
	my ($kw, $arg, $targ, $ret, $sub, $val);

	# refresh global vars only once per command line
	refreshGlobal();
	
	while (($kw, $targ) = parseKw($cmd)) {
		$ret = "_%_";
		# first parse _then_ substitute. slower but more safe
		$arg = subvars($targ) unless $kw eq 'nick';
		my $randomized = 0;

		if ($kw eq 'npc')           {$ret = getnpcID($arg)}
		elsif ($kw eq 'cart')       {($ret) = getItemIDs($arg, $::cart{'inventory'})}
		elsif ($kw eq 'Cart')       {$ret = join ',', getItemIDs($arg, $::cart{'inventory'})}
		elsif ($kw eq 'inventory')  {($ret) = getInventoryIDs($arg)}
		elsif ($kw eq 'Inventory')  {$ret = join ',', getInventoryIDs($arg)}
		elsif ($kw eq 'store')      {($ret) = getItemIDs($arg, \@::storeList)}
		elsif ($kw eq 'storage')    {($ret) = getStorageIDs($arg)}
		elsif ($kw eq 'Storage')    {$ret = join ',', getStorageIDs($arg)}
		elsif ($kw eq 'player')     {$ret = getPlayerID($arg)}
		elsif ($kw eq 'monster')    {$ret = getMonsterID($arg)}
		elsif ($kw eq 'vender')     {$ret = getVenderID($arg)}
		elsif ($kw eq 'venderitem') {($ret) = getItemIDs($arg, \@::venderItemList)}
		elsif ($kw eq 'venderItem') {$ret = join ',', getItemIDs($arg, \@::venderItemList)}
		elsif ($kw eq 'venderprice'){$ret = getItemPrice($arg, \@::venderItemList)}
		elsif ($kw eq 'venderamount'){$ret = getVendAmount($arg, \@::venderItemList)}
		elsif ($kw eq 'random')     {$ret = getRandom($arg); $randomized = 1}
		elsif ($kw eq 'rand')       {$ret = getRandomRange($arg); $randomized = 1}
		elsif ($kw eq 'invamount')  {$ret = getInventoryAmount($arg)}
		elsif ($kw eq 'cartamount') {$ret = getCartAmount($arg)}
		elsif ($kw eq 'shopamount') {$ret = getShopAmount($arg)}
		elsif ($kw eq 'storamount') {$ret = getStorageAmount($arg)}
		elsif ($kw eq 'config')     {$ret = getConfig($arg)}
		elsif ($kw eq 'arg')        {$ret = getWord($arg)}
		elsif ($kw eq 'eval')       {$ret = eval($arg) unless $Settings::lockdown}
		elsif ($kw eq 'listitem')   {$ret = getArgFromList($arg)}
		elsif ($kw eq 'listlength') {$ret = getListLenght($arg)}
		elsif ($kw eq 'nick')       {$arg = subvars($targ, 1); $ret = q4rx2($arg)}
		return unless defined $ret;
		return $cmd if $ret eq '_%_';
		$targ = q4rx $targ;
		unless ($randomized) {
			$cmd =~ s/\@$kw\s*\(\s*$targ\s*\)/$ret/g
		} else {
			$cmd =~ s/\@$kw\s*\(\s*$targ\s*\)/$ret/
		}
	}
	
	unless ($Settings::lockdown) {
		# any round bracket(pair) found after parseKw sub-routine were treated as macro perl sub-routine
		undef $ret; undef $arg;
		while (($sub, $val) = parseSub($cmd)) {
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
			$arg = subvars($val);
			my $sub1 = $sub."(".$arg.")";
			$ret = eval($sub1);
			return unless defined $ret;
			$val = q4rx $val;		
			$cmd =~ s/$sub\s*\(\s*$val\s*\)/$ret/g
		}
	}

	$cmd = subvars($cmd);
	return $cmd
}

1;