package eventMacro::Data;

use strict;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw($eventMacro @perl_name %parameters $macroKeywords);

our $eventMacro;
our @perl_name;

our %parameters = (
	'timeout' => 1,      # setting: re-check timeout
	'delay' => 1,        # option: delay before the macro starts
	'run-once' => 1,     # option: run automacro only once
	'disabled' => 1,     # option: automacro disabled
	'call' => 1,         # setting: macro to be called
	'overrideAI' => 1,   # option: override AI
	'orphan' => 1,       # option: orphan handling
	'macro_delay' => 1,  # option: default macro delay
	'priority' => 1,     # option: automacro priority
	'exclusive' => 1,    # option: is macro interruptible
);

our $macroKeywords =
	"npc"          . "|" .
	"store"        . "|" .
	"player"       . "|" .
	"monster"      . "|" .
	"venderitem"   . "|" .
	"venderprice"  . "|" .
	"venderamount" . "|" .
	"random"       . "|" .
	"rand"         . "|" .
	"invamount"    . "|" .
	"cartamount"   . "|" .
	"shopamount"   . "|" .
	"storamount"   . "|" .
	"[Ii]nventory" . "|" .
	"[Ss]torage"   . "|" .
	"[Cc]art"      . "|" .
	"vender"       . "|" .
	"config"       . "|" .
	"eval"         . "|" .
	"arg"          . "|" .
	"listitem"     . "|" .
   	"nick"         . "|" .
	"listlenght"
;

1;
