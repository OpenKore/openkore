#########################################################################
#  OpenKore - Settings
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#
#  $Revision$
#  $Id$
#
#########################################################################

package Settings;

use strict;
use Exporter;
use base qw(Exporter);
use Getopt::Long;
use Globals;
use Plugins;
use Utils;
use Log;

our @EXPORT_OK = qw(parseArguments addConfigFile delConfigFile);


# Constants
our $NAME = 'OpenKore';
our $VERSION = 'CVS';
our $WEBSITE = 'http://openkore.sourceforge.net';
our $versionText = "*** $NAME $VERSION - Custom Ragnarok Online client ***\n***   $WEBSITE   ***\n";
our $welcomeText = "Welcome to X-$NAME.";
our $MAX_READ = 30000;

# Commandline arguments
our $daemon;
our $control_folder;
our $tables_folder;
our $logs_folder;
our $plugins_folder;
our $config_file;
our $items_control_file;
our $pickupitems_file;
our $mon_control_file;
our $chat_file;
our $item_log_file;
our $shop_file;
our $def_field;
our $monster_log;
our $default_interface;

# Configuration files and associated file parsers
our @configFiles;


sub MODINIT {
	$daemon = 0;
	$control_folder = "control";
	$tables_folder = "tables";
	$logs_folder = "logs";
	$plugins_folder = "plugins";
}


sub parseArguments {
	my $help_option;
	undef $config_file;
	undef $items_control_file;
	undef $mon_control_file;
	undef $chat_file;
	undef $item_log_file;
	undef $shop_file;
	# For some reason MODINIT() is not called on Win32 (when running as compiled executable)
	# FIXME: find out why and fix it.
	MODINIT();
	
	GetOptions(
		'daemon', \$daemon,
		'help', \$help_option,
		'control=s', \$control_folder,
		'tables=s', \$tables_folder,
		'logs=s', \$logs_folder,
		'plugins=s', \$plugins_folder,
		'config=s', \$config_file,
		'mon_control=s', \$mon_control_file,
		'items_control=s', \$items_control_file,
		'pickupitems=s', \$pickupitems_file,
		'chat=s', \$chat_file,
		'shop=s', \$shop_file,
		'fields=s',\$def_field,
		'monsters=s', \$monster_log,
		'items=s', \$item_log_file,
		'interface=s', \$default_interface);
	if ($help_option) {
		print "Usage: openkore.exe [options...]\n\n";
		print "The supported options are:\n\n";
		print "--help                     Displays this help message.\n";
		print "--daemon                   Start as daemon; don't listen for keyboard input.\n";
		print "--control=path             Use a different folder as control folder.\n";
		print "--tables=path              Use a different folder as tables folder.\n";
		print "--logs=path                Save log files in a different folder.\n";
		print "--plugins=path             Look for plugins in specified folder.\n";
		print "--fields=path              Where fields folder to use.\n";
		print "\n";
		print "--config=path/file         Which config.txt to use.\n";
		print "--mon_control=path/file    Which mon_control.txt to use.\n";
		print "--items_control=path/file  Which items_control.txt to use.\n";
		print "--pickupitems=path/file    Which pickupitems.txt to use.\n";
		print "--chat=path/file           Which chat.txt to use.\n";
		print "--shop=path/file           Which shop.txt to use.\n";
		print "--interface=module         Which interface to use at startup.\n";
		exit(0);
	}

	$config_file = "$control_folder/config.txt" if (!defined $config_file);
	$monster_log = "$logs_folder/monsters.txt" if (!defined $monster_log);
	$items_control_file = "$control_folder/items_control.txt" if (!defined $items_control_file);
	$pickupitems_file = "$control_folder/pickupitems.txt" if (!defined $pickupitems_file);
	$mon_control_file = "$control_folder/mon_control.txt" if (!defined $mon_control_file);
	$chat_file = "$logs_folder/chat.txt" if (!defined $chat_file);
	$item_log_file = "$logs_folder/items.txt" if (!defined $item_log_file);
	$shop_file = "$control_folder/shop.txt" if (!defined $shop_file);
	$def_field = "fields" if (!defined $def_field);
	$logs_folder = "logs" if (!defined $logs_folder);
	$plugins_folder = "plugins" if (!defined $plugins_folder);
	$default_interface = 'Console' if !defined $default_interface;

	if (! -d $logs_folder) {
		if (!mkdir($logs_folder)) {
			print "Error: unable to create folder $logs_folder ($!)\n";
			<STDIN>;
			exit 1;
		}
	}
}


sub addConfigFile {
	my ($file, $hash, $func) = @_;
	my %item;

	$item{file} = $file;
	$item{hash} = $hash;
	$item{func} = $func;
	return binAdd(\@configFiles, \%item);
}

sub delConfigFile {
	my $ID = shift;
	delete $configFiles[$ID];
}

sub load {
	my $r_array = shift;
	$r_array = \@configFiles if (!$r_array);

	Plugins::callHook('preloadfiles', {files => $r_array});
	foreach (@{$r_array}) {
		if (-f $$_{file}) {
			Log::message("Loading $$_{file}...\n", "load");
		} else {
			Log::error("Error: Couldn't load $$_{file}\n", "load");
		}
		$_->{func}->($_->{file}, $_->{hash});
	}
	Plugins::callHook('postloadfiles', {files => $r_array});
}

sub parseReload {
	my $temp = shift;
	my @temp;
	my %temp;
	my $temp2;
	my $qm;
	my $except;
	my $found;

	while ($temp =~ /(\w+)/g) {
		$temp2 = $1;
		$qm = quotemeta $temp2;
		if ($temp2 eq "all") {
			foreach (@configFiles) {
				$temp{$_->{file}} = $_;
			}

		# FIXME: This belongs somewhere else
		} elsif ($temp2 eq "plugins") {
			message("Reloading all plugins...\n", "load");
			Plugins::unloadAll();
			Plugins::loadAll();

		} elsif ($temp2 =~ /\bexcept\b/i || $temp2 =~ /\bbut\b/i) {
			$except = 1;

		} else {
			if ($except) {
				foreach (@configFiles) {
					delete $temp{$_->{file}} if $_->{file} =~ /$qm/i;
				}
			} else {
				foreach (@configFiles) {
					$temp{$_->{file}} = $_ if $_->{file} =~ /$qm/i;
				}
			}
		}
	}

	foreach my $f (keys %temp) {
		$temp[@temp] = $temp{$f};
	}
	load(\@temp);
}


return 1;
