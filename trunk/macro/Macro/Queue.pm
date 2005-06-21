# $Header$

package Macro::Queue;

use strict;
use warnings;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(processQueue);

use Utils;
use Globals;
use AI;
use Log qw(error);
use Commands;
use Macro::Data;
use Macro::Parser qw(parseCmd);
use Macro::Utilities qw(ai_isIdle);

our $Version = sprintf("%d.%02d", q$Revision$ =~ /(\d+)\.(\d+)/);

# constructor, creates a new queue
sub new {
  my ($class, $name) = @_;
  return unless defined $macro{$name};
  my $self = {
    name => $name,
    queue => [@{$macro{$name}}],
    timeout => $timeout{macro_delay}{timeout},
    time => time,
    finished => 0,
    overrideAI => 0
  };
  bless ($self, $class);
  AI::queue('macro');
  return $self;
};

# destructor, dequeues from AI if needed
sub DESTROY {
  AI::dequeue() if AI::is('macro');
};

# returns the name of the current macro in queue
sub name {
  my $self = shift;
  return $self->{name};
};

# gets next command from queue, parses it and returns the result
# returns: parsed command, undef if there was an error
sub next {
  my $self = shift;
  return parseCmd(shift(@{$self->{queue}})) if @{$self->{queue}};
  $self->{finished} = 1;
  $self->{timeout} = 0;
  return;
};

# prepends another macro to current queue
sub addMacro {
  my ($self, $name) = @_;
  @{$self->{queue}} = (@{$macro{$name}}, @{$self->{queue}});
  AI::queue('macro');
};

# sets timeout for next command
sub setTimeout {
  my ($self, $timeout) = @_;
  $self->{timeout} = $timeout;
  $self->{time} = time;
};

# gets timeout for next command
sub timeout {
  my $self = shift;
  my %tmp = (time => $self->{time}, timeout => $self->{timeout});
  return %tmp;
};

# sets override AI
sub setOverrideAI {
  my $self = shift;
  $self->{overrideAI} = 1;
};

# gets override AI value
sub overrideAI {
  my $self = shift;
  return $self->{overrideAI};
};

# returns whether or not the macro finished
sub finished {
  my $self = shift;
  return $self->{finished};
};

# runs and removes commands from queue
sub processQueue {
  # this should never happen.
  if (!defined $queue) {
    if (AI::is('macro')) { ## cut
    AI::dequeue if AI::is('macro');
      $cvs->debug("in processQueue, \$queue is undef mit AI::is macro", 1);
    }; ## cut
    return
  };
  my %tmptime = $queue->timeout;
  if (timeOut(\%tmptime) && ai_isIdle()) {
    my $command = $queue->next;
    if (defined $command) {
      if ($command ne "") {
        $cvs->debug("processing $command)", 1);
        Commands::run($command) || main::parseCommand($command);
        $queue->setTimeout($timeout{macro_delay}{timeout});
      };
    } else {
      if (!$queue->finished) {
        error(sprintf("[macro] an error occurred in %s\n", $queue->name));
      };
      undef $queue;
    };
  };
};

1;
