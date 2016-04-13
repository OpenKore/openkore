# xConf plugin by 4epT (ICQ 2227733)
# Based on Lims idea
# Version: 4
# Last changes 15.05.2013
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

package xConf;

use strict;
use Plugins;
use Globals;
use Log qw(message error debug warning);

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
	my ($file,$file2,$found,$key,$oldval,$shopname,$type,$value, %inf_hash, %ctrl_hash);
	if ($cmd eq 'sconf') {
		($key, $value) = $args =~ /(name)(?:\s)(.*)/;
		$shopname = 1 if $key eq 'name';
	}
	($key, $value) = $args =~ /([\s\S]+?)(?:\s)([\-\d\.(\.\.)]+[\s\S]*)/ if !$shopname;
	$key = $args if !$key;
	$key =~ s/\s+$//g;
debug "KEY: $key, VALUE: $value\n";
	if (!$key) {
		error "Syntax Error in function '$cmd'. Not found <key>\n".
				"Usage: $cmd <key> [<value>]\n";
		return;
	}
	if ($cmd eq 'iconf') {
		%inf_hash  = %items_lut;
		%ctrl_hash = %items_control;
		$file = 'items_control.txt';
		$file2 = 'tables\..\items.txt';
		$type = 'Item';
	} elsif ($cmd eq 'mconf') {
		%inf_hash  = %monsters_lut;
		%ctrl_hash = %mon_control;
		$file = 'mon_control.txt';
		$file2 = 'tables\..\monsters.txt';
		$type = 'Monster';
	} elsif ($cmd eq 'pconf') {
		%inf_hash  = %items_lut;
		%ctrl_hash = %pickupitems;
		$file = 'pickupitems.txt';
		$file2 = 'tables\..\items.txt';
		$type = 'Item';
	} elsif ($cmd eq 'sconf') {
		%inf_hash = %items_lut;
		%ctrl_hash = %shop;
		$file = 'shop.txt';
		$file2 = 'tables\..\items.txt';
		$type = 'Item';
	}

## Check $key in tables\monsters.txt & tables\items.txt
	if ($key ne "all") {
## Search name by ID
		if ($inf_hash{$key}) {
debug "$type '$inf_hash{$key}' ID: $key is found in file '$file2'.\n";
		$found = 1;
		$key = $inf_hash{$key}
		} else {
## Search name by $key
			foreach my $name (values %inf_hash) {
				if ($found = (lc($key) eq lc($name))) {
					$key = $name;
debug "$type '$name' is found in file '$file2'.\n";
					last
				}
			}
		}
		if (!$found and !$shopname) {
			if ($cmd eq 'mconf') {
				warning "WARNING: $type '$key' is not found in file '$file2'!\n";
			} else {
				error "$type '$key' is not found in file '$file2'!\n";
				return;
			}
		}
	}

	if ($cmd eq 'iconf') {$oldval = "$items_control{lc($key)}{keep} $items_control{lc($key)}{storage} $items_control{lc($key)}{sell} $items_control{lc($key)}{cart_add} $items_control{lc($key)}{cart_get}"}
	if ($cmd eq 'mconf') {$oldval = "$ctrl_hash{lc($key)}{attack_auto} $ctrl_hash{lc($key)}{teleport_auto} $ctrl_hash{lc($key)}{teleport_search} $ctrl_hash{lc($key)}{skillcancel_auto} $ctrl_hash{lc($key)}{attack_lvl} $ctrl_hash{lc($key)}{attack_jlvl} $ctrl_hash{lc($key)}{attack_hp} $ctrl_hash{lc($key)}{attack_sp} $ctrl_hash{lc($key)}{weight}"}
	if ($cmd eq 'pconf') {$oldval = $pickupitems{lc($key)}}
	if ($cmd eq 'sconf') {
		if ($shopname) {
			$oldval = $shop{title_line};
			$oldval =~ s/;;/,,/g;
		} else {
			for my $sale (@{$shop{items}}) {
				if (lc($sale->{name}) eq lc($key)) {
					$oldval = ($sale->{priceMax}) ? "$sale->{price}..$sale->{priceMax} $sale->{amount}" : "$sale->{price} $sale->{amount}";
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
		filewrite($file, $key, $value, $oldval,$shopname);
	}
}

## write FILE
sub filewrite {
	my ($file, $key, $value, $oldval,$shopname) = @_;
	my @value;
	my $controlfile = Settings::getControlFilename($file);
debug "sub WRITE = FILE: $file, KEY: $key, VALUE: $value, OLDVALUE: $oldval\n";
	open(FILE, "<:utf8", $controlfile);
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
		my ($what) = $line =~ /([\s\S]+?)(?:\s[\-\d\.]+[\s\S]*)/;
		$what =~ s/\s+$//g;
		my $tmp;
		if (lc($what) eq lc($key)) {
debug "Change old record: ";
			if ($file eq 'shop.txt') {
				$tmp = join ('	', $key, @value);
			} else {
				$tmp = join (' ', $key, @value);
			}
			$line = $tmp;
			$used = 1;
		}
	}
	if ($used == 0) {
debug "New record: ";
	my ($price, $amount) = split(/\s+/, $value);
		if ($file eq 'shop.txt') {
			push (@lines, $key.'	'.$price.'	'.$amount)
		} else {
			push (@lines, $key.' '.$value)
		}
	}
	}
	open(WRITE, ">:utf8", $controlfile);
	print WRITE join ("\n", @lines);
	close(WRITE);
	message "$file: '$key' set to @value (was $oldval)\n", 'info';
	Commands::run("reload $file")
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
		$tmp =~ s/\x{FEFF}//g;
		push @lines, $tmp if $tmp =~ /^#/;
	}
	push @lines, "\n";
	foreach (@mobs) { push @lines, $_."\n" }
	close($file);
	open($file,">:utf8",$controlfile);
	print $file @lines;
	close($file);
	Commands::run("reload priority.txt");
}

1;