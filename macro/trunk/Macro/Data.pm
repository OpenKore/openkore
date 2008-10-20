# $Id$
package Macro::Data;

use strict;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(%macro %automacro %varStack $queue $onHold %amSingle %amMulti $macroKeywords);

our %macro;
our %automacro;
our %varStack;
our $queue;
our $onHold;

our %amSingle = (
	'map' => 1,          # map check
	'mapchange' => 1,    # map change check
	'class' => 1,        # job class check
	'timeout' => 1,      # setting: re-check timeout
	'delay' => 1,        # option: delay before the macro starts
	'run-once' => 1,     # option: run automacro only once
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
	'priority' => 1,     # option: automacro priority
	'exclusive' => 1,     # option: is macro interruptible
	'eval' => 1	     # check : eval 
	
);

our %amMulti = (
	'set' => 1,          # set: variable
	'save' => 1,         # setting: save hook arguments
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

our $macroKeywords =
	"npc"          . "|" .
	"cart"         . "|" .
	"inventory"    . "|" .
	"store"        . "|" .
	"storage"      . "|" .
	"player"       . "|" .
	"vender"       . "|" .
	"venderitem"   . "|" .
	"venderprice"  . "|" .
	"venderamount" . "|" .
	"random"       . "|" .
	"rand"         . "|" .
	"[Ii]nvamount" . "|" .
	"[Cc]artamount". "|" .
	"[Ss]hopamount". "|" .
	"[Ss]toramount". "|" .
	"config"       . "|" .
	"eval"         . "|" .
	"arg"          . "|" .
	"listitem"     . "|" .
	"listlenght"
;

1;
