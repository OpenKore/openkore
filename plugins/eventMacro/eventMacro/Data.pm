package eventMacro::Data;

use strict;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw($eventMacro @perl_name $valid_var_characters $general_variable_qr $general_wider_variable_qr $scalar_variable_qr $array_variable_qr $accessed_array_variable_qr $hash_variable_qr $accessed_hash_variable_qr $macro_keywords_character %parameters $macroKeywords CHECKING_AUTOMACROS PAUSED_BY_EXCLUSIVE_MACRO PAUSE_FORCED_BY_USER CHECKING_FORCED_BY_USER STATE_TYPE EVENT_TYPE);

our $eventMacro;
our @perl_name;

our $valid_var_characters = qr/\.?[a-zA-Z][a-zA-Z\d_]*/;

our $general_variable_qr = qr/(?:\$$valid_var_characters(?:\[\d+\]|\{[a-zA-Z\d_]+\})?|\@$valid_var_characters|\%$valid_var_characters)/;

our $general_wider_variable_qr = qr/(?:\$$valid_var_characters(?:\[.+?\]|\{.+?\})?|\@$valid_var_characters|\%$valid_var_characters)/;

our $scalar_variable_qr = qr/\$$valid_var_characters/;

our $array_variable_qr = qr/\@$valid_var_characters/;
our $accessed_array_variable_qr = qr/\$$valid_var_characters\[\d+\]/;

our $hash_variable_qr = qr/\%$valid_var_characters/;
our $accessed_hash_variable_qr = qr/\$$valid_var_characters\{[a-zA-Z\d_]+\}/;

our $macro_keywords_character = '&';

use constant {
	CHECKING_AUTOMACROS => 0,
	PAUSED_BY_EXCLUSIVE_MACRO => 1,
	PAUSE_FORCED_BY_USER => 2,
	CHECKING_FORCED_BY_USER => 3
};

use constant {
	STATE_TYPE => 1,
	EVENT_TYPE => 2
};

our %parameters = (
	'timeout' => 1,               # setting: re-check timeout
	'delay' => 1,                 # option: delay before the macro starts
	'run-once' => 1,              # option: run automacro only once
	'disabled' => 1,              # option: automacro disabled
	'call' => 1,                  # setting: macro to be called
	'overrideAI' => 1,            # option: override AI
	'orphan' => 1,                # option: orphan handling
	'macro_delay' => 1,           # option: default macro delay
	'priority' => 1,              # option: automacro priority
	'exclusive' => 1,             # option: is macro interruptible by other automacros
	'self_interruptible' => 1,    # option: is macro interruptible by its own caller automacro
	'repeat' => 1,                # option: the number of times the called macro will repeat itself
	'CheckOnAI' => 1,             # option: on which AI state the automacro will be checked
);

our $macroKeywords = join '|', qw(
	arg listlength
	cartamount cart Cart
	config
	defined
	eval
	exists
	delete
	invamount inventory Inventory InventoryType
	keys
	monster
	nick
	npc
	player
	push pop unshift shift
	random rand
	shopamount
	split
	store storamount
	storage Storage
	strip
	questStatus questInactiveCount questIncompleteCount questCompleteCount
	values
	vender venderitem venderprice venderamount
);

1;
