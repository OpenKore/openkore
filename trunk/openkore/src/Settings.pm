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

# Other stuff
our $usageText = <<EOF;
Usage: openkore.exe [options...]

The supported options are:
--help                     Displays this help message.
--control=path             Use a different folder as control folder.
--tables=path              Use a different folder as tables folder.
--logs=path                Save log files in a different folder.
--plugins=path             Look for plugins in specified folder.
--fields=path              Where fields folder to use.

--config=path/file         Which config.txt to use.
--mon_control=path/file    Which mon_control.txt to use.
--items_control=path/file  Which items_control.txt to use.
--pickupitems=path/file    Which pickupitems.txt to use.
--chat=path/file           Which chat.txt to use.
--shop=path/file           Which shop.txt to use.
--monsters=path/file       Which monsters.txt to use.
--items=path/file          Which items.txt to use.

--interface=module         Which interface to use at startup.
EOF


##
# Settings::parseArguments()
# Returns: 1 on success, 2 if a 'usage' text should be displayed.
#          If an error occured, the return value is an error message string.
#
# Parse commandline arguments. Various variables within the Settings.pm
# module will be filled with values.
sub parseArguments {
	$control_folder = "control";
	$tables_folder = "tables";
	$logs_folder = "logs";
	$plugins_folder = "plugins";
	$def_field = "fields";

	$config_file = "$control_folder/config.txt";
	$mon_control_file = "$control_folder/mon_control.txt";
	$items_control_file = "$control_folder/items_control.txt";
	$pickupitems_file = "$control_folder/pickupitems.txt";
	$chat_file = "$logs_folder/chat.txt";
	$shop_file = "$control_folder/shop.txt";
	$monster_log = "$logs_folder/monsters.txt";
	$item_log_file = "$logs_folder/items.txt";

	$default_interface = "Console";


	my $help_option;
	GetOptions(
		'help',		\$help_option,
		'control=s',	\$control_folder,
		'tables=s',	\$tables_folder,
		'logs=s',	\$logs_folder,
		'plugins=s',	\$plugins_folder,
		'fields=s',	\$def_field,

		'config=s',		\$config_file,
		'mon_control=s',	\$mon_control_file,
		'items_control=s',	\$items_control_file,
		'pickupitems=s',	\$pickupitems_file,
		'chat=s',		\$chat_file,
		'shop=s',		\$shop_file,
		'monsters=s',		\$monster_log,
		'items=s',		\$item_log_file,

		'interface=s',		\$default_interface
	);

	if ($help_option) {
		return 2;
	}

	if (! -d $logs_folder) {
		if (!mkdir($logs_folder)) {
			return "Unable to create folder $logs_folder ($!)";
		}
	}
	return 1;
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
