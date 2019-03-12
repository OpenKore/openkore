# xConf plugin by 4epT (ICQ 2227733)
# Based on Lims idea
# Version: 4.1
# Last changes 12.03.2017 by Mortimal
# Plug-in for change mon_control/pickupitems/items_control/priority files, using console commands.
#
# Examples of commands:
# mconf Spore 0 0 0
# mconf 1014 0 0 0
#
# iconf Meat 50 1 0
# iconf 517 50 1 0
#
# pconf Fluff -1
# pconf 914 -1
#
# priconf Pupa, Poring, Lunatic
#
# mconf clearall
# iconf setall 0 0 0

package xConf;

use strict;
use Plugins;
use Globals;
use Log qw(message error debug warning);
use Misc qw(parseReload);

Plugins::register('xConf', 'commands for change items_control, mon_control, pickupitems, priority', \&Unload, \&Unload);

my $plugin_commands = Commands::register(
	['iconf', 'edit items_control.txt', \&xConf],
	['mconf', 'edit mon_control.txt', \&xConf],
	['pconf', 'edit pickupitems.txt', \&xConf],
	['sconf', 'edit shop.txt', \&xConf],
	['priconf', 'edit priority.txt', \&priconf],
);

sub Unload {
	Commands::unregister($plugin_commands);
	message "xConf plugin reloading or unloading\n", 'success'
}

sub xConf {
	my ($cmd, $args) = @_;
	my ($file,$tables_file,$found,$key,$oldval,$shopname,$type,$value, $name, $inf_hash, $ctrl_hash, $id, $needQuotes);
	
	($key, $value) = $args =~ /([\s\S]+?)\s([\-\d\.]+[\s\S]*)/ if !$shopname;
	
	if ($cmd eq 'sconf') {
		($key, $value) = $args =~ /(name)\s(.*)/;
		$shopname = $value if $key eq 'name';
		$inf_hash = \%items_lut;
		$ctrl_hash = \%shop;
		$file = 'shop.txt';
		$tables_file = 'tables\..\items.txt';
		$type = 'Item';
		
	} elsif ($cmd eq 'iconf') {
		
		$inf_hash  = \%items_lut;
		$ctrl_hash = \%items_control;
		$file = 'items_control.txt';
		$tables_file = 'tables\..\items.txt';
		$type = 'Item';
		
		#syntax checking for items with number in name buy whithout quotes to surrond it
		if ($key =~ /[a-zA-Z][0-9]/ && $key !~ /"/) {
			warning ("$key has number in name, we recommend surround it with quotes");
		}
		
		if ($key =~ /"/) {
			$needQuotes = 1; #first remove quotes to do all check and after in the end put it back
		}
		
	} elsif ($cmd eq 'pconf') {
		$inf_hash  = \%items_lut;
		$ctrl_hash = \%pickupitems;
		$file = 'pickupitems.txt';
		$tables_file = 'tables\..\items.txt';
		$type = 'Item';
		
	} elsif ($cmd eq 'mconf') {
		$inf_hash  = \%monsters_lut;
		$ctrl_hash = \%mon_control;
		$file = 'mon_control.txt';
		$tables_file = 'tables\..\monsters.txt';
		$type = 'Monster';
		
	}
	
	$key = $args if !$key;
	$key =~ s/^\s+|\s+$//g;
	$key =~ s/"(.+)"/\1/; #remove quotes
	debug "extracted from args: KEY: $key, VALUE: $value\n";
	if (!$key) {
		error "Syntax Error in function '$cmd'. Not found <key>\n".
				"Usage: $cmd <key> [<value>]\n";
		return;
	}
	
	## Command "sconf" don't have setall & clearall feature
	if ( ($key eq "clearall" || $key eq "setall") && $cmd eq 'sconf') {
		error "Syntax Error in function '$cmd'. Keys 'setall' and 'clearall' is not suported.\n";
		return;
	} elsif ($key eq "clearall") { ## If $key is "clear" clear file content and exit
		fileclear($file);
		return;
	} elsif ($key eq "setall") { ## If $key is "setall" setting all keys in file to $key
		filesetall($file, $value);
		return;
	}
	## Check $key in tables\monsters.txt or tables\items.txt
	if ($key ne "all") {

		#key is an ID, have to find the name of the item/monster
		if ($inf_hash->{$key}) {
			debug "key is an ID, $type '$inf_hash->{$key}' ID: $key is found in file '$tables_file'.\n";
			$found = 1;
			if ($cmd eq 'iconf' && $itemSlotCount_lut{$key}) {
				$name = $inf_hash->{$key}." [".$itemSlotCount_lut{$key}."]";
			} else {
				$name = $inf_hash->{$key};
			}
			$id = $key;

		#key is a name, have to find ID of the item/monster
		} else {
			my $options;
			if ($key =~/\[\d*\]/) { #testing if item has slot
				($key,$options) = $key =~ /(.*?)(\[.+\])/;
				$key =~ s/^\s+|\s+$//g;
				$needQuotes = 1;
			}
			my $key_with_underscore = $key;
			$key_with_underscore =~ s/ /_/;
			for (my $i; $i < values %{$inf_hash}; $i++) {
				if (lc($key) eq lc($inf_hash->{$i}) || lc($key_with_underscore) eq lc($inf_hash->{$i})) {
					$id = $i;
					$found = 1;
					debug "$type '$name' found in file '$tables_file'.\n";
					last;
				}
			}
			$key = (defined $options ? $key . ' ' . $options : $key);
			$name = $key;
		}

		debug "Id: '$id', name: '$name', value: $value\n";
		if (!$found and !$shopname) {
			if ($cmd eq 'mconf') {
				warning "WARNING: Monster '$name' not found in file '$tables_file'!\n";
			} else {
				error "Item '$name'(id: $id) not found in file '$tables_file'!\n";
				return;
			}
		}
	}
	
	my $realKey;
	
	if (exists $ctrl_hash->{lc($name)}) {
		$realKey = lc($name);
	} else {
		$realKey = $key;
	}
	
	if ($cmd eq 'iconf') {
		$oldval = sprintf("%s %s %s %s %s", $ctrl_hash->{$realKey}{keep}, $ctrl_hash->{$realKey}{storage}, $ctrl_hash->{$realKey}{sell},
			$ctrl_hash->{$realKey}{cart_add}, $ctrl_hash->{$realKey}{cart_get});
	} elsif ($cmd eq 'mconf') {
		$oldval = sprintf("%s %s %s %s %s %s %s %s %s", $ctrl_hash->{$realKey}{attack_auto}, $ctrl_hash->{$realKey}{teleport_auto},
			$ctrl_hash->{$realKey}{teleport_search}, $ctrl_hash->{$realKey}{skillcancel_auto}, $ctrl_hash->{$realKey}{attack_lvl},
			$ctrl_hash->{$realKey}{attack_jlvl}, $ctrl_hash->{$realKey}{attack_hp}, $ctrl_hash->{$realKey}{attack_sp},
			$ctrl_hash->{$realKey}{weight});
	} elsif ($cmd eq 'pconf') {
		$oldval = $pickupitems{$realKey};
	} elsif ($cmd eq 'sconf') {
		if ($shopname) {
			$oldval = $shop{title_line};
			$oldval =~ s/;;/,,/g;
		} else {
			for my $sale (@{$shop{items}}) {
				if (lc($sale->{name}) eq lc($realKey)) {
					$oldval = $sale->{price};
					$oldval .= "..$sale->{priceMax}" if ($sale->{priceMax});
					$oldval .= " $sale->{amount}";
					last;
				}
			}
		}
	}
	$oldval =~ s/\s+$//g;
	$value =~ s/\s+$//g;
	debug "VALUE: '$value', OLDVALUE: '$oldval'\n";
	if (not defined $value and $oldval eq '') {
		error "$type '$realKey' is not found in file '$file'!\n";
	} elsif (not defined $value) {
		message "$file: '$name' is $oldval\n", "info";
	} elsif ($value eq $oldval) {
		message "$file: '$name' is already '$value'\n", 'info';
	} else {
		filewrite($file, $realKey, $value, $oldval, $shopname, $name, $id, $needQuotes);
	}
}

## clear file leave only #lines, emptylines and all parameter.
sub fileclear {
	my ($file) = @_;
	my $controlfile = Settings::getControlFilename($file);
	open(FILE, "<:utf8", $controlfile);
	my @lines = <FILE>;
	close(FILE);
	chomp @lines;
	my @newlines;
	foreach (@lines) {
		push (@newlines,$_) if $_ =~ /^$/ || $_ =~ /^#/ || $_ =~ /^all/;
	}
	open(WRITE, ">:utf8", $controlfile);
	print WRITE join ("\n", @newlines);
	close(WRITE);
	message "xConf. $file: cleared.\n", 'info';
	parseReload($file);
}

## set all keys to $value
sub filesetall {
	my ($file,$value) = @_;
	my $controlfile = Settings::getControlFilename($file);
	my @value;
	
	if (!$value) {
		push (@value, "0") ;
	} else {
		@value = split(/\s+/, $value);
	}
	
	open(FILE, "<:utf8", $controlfile);	
	my @lines = <FILE>;
	close(FILE);
	chomp @lines;
	
	foreach my $line (@lines) {
		next if $line =~ /^$/ || $line =~ /^#/;
		my ($what) = $line =~ /([\s\S]+?)(?:\s[\-\d\.]+[\s\S]*)/;
		$what =~ s/\s+$//g;
		$line = join (' ', $what, @value);
	}
	
	open(WRITE, ">:utf8", $controlfile);
	print WRITE join ("\n", @lines);
	close(WRITE);
	
	message "xConf. $file: all set to $value.\n", 'info';
	parseReload($file);
}

## write FILE
sub filewrite {
	my ($file, $realKey, $value, $oldval, $shopname, $name, $id, $needQuotes) = @_;
	my @value;
	my $controlfile = Settings::getControlFilename($file);
	debug "sub filewrite =\n".
	"FILE: '$file'\n".
	"REALKEY: '$realKey'\n".
	"VALUE: '$value'\n".
	"OLDVALUE: '$oldval'\n".
	"SHOPNAME: '$shopname'\n".
	"NAME: '$name'\n".
	"ID: '$id'\n".
	"NEEDQUOTES: '$needQuotes'\n";

	open(FILE, "<:encoding(UTF-8)", $controlfile);
	my @lines = <FILE>;
	close(FILE);
	chomp @lines;

	my $used = 0;
	if ($shopname) {
		@value = split(/,,/, $shopname);
		foreach my $line (@lines) {
			next if $line =~ /^$/ || $line =~ /^#/;
			if ($line eq $shop{title_line}) {
				$line = join (';;', @value);
				last;
			}
		}

	} else {
		@value = split(/\s+/, $value);
		foreach my $line (@lines) {
			my ($what) = $line =~ /([\s\S]+?)\s[\-\d\.]+[\s\S]*/;
			$what =~ s/\s+$//g;
			$what =~ s/"(.+)"/\1/; #remove quotes
			my $tmp;
			if ($what eq $id ||lc($what) eq lc($name)) {
				debug "Change old record: ";
				if ($file eq 'shop.txt') {
					$tmp = join ('	', $name, @value);
				} else {
					if (lc($realKey) eq lc($name)) {
						if ($needQuotes) {
							$tmp = join (' ', "\"$name\"", @value, "#", $id);
						} else {
							$tmp = join (' ', $name, @value, "#", $id);
						}
					} else {
						$tmp = join (' ', $id, @value, "#", $name);
					}
				}
				$line = $tmp;
				$used = 1;
			}
		}
		if ($used == 0) {
			debug "New record: ";
			my ($price, $amount) = split(/\s+/, $value);
			if ($file eq 'shop.txt') {
				push (@lines, $name.'	'.$price.'	'.$amount)
			} else {
				if (lc($realKey) eq lc($name)) {
					if ($needQuotes) {
						push (@lines, '"'. $name. '"'. ' '.$value. " #ID: ". $id)
					} else {
						push (@lines, $name.' '.$value. " #ID: ". $id)
					}
				} else {
					push (@lines, $id.' '.$value. " #". $name)
				}
			}
		}
	}
	open(WRITE, ">:utf8", $controlfile);
	print WRITE join ("\n", @lines);
	close(WRITE);
	message "$file: '$name' set to @value (was ". ($oldval || "*None*") .")\n", 'info';
	parseReload($file);
}

sub priconf {
	my ($cmd, $args) = @_;
	my @mobs = split /\s*,\s*/, $args;
	if (@mobs == 0) { 
		error "Syntax Error in function 'priconf'.\n".
				"Usage: priconf monster1, monster2, ...\n";
		return;
	}
	my $controlfile = Settings::getControlFilename('priority.txt');
	open(my $file,"<:utf8",$controlfile);
	my @lines;
	while (my $tmp = <$file>) {
		push @lines, $tmp if ($tmp =~ /^#/ or $tmp =~ /^!/);
	}
	push @lines, "\n";
	foreach (@mobs) { push @lines, $_."\n" }
	close($file);
	open($file,">:utf8",$controlfile);
	print $file @lines;
	close($file);
	parseReload("priority.txt");
}

1;
