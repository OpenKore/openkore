package Macro::Data;

use strict;
use warnings;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(%macro %automacro %varStack $queue $cvs %logfac $onHold %amSingle %amMulti);

our %macro;
our %automacro;
our %varStack;
our $queue;
our $cvs;
our $onHold;

our %logfac = (
  'variable_trace'      => 1,    # tracks variables
  'command_preparsed'   => 2,    # unparsed command line
  'command_parsed'      => 4,    # parsed command line
  'parser_steps'        => 8,    # parser steps
  'function_call_macro' => 16,   # functions with low traffic, macro functions
  'function_call_auto'  => 32,   # functions with high traffic, automacro functions
  'automacro_checks'    => 64,   # automacro checks
  'developers'          => 128,  # debugging messages useful for developers
  'full'                => 255   # full debugging
);

our %amSingle = (
  'map' => 1,          # map check
  'mapchange' => 1,    # map change check
  'class' => 1,        # job class check
  'timeout' => 1,      # setting: re-check timeout
  'delay' => 1,        # option: delay before the macro starts
  'disabled' => 1,     # option: automacro disabled
  'call' => 1,         # setting: macro to be called
  'spell' => 1,        # check: cast sensor
  'notMonster' => 1,   # check: disallow monsters other than ~
  'pm' => 1,           # check: private message
  'pubm' => 1,         # check: public chat
  'guild' => 1,        # check: guild chat
  'party' => 1,        # check: party chat
  'console' => 1,      # check: console message
  'overrideAI' => 1,   # option: override AI
  'orphan' => 1,       # option: orphan handling
  'macro_delay' => 1,  # option: default macro delay
  'hook' => 1,         # check: openkore hook
  'save' => 1,         # setting: save hook arguments
  'priority' => 1,     # option: automacro priority
  'exclusive' => 1     # option: is macro interruptible
);

our %amMulti = (
  'monster' => 1,      # check: monster on screen
  'aggressives' => 1,  # check: aggressives
  'location' => 1,     # check: player's location
  'var' => 1,          # check: variable / value
  'varvar' => 1,       # check: nested variable / value
  'base' => 1,         # check: base level
  'job' => 1,          # check: job level
  'hp' => 1,           # check: player's hp
  'sp' => 1,           # check: player's sp
  'spirit' => 1,       # check: spirit spheres
  'weight' => 1,       # check: player's weight
  'cartweight' => 1,   # check: cart weight
  'soldout' => 1,      # check: sold out shop slots
  'zeny' => 1,         # check: player's zeny
  'player' => 1,       # check: player name near
  'equipped' => 1,     # check: equipment
  'status' => 1,       # check: player's status
  'inventory' => 1,    # check: item amount in inventory
  'storage' => 1,      # check: item amount in storage
  'shop' => 1,         # check: item amount in shop
  'cart' => 1          # check: item amount in cart
);

1;
