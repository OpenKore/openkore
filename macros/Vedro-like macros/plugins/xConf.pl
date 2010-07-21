# xConf plugin by 4epT (ICQ 2227733)
# Based on Lims idea
# Edited by Dairey
# Last changes 03.02.2009
# Plug-in for change mon_control/pickupitems/items_control files, using console commands.
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


package xConf;

use Plugins;
use Globals;
use Log qw(message error debug);

## startup
Plugins::register('xConf', 'commands for change items_control, mon_control, pickupitems', \&Unload);

## Register command 'xConf'
my $chooks = Commands::register(
   ['iconf', 'edit items_control.txt', \&xConf],
   ['mconf', 'edit mon_control.txt', \&xConf],
   ['pconf', 'edit pickupitems.txt', \&xConf],
   ['sconf', 'edit shop.txt', \&xConf]
);

sub Unload {
   Commands::unregister($chooks);
   message " xConf plugin unloading, ", 'success'
}

sub xConf {
   my ($cmd, $args) = @_;
   my ($key, undef, $value) = $args =~ /([\s\S]+?)( |   )([\-\d\.]+[\s\S]*)/;
   $key = $args if !$key;
debug "KEY: $key, VALUE: $value\n";
   if (!$key) {
      error "Syntax Error in function '$cmd'. Not found <key>\nUsage: $cmd <key> [<value>]\n";
      return
   }
   my ($file,$found,$name, %inf_hash, %ctrl_hash) = undef;

   if ($cmd eq 'mconf') {
      %inf_hash  = %monsters_lut;
      %ctrl_hash = %mon_control;
      $file = 'mon_control.txt'
   } elsif ($cmd eq 'pconf') {
      %inf_hash  = %items_lut;
      %ctrl_hash = %pickupitems;
      $file = 'pickupitems.txt'
   } elsif ($cmd eq 'iconf') {
      %inf_hash  = %items_lut;
      %ctrl_hash = %items_control;
      $file = 'items_control.txt'
   } elsif ($cmd eq 'sconf') {
      %inf_hash = %items_lut;
     %ctrl_hash = %shop;
     $file = 'shop.txt'
   }

## Check  $key in tables\monsters.txt & items.txt

if ($key ne "all") {
      if ($inf_hash{$key}) {
debug "'$inf_hash{$key}' ID: $key is found in 'tables\\monsters.txt'.\n";
         $found = 1;
         $key = $inf_hash{$key}
      } else {
         foreach $name (values %inf_hash) {
            if ($found = (lc($key) eq lc($name))) {
            $key = $name;
debug "'$name' is found in 'tables\\monsters.txt'.\n";
            last
            }
         }
      }
      if (!$found) {error "WARNING: '$key' is not found in 'tables\\monsters.txt' and in 'tables\\items.txt'!\n"}
}
      if($value eq '') {
	  if ($cmd eq 'sconf') {
		my $i = 0;
		$found = 0;
		until ($ctrl_hash{items}[$i]{name} eq "") {
		if ($ctrl_hash{items}[$i]{name} eq $args) {
		$found = 1;
		message "\n$file:\n------------------------------\n $ctrl_hash{items}[$i]{name} $ctrl_hash{items}[$i]{price} $ctrl_hash{items}[$i]{amount}\n------------------------------\n\n", 'list'
		}
		$i++;
		}
	if (!$found) {
	error "The key '$key' is not found in '$file'\n";
	}
	} else {
         if ($ctrl_hash{lc($key)}) {
			$key = lc($key);
            if ($cmd eq 'mconf') {
            message "\n$file:\n------------------------------\n $key $ctrl_hash{$key}{attack_auto} $ctrl_hash{$key}{teleport_auto} $ctrl_hash{$key}{teleport_search} $ctrl_hash{$key}{skillcancel_auto} $ctrl_hash{$key}{attack_lvl} $ctrl_hash{$key}{attack_jlvl} $ctrl_hash{$key}{attack_hp} $ctrl_hash{$key}{attack_sp} $ctrl_hash{$key}{weight}\n------------------------------\n\n", 'list'
            } elsif ($cmd eq 'pconf') {
               message "\n$file:\n------------------------------\n $key $pickupitems{$key}\n------------------------------\n\n", 'list'
            } elsif ($cmd eq 'iconf') {
               message "\n$file:\n------------------------------\n $key $items_control{$key}{keep} $items_control{$key}{storage} $items_control{$key}{sell} $items_control{$key}{cart_add} $items_control{$key}{cart_get}\n------------------------------\n\n", 'list'
            }
         } else {error "The key '$key' is not found in '$file'\n"}
      }
	  return
	  }
   filewrite($file, $key, $value)
}

## write FILE
sub filewrite {
   my ($file, $key, $value) = @_;
   my @folders = Settings::getControlFolders();
debug "sub WRITE = FILE: $file, KEY: $key, VALUE: $value\n";
   open (FILE, "$folders[0]/$file");
   my @lines = <FILE>;
   close (FILE);
   chomp @lines;

   my @new = ();
   my $used = 0;
   foreach my $line (@lines) {
      my ($what, undef, $is) = $line =~ /([\s\S]+?)( |   )([\-\d\.]+[\s\S]*)/;
      if(lc($what) eq lc($key)) {
         if($file eq 'shop.txt') {
         $line = join ('	', $key, $value);
         } else {
         $line = join (' ', $key, $value);
         }
         $used = 1
      }
      push (@new, $line)
   }
   if($used == 0){
   if($file eq 'shop.txt') {
   push (@new, $key.'	'.$value)
   } else {
      push (@new, $key.' '.$value)
   }
   }

   open (WRITE, ">$folders[0]/$file");
   print WRITE join ("\n", @new);
   close (WRITE);
   message "\n $file:\n------------------------------\n $key $value\n------------------------------\n\n", 'system';
   Commands::run("reload $file")
}
return 1;