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

my $chooks = Commands::register(
	['iconf', 'edit items_control.txt', \&xConf],
	['mconf', 'edit mon_control.txt', \&xConf],
	['pconf', 'edit pickupitems.txt', \&xConf],
	['sconf', 'edit shop.txt', \&xConf],
	['priconf', 'edit priority.txt', \&priconf],
);

sub Unload {
	Commands::unregister($chooks);
	message "xConf plugin reloading or unloading\n", 'success'
}

sub xConf {
my ($cmd, $args) = @_;
	my ($file,$file2,$found,$key,$oldval,$shopname,$type,$value, $name, $inf_hash, $ctrl_hash);
	if ($cmd eq 'sconf') {
		($key, $value) = $args =~ /(name)(?:\s)(.*)/;
		$shopname = 1 if $key eq 'name';
	}
	($key, $value) = $args =~ /([\s\S]+?)(?:\s)([\-\d\.]+[\s\S]*)/ if !$shopname;
	$key = $args if !$key;
	$key =~ s/^\s+|\s+$//g;
	debug "extracted from args: KEY: $key, VALUE: $value\n";
	if (!$key) {
		error "Syntax Error in function '$cmd'. Not found <key>\n".
				"Usage: $cmd <key> [<value>]\n";
		return;
	}
	if ($cmd eq 'iconf') {
		$inf_hash  = \%items_lut;
		$ctrl_hash = \%items_control;
		$file = 'items_control.txt';
		$file2 = 'tables\..\items.txt';
		$type = 'Item';
	} elsif ($cmd eq 'mconf') {
		$inf_hash  = \%monsters_lut;
		$ctrl_hash = \%mon_control;
		$file = 'mon_control.txt';
		$file2 = 'tables\..\monsters.txt';
		$type = 'Monster';
	} elsif ($cmd eq 'pconf') {
		$inf_hash  = \%items_lut;
		$ctrl_hash = \%pickupitems;
		$file = 'pickupitems.txt';
		$file2 = 'tables\..\items.txt';
		$type = 'Item';
	} elsif ($cmd eq 'sconf') {
		$inf_hash = \%items_lut;
		$ctrl_hash = \%shop;
		$file = 'shop.txt';
		$file2 = 'tables\..\items.txt';
		$type = 'Item';
	}
	## Command "sconf" don't have setall & clearall feature
	if( (($key eq "clearall") || ($key eq "setall")) && ($cmd eq 'sconf')) {
		error "Syntax Error in function '$cmd'. Keys 'setall' and 'clearall' is not suported.\n";
		return;
	} elsif($key eq "clearall")	{ ## If $key is "clear" clear file content and exit
		fileclear($file);
		return;
	} elsif (($key eq "setall")) { ## If $key is "setall" setting all keys in file to $key
		filesetall($file, $value);
		return;
	}
	## Check $key in tables\monsters.txt & tables\items.txt
	if ($key ne "all") {

		#key is an ID, have to find the name of the item/monster
		if ($inf_hash->{$key}) {
			debug "key is an ID, $type '$inf_hash->{$key}' ID: $key is found in file '$file2'.\n";
			$found = 1;
			if ($cmd eq 'iconf' && $itemSlotCount_lut{$key}) {
				$name = $inf_hash->{$key}." [".$itemSlotCount_lut{$key}."]";
			} else {
				$name = $inf_hash->{$key};
			}

		#key is a name, have to find ID of the item/monster
		} else {
			foreach (values %{$inf_hash}) {
				if ((lc($key) eq lc($_))) {
					$name = $_;
					foreach my $ID (keys %{$inf_hash}) {
						if ($inf_hash->{$ID} eq $name) {
							$key = $ID;
							$found = 1;
							debug "$type '$name' found in file '$file2'.\n";
							last;
						}
					}
					last;
				}
			}
		}

		#at this point, $key is always the ID of the item/monster
		#and the name is stored on $name

		debug "Id: '$key', name: '$name', value: $value\n";
		if (!$found and !$shopname) {
			if ($cmd eq 'mconf') {
				warning "WARNING: $type '$key' not found in file '$file2'!\n";
			} else {
				error "$type '$key' not found in file '$file2'!\n";
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
		$oldval = sprintf("%s %s %s %s %s", $ctrl_hash->{$realKey}{attack_auto}, $ctrl_hash->{$realKey}{teleport_auto},
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
				if (lc($sale->{name}) eq lc($key)) {
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
		error "$type '$key' is not found in file '$file'!\n";
	} elsif (not defined $value or $value eq $oldval) {
		message "$file: '$key' is $oldval\n", "info";
	} else {
		filewrite($file, $key, $value, $oldval, $shopname, $name, $realKey);
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
	my ($file, $key, $value, $oldval, $shopname, $name, $realKey) = @_;
	my @value;
	my $controlfile = Settings::getControlFilename($file);
	debug "sub WRITE = FILE: $file\nKEY: $key\nVALUE: $value\nNAME: $name\nOLDVALUE: $oldval\nREALKEY: $realKey";

	open(FILE, "<:encoding(UTF-8)", $controlfile);
	my @lines = <FILE>;
	close(FILE);
	chomp @lines;

	my $used = 0;
	if ($shopname) {
		@value = split(/,,/, $value);
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
			my $tmp;
			if (lc($what) eq $realKey) {
				debug "Change old record: ";
				if ($file eq 'shop.txt') {
					$tmp = join ('	', $name, @value);
				} else {
					if ($realKey eq lc($name)) {
						$tmp = join (' ', $name, @value, "#", $key);
					} else {
						$tmp = join (' ', $key, @value, "#", $name);
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
				push (@lines, $key.' '.$value. " #". $name)
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
