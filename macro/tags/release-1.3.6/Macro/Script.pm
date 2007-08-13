package Macro::Script;

use strict;

require Exporter;
our @ISA = qw(Exporter);

use Utils;
use Globals;
use AI;
use Macro::Data;
use Macro::Parser qw(parseCmd);
use Macro::Utilities qw(setVar getVar cmpr);
use Macro::Automacro qw(releaseAM lockAM);
use Log qw(message);
our $Changed = sprintf("%s %s %s",
	q$Date$
	=~ /(\d{4}-\d{2}-\d{2}) (\d{2}:\d{2}:\d{2}) ([+-]\d{4})/);
      
# constructor
sub new {
	my ($class, $name, $repeat) = @_;
	$repeat = 0 unless ($repeat && $repeat =~ /^\d+$/);
	return unless defined $macro{$name};
	my $self = {
		name => $name,
		registered => 0,
		submacro => 0,
		macro_delay => $timeout{macro_delay}{timeout},
		timeout => 0,
		time => time,
		finished => 0,
		overrideAI => 0,
		line => 0,
		label => {scanLabels($macro{$name})},
		repeat => $repeat,
		subcall => undef,
		error => undef,
		orphan => $::config{macro_orphans},
		interruptible => 1,
		macro_block => 0
	};
	bless ($self, $class);
	return $self
}

# destructor
sub DESTROY {
	my $self = shift;
	AI::clear('macro') if (AI::inQueue('macro') && !$self->{submacro})
}

# declares current macro to be a submacro
sub regSubmacro {
	my $self = shift;
	$self->{submacro} = 1
}

# registers to AI queue
sub register {
	my $self = shift;
	AI::queue('macro') unless $self->{overrideAI};
	$self->{registered} = 1
}

# checks register status
sub registered {
	my $self = shift;
	return $self->{registered}
}

# sets or gets method for orphaned macros
sub orphan {
	my ($self, $method) = @_;
	if (defined $method) {$self->{orphan} = $method}
	return $self->{orphan}
}

# sets repeat
sub setRepeat {
	my $self = shift;
	$self->{repeat} = shift
}

# sets macro_delay timeout for this macro
sub setMacro_delay {
	my $self = shift;
	$self->{macro_delay} = shift
}

# sets or gets timeout for next command
sub timeout {
	my ($self, $timeout) = @_;
	if (defined $timeout) {$self->{timeout} = $timeout}
	return (time => $self->{time}, timeout => $self->{timeout})
}

# sets or gets override AI value
sub overrideAI {
	my ($self, $flag) = @_;
	if (defined $flag) {$self->{overrideAI} = $flag}
	return $self->{overrideAI}
}

# sets or get interruptible flag
sub interruptible {
	my ($self, $flag) = @_;
	if (defined $flag) {$self->{interruptible} = $flag}
	return $self->{interruptible}
}

# sets or gets macro block flag
sub macro_block {
	my ($self, $flag) = @_;
	if (defined $flag) {$self->{macro_block} = $flag}
	return $self->{macro_block}
}

# returns whether or not the macro finished
sub finished {
	my $self = shift;
	return $self->{finished}
}

# returns the name of the current macro
sub name {
	my $self = shift;
	return $self->{name}
}

# returns the current line number
sub line {
	my $self = shift;
	return $self->{line}
}

# returns the error line
sub error {
	my $self = shift;
	return $self->{error}
}

# re-sets the timer
sub ok {
	my $self = shift;
	$self->{time} = time
}

# scans the script for labels
sub scanLabels {
	my $script = shift;
	my %labels;
	for (my $line = 0; $line < @{$script}; $line++) {
		if (${$script}[$line] =~ /^:/) {
			my ($label) = ${$script}[$line] =~ /^:(.*)$/;
			$labels{$label} = $line
		}
		if (${$script}[$line] =~ /^while\s+/) {
			my ($label) = ${$script}[$line] =~ /\s+as\s+(.*)$/;
			$labels{$label} = $line
		}
		if (${$script}[$line] =~ /^end\s+/) {
			my ($label) = ${$script}[$line] =~ /^end\s+(.*)$/;
			$labels{"end ".$label} = $line
		}
	}
	return %labels
}

# processes next line
sub next {
	my $self = shift;
	if (defined $self->{subcall}) {
		my $command = $self->{subcall}->next;
		if (defined $command) {
			my %tmptime = $self->{subcall}->timeout;
			$self->{timeout} = $tmptime{timeout};
			$self->{time} = $tmptime{time};
			if ($self->{subcall}->finished) {
				undef $self->{subcall};
				$self->{line}++
			}
			return $command
		}
		$self->{error} = $self->{subcall}->{error};
		return
	}

	my $line = ${$macro{$self->{name}}}[$self->{line}];
	if (!defined $line) {
		if ($self->{repeat} > 1) {
			$self->{repeat}--;
			$self->{line} = 0
		} else {
			$self->{finished} = 1
		}
		return ""
	}

	my $errtpl = "error in ".$self->{line};
	##########################################
	# jump to label: goto label
	if ($line =~ /^goto\s/) {
		my ($tmp) = $line =~ /^goto\s+([a-zA-Z][a-zA-Z\d]*)/;
		if (exists $self->{label}->{$tmp}) {
			$self->{line} = $self->{label}->{$tmp}
		} else {
			$self->{error} = "$errtpl: cannot find label $tmp"
		}
		$self->{timeout} = 0
	##########################################
	# declare block ending: end label
	} elsif ($line =~ /^end\s/) {
		my ($tmp) = $line =~ /^end\s+(.*)/;
		if (exists $self->{label}->{$tmp}) {
			$self->{line} = $self->{label}->{$tmp}
		} else {
			$self->{error} = "$errtpl: cannot find block start for $tmp"
		}
		$self->{timeout} = 0
	##########################################
	# macro block: begin
	} elsif ($line eq '[') {
		$self->{macro_block} = 1;
		$self->{line}++
	##########################################
	# macro block: end
	} elsif ($line eq ']') {
		$self->{macro_block} = 0;
		$self->{timeout} = 0;
		$self->{line}++
	##########################################
	# if statement: if (foo = bar) goto label?
	} elsif ($line =~ /^if\s/) {
		my ($first, $cond, $last, $then) = $line =~ /^if\s+\(\s*"?(.*?)"?\s+([<>=!~]+?)\s+"?(.*?)"?\s*\)\s+(.*?)$/;
		if (!defined $first || !defined $cond || !defined $last || !defined $then || $then !~ /^(goto\s|stop)/) {
			$self->{error} = "$errtpl: syntax error in if statement"
		} else {
			my $pfirst = parseCmd($first); my $plast = parseCmd($last);
			unless (defined $pfirst && defined $plast) {
				$self->{error} = "$errtpl: either '$first' or '$last' has failed"
			} elsif (cmpr($pfirst, $cond, $plast)) {
				if ($then =~ /^goto\s/) {
					my ($tmp) = $then =~ /^goto\s+([a-zA-Z][a-zA-Z\d]*)$/;
					if (exists $self->{label}->{$tmp}) {
						$self->{line} = $self->{label}->{$tmp}
					} else {
						$self->{error} = "$errtpl: cannot find label $tmp"
					}
				} elsif ($then =~ /^stop$/) {
					$self->{finished} = 1
				}
			} else {
				$self->{line}++
			}
		}
		$self->{timeout} = 0
	##########################################
	# while statement: while (foo <= bar) as label
	} elsif ($line =~ /^while\s/) {
		my ($first, $cond, $last, $label) = $line =~ /^while\s+\(\s*"?(.*?)"?\s+([<>=!]+?)\s+"?(.*?)"?\s*\)\s+as\s+(.*)$/;
		if (!defined $first || !defined $cond || !defined $last || !defined $label) {
			$self->{error} = "$errtpl: syntax error in while statement"
		} else {
			my $pfirst = parseCmd($first); my $plast = parseCmd($last);
			unless (defined $pfirst && defined $plast) {
				$self->{error} = "$errtpl: either '$first' or '$last' has failed"
			} elsif (!cmpr($pfirst, $cond, $plast)) {
				$self->{line} = $self->{label}->{"end ".$label}
			}
			$self->{line}++
		}
		$self->{timeout} = 0
	##########################################
	# pop value from variable: $var = [$list]
	} elsif ($line =~ /^\$[a-z][a-z\d]*\s+=\s+\[\s*\$[a-z][a-z\d]*\s*\]$/i) {
		my ($var, $list) = $line =~ /^\$([a-z][a-z\d]*?)\s+=\s+\[\s*\$([a-z][a-z\d]*?)\s*\]$/i;
		my $listitems = (getVar($list) or "");
		my $val;
		if (($val) = $listitems =~ /^(.*?)(,|$)/) {
			$listitems =~ s/^(.*?)(,|$)//;
			setVar($list, $listitems)
		} else {
			$val = $listitems
		}
		setVar($var, $val);
		$self->{line}++;
		$self->{timeout} = 0;
	##########################################
	# set variable: $variable = value
	} elsif ($line =~ /^\$[a-z]/i) {
		my ($var, $val);
		if (($var, $val) = $line =~ /^\$([a-z][a-z\d]*?)\s+=\s+(.*)$/i) {
			my $pval = parseCmd($val);
			if (defined $pval) {setVar($var, $pval)}
			else {$self->{error} = "$errtpl: $val failed"}
		} elsif (($var, $val) = $line =~ /^\$([a-z][a-z\d]*?)([+-]{2})$/i) {
			if ($val eq '++') {setVar($var, (getVar($var) or 0)+1)}
			else {setVar($var, (getVar($var) or 0)-1)}
		} else {
			$self->{error} = "$errtpl: unrecognized assignment"
		}
		$self->{line}++;
		$self->{timeout} = 0
	##########################################
	# set doublevar: ${$variable} = value
	} elsif ($line =~ /^\$\{\$[.a-z]/i) {
		my ($dvar, $val);
		if (($dvar, $val) = $line =~ /^\$\{\$([.a-z][a-z\d]*?)\}\s+=\s+(.*)$/i) {
			my $var = getVar($dvar);
			unless (defined $var) {
				$self->{error} = "$errtpl: $dvar not defined"
			} else {
				my $pval = parseCmd($val);
				unless (defined $pval) {
					$self->{error} = "$errtpl: $val failed"
				} else {
					setVar("#".$var, parseCmd($val))
				}
			}
		} elsif (($dvar, $val) = $line =~ /^\$\{\$([.a-z][a-z\d]*?)\}([+-]{2})$/i) {
			my $var = getVar($dvar);
			unless (defined $var) {
				$self->{error} = "$errtpl: $dvar undefined"
			} else {
				if ($val eq '++') {setVar("#".$var, (getVar("#".$var) or 0)+1)}
				else {setVar("#".$var, (getVar("#".$var) or 0)-1)}
			}
		} else {
			$self->{error} = "$errtpl: unrecognized assignment."
		}
		$self->{line}++;
		$self->{timeout} = 0
	##########################################
	# label definition: :label
	} elsif ($line =~ /^:/) {
		$self->{line}++;
		$self->{timeout} = 0
	##########################################
	# returns command: do whatever
	} elsif ($line =~ /^do\s/) {
		my ($tmp) = $line =~ /^do\s+(.*)/;
		if ($tmp =~ /^macro\s+/) {
			my ($arg) = $tmp =~ /^macro\s+(.*)/;
			if ($arg =~ /^reset/) {
				$self->{error} = "$errtpl: use 'release' instead of 'macro reset'"
			} elsif ($arg eq 'pause' || $arg eq 'resume') {
				$self->{error} = "$errtpl: do not use 'macro pause' or 'macro resume' within a macro"
			} elsif ($arg =~ /^set\s/) {
				$self->{error} = "$errtpl: do not use 'macro set'. Use \$foo = bar"
			} elsif ($arg eq 'stop') {
				$self->{error} = "$errtpl: use 'stop' instead"
			} elsif ($arg !~ /^(list|status)$/) {
				$self->{error} = "$errtpl: use 'call $arg' instead of 'macro $arg'"
			}
		} elsif ($tmp =~ /^ai\s+clear$/) {
			$self->{error} = "$errtpl: do not mess around with ai in macros"
		}
		return if defined $self->{error};
		my $result = parseCmd($tmp);
		unless (defined $result) {
			$self->{error} = "$errtpl: command $tmp failed";
			return
		}
		$self->{line}++;
		$self->{timeout} = $self->{macro_delay};
		return $result
	##########################################
	# log command
	} elsif ($line =~ /^log\s+/) {
		my ($tmp) = $line =~ /^log\s+(.*)/;
		my $result = parseCmd($tmp);
		unless (defined $result) {
			$self->{error} = "$errtpl: $tmp failed"
		} else {
			message "[macro][log] $result\n", "macro";
		}
		$self->{line}++;
		$self->{timeout} = $self->{macro_delay}
	##########################################
	# pause command
	} elsif ($line =~ /^pause/) {
		my ($tmp) = $line =~ /^pause\s*(.*)/;
		if (defined $tmp) {
			my $result = parseCmd($tmp);
			unless (defined $result) {
				$self->{error} = "$errtpl: $tmp failed"
			} else {
				$self->{timeout} = $result
			}
		} else {
			$self->{timeout} = $self->{macro_delay}
		}
		$self->{line}++
	##########################################
	# stop command
	} elsif ($line =~ /^stop$/) {
		$self->{finished} = 1
	##########################################
	# release command
	} elsif ($line =~ /^release\s+/) {
		my ($tmp) = $line =~ /^release\s+(.*)/;
		if (!releaseAM(parseCmd($tmp))) {
			$self->{error} = "$errtpl: releasing $tmp failed"
		}
		$self->{line}++;
		$self->{timeout} = 0
	##########################################
	# lock command
	} elsif ($line =~ /^lock\s+/) {
		my ($tmp) = $line =~ /^lock\s+(.*)/;
		if (!lockAM(parseCmd($tmp))) {
			$self->{error} = "$errtpl: locking $tmp failed"
		}
		$self->{line}++;
		$self->{timeout} = 0
	##########################################
	# call command
	} elsif ($line =~ /^call\s+/) {
		my ($tmp) = $line =~ /^call\s+(.*)/;
		if ($tmp =~ /\s/) {
			my ($name, $times) = $tmp =~ /(.*?)\s+(.*)/;
			my $ptimes = parseCmd($times);
			if (defined $ptimes) {
				$self->{subcall} = new Macro::Script($name, $ptimes)
			}
		} else {
			$self->{subcall} = new Macro::Script($tmp)
		}
		unless (defined $self->{subcall}) {
			$self->{error} = "$errtpl: failed to call script"
		} else {
			$self->{subcall}->regSubmacro;
			$self->{timeout} = $self->{macro_delay}
		}
	##########################################
	# set command
	} elsif ($line =~ /^set\s+/) {
		my ($var, $val) = $line =~ /^set\s+(\w+)\s+(.*)$/;
		if ($var eq 'macro_delay' && $val =~ /^[\d\.]*\d+$/) {
			$self->{macro_delay} = $val
		} elsif ($var eq 'repeat' && $val =~ /^\d+$/) {
			$self->{repeat} = $val
		} elsif ($var eq 'overrideAI' && $val =~ /^[01]$/) {
			$self->{overrideAI} = $val
		} elsif ($var eq 'exclusive' && $val =~ /^[01]$/) {
			$self->{interruptible} = $val?0:1
		} elsif ($var eq 'orphan' && $val =~ /^(terminate|reregister|reregister_safe)$/) {
			$self->{orphan} = $val
		} else {
			$self->{error} = "$errtpl: unrecognized key or wrong value"
		}
		$self->{line}++;
		$self->{timeout} = 0
	##########################################
	# unrecognized line
	} else {
		$self->{error} = "$errtpl: syntax error"
	}
	if (defined $self->{error}) {return} else {return ""}
}

1;
