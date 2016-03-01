# $Header$

package Macro::Script;

use strict;
use warnings;

require Exporter;
our @ISA = qw(Exporter);

use Utils;
use Globals;
use AI;
use Macro::Data;
use Macro::Parser qw(parseCmd);
use Macro::Utilities qw(setVar getVar cmpr);
use Macro::Automacro qw(releaseAM);
use Log qw(message);
our $Version = sprintf("%d.%02d", q$Revision: 3502 $ =~ /(\d+)\.(\d+)/);

# constructor
sub new {
  my ($class, $name, $repeat) = @_;
  $repeat = 0 unless defined $repeat;
  return unless defined $macro{$name};
  my $self = {
    name => $name,
    script => [@{$macro{$name}}],
    timeout => $timeout{macro_delay}{timeout},
    time => time,
    finished => 0,
    overrideAI => 0,
    line => 0,
    label => {scanLabels($macro{$name})},
    repeat => $repeat,
    subcall => undef,
    error => undef
  };
  AI::queue('macro');
  bless ($self, $class);
  return $self;
}

# destructor
sub DESTROY {
  AI::dequeue() if AI::is('macro');
}

# sets repeat
sub setRepeat {
  my $self = shift;
  $self->{repeat} = shift;
}

# for debugging purposes
sub printLabels {
  my $self = shift;
  foreach my $k (keys %{$self->{label}}) {
    $cvs->debug(sprintf("%s->%s", $k, ${$self->{label}}{$k}), $logfac{developers});
  }
}

# sets timeout for next command
sub setTimeout {
  my $self = shift;
  $self->{timeout} = shift;
}

# gets timeout for next command
sub timeout {
  my $self = shift;
  my %tmp = (time => $self->{time}, timeout => $self->{timeout});
  return %tmp;
}

# sets override AI
sub setOverrideAI {
  my $self = shift;
  $self->{overrideAI} = 1;
}

# gets override AI value
sub overrideAI {
  my $self = shift;
  return $self->{overrideAI};
}

# returns whether or not the macro finished
sub finished {
  my $self = shift;
  return $self->{finished};
}

# returns the name of the current macro
sub name {
  my $self = shift;
  return $self->{name};
}

# returns the error line
sub error {
  my $self = shift;
  return $self->{error};
}

# scans the script for labels
sub scanLabels {
  my $script = shift;
  my %labels;
  for (my $line = 0; $line < @{$script}; $line++) {
    if (${$script}[$line] =~ /^:/) {
      my ($label) = ${$script}[$line] =~ /^:(.*)$/;
      $labels{$label} = $line;
    }
    if (${$script}[$line] =~ /^while\s+/) {
      my ($label) = ${$script}[$line] =~ /\s+as\s+(.*)$/;
      $labels{$label} = $line;
    }
    if (${$script}[$line] =~ /^end\s+/) {
      my ($label) = ${$script}[$line] =~ /^end\s+(.*)$/;
      $labels{"end ".$label} = $line;
    }
  }
  return %labels;
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
        $self->{line}++;
      }
      return $command;
    }
    $self->{error} = $self->{subcall}->{error};
    return
  }
  $self->{timeout} = $timeout{macro_delay}{timeout};
  my $line = ${$self->{script}}[$self->{line}];
  if (!defined $line) {
    if ($self->{repeat} > 1) {
      $self->{repeat}--;
      $self->{line} = 0;
    } else {
      $self->{finished} = 1;
    }
    return ""
  }
  ##########################################
  # jump to label: goto label
  if ($line =~ /^goto\s/) {
    my ($tmp) = $line =~ /^goto\s+([a-zA-Z][a-zA-Z\d]*)/;
    if (exists $self->{label}->{$tmp}) {
      $self->{line} = $self->{label}->{$tmp};
    } else {
      $self->{error} = "error in ".$self->{line}.": cannot find label ".$tmp;
    }
  ##########################################
  # declare block ending: end label
  } elsif ($line =~ /^end\s/) {
    my ($tmp) = $line =~ /^end\s+(.*)/;
    if (exists $self->{label}->{$tmp}) {
      $self->{line} = $self->{label}->{$tmp};
    } else {
      $self->{error} = "error in ".$self->{line}.": cannot find block start";
    }
  ##########################################
  # if statement: if (foo = bar) goto label?
  } elsif ($line =~ /^if\s/) {
    my ($first, $cond, $last, $then) = $line =~ /^if\s+\(\s*(.*?)\s+([<>=!]+?)\s+(.*?)\s*\)\s+(.*?)$/;
    if (!defined $first || !defined $cond || !defined $last || !defined $then || $then !~ /^(goto\s|stop)/) {
      $self->{error} = "error in ".$self->{line}.": syntax error in if statement";
    } else {
      $first = parseCmd($first); $last = parseCmd($last);
      if (cmpr($first, $cond, $last)) {
        if ($then =~ /^goto\s/) {
          my ($tmp) = $then =~ /^goto\s+([a-zA-Z][a-zA-Z\d]*)$/;
          if (exists $self->{label}->{$tmp}) {
            $self->{line} = $self->{label}->{$tmp};
          } else {
            $self->{error} = "error in ".$self->{line}.": cannot find label ".$tmp;
          }
        } elsif ($then =~ /^stop$/) {
          $self->{finished} = 1;
        }
      } else {
        $self->{line}++;
      }
    }
  ##########################################
  # while statement: while (foo <= bar) as label
  } elsif ($line =~ /^while\s/) {
    my ($first, $cond, $last, $label) = $line =~ /^while\s+\(\s*(.*?)\s+([<>=!]+?)\s+(.*?)\s*\)\s+as\s+(.*)$/;
    if (!defined $first || !defined $cond || !defined $last || !defined $label) {
      $self->{error} = "error in ".$self->{line}.": syntax error in while statement";
    } else {
      $first = parseCmd($first); $last = parseCmd($last);
      if (!cmpr($first, $cond, $last)) {
        $self->{line} = $self->{label}->{"end ".$label}
      }
      $self->{line}++;
    }
  ##########################################
  # set variable: $variable = value
  } elsif ($line =~ /^\$[a-z]/i) {
    my ($var, $val);
    if (($var, $val) = $line =~ /^\$([a-z][a-z\d]*?)\s+=\s+(.*)$/i) {
      setVar($var, parseCmd($val));
    } elsif (($var, $val) = $line =~ /^\$([a-z][a-z\d]*?)([+-]{2})$/i) {
      if ($val eq '++') {setVar($var, getVar($var)+1)}
      else {setVar($var, getVar($var)-1)}
    } else {
      $self->{error} = "error in ".$self->{line}.": unrecognized assignment";
    }
    $self->{line}++;
  ##########################################
  # set doublevar: ${$variable} = value
  } elsif ($line =~ /^\$\{\$[.a-z]/i) {
    my ($dvar, $val);
    if (($dvar, $val) = $line =~ /^\$\{\$([.a-z][a-z\d]*?)\}\s+=\s+(.*)$/i) {
      my $var = getVar($dvar);
      setVar("#".$var, parseCmd($val));
    } elsif (($dvar, $val) = $line =~ /^\$\{\$([.a-z][a-z\d]*?)\}([+-]{2})$/i) {
      my $var = getVar($dvar);
      if ($val eq '++') {setVar("#".$var, getVar("#".$var)+1)}
      else {setVar("#".$var, getVar("#".$var)-1)}
    } else {
        $self->{error} = "error in ".$self->{line}.": unrecognized assignment.";
    }
    $self->{line}++;
  ##########################################
  # label definition: :label
  } elsif ($line =~ /^:/) {
    $self->{line}++;
  ##########################################
  # returns command: do whatever
  } elsif ($line =~ /^do\s/) {
    my ($tmp) = $line =~ /^do\s+(.*)/;
    if ($tmp =~ /^macro\s+/) {
      my ($arg) = $tmp =~ /^macro\s+(.*)/;
      if ($arg ne 'stop') {
        $self->{error} = "error in ".$self->{line}.": use 'call $arg' instead of 'macro $arg'";
        return
      }
    }
    $self->{line}++;
    return parseCmd($tmp);
  ##########################################
  # log command
  } elsif ($line =~ /^log\s+/) {
    my ($tmp) = $line =~ /^log\s+(.*)/;
    $tmp = parseCmd($tmp);
    message "[macro][log] $tmp\n", "macro";
    $self->{line}++;
  ##########################################
  # pause command
  } elsif ($line =~ /^pause/) {
    my ($tmp) = $line =~ /^pause\s+(\d+)/;
    if (defined $tmp) {$self->{timeout} = $tmp}
    $self->{line}++
  ##########################################
  # stop command
  } elsif ($line =~ /^stop$/) {
    $self->{error} = "macro stopped in line ".$self->{line};
  ##########################################
  # release command
  } elsif ($line =~ /^release\s+/) {
    my ($tmp) = $line =~ /^release\s+(.*)/;
    releaseAM($tmp);
    $self->{line}++;
  ##########################################
  # call command
  } elsif ($line =~ /^call\s+/) {
    my ($tmp) = $line =~ /^call\s+(.*)/;
    if ($tmp =~ /\s/) {
      my ($name, $times) = $tmp =~ /(.*?)\s+(.*)/;
      $self->{subcall} = new Macro::Script($name, $times);
    } else {
      $self->{subcall} = new Macro::Script($tmp);
    }
    if (!defined $self->{subcall}) {
      $self->{error} = "error in ".$self->{line}.": failed to call script";
    }
  ##########################################
  # unrecognized line
  } else {
    $self->{error} = "error in ".$self->{line}.": syntax error";
  }
  if (defined $self->{error}) {return} else {$self->{time} = time;return ""}
}

1;
