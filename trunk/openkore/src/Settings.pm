#########################################################################
#  OpenKore - Settings
#  This module defines configuration variables and filenames of data files.
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#
#
#
#  $Revision$
#  $Id$
#
#########################################################################

package Settings;

use strict;
use Exporter;
use Getopt::Long;
# NOTE: do not use any other Kore modules here. It will create circular dependancies.

our @ISA = ("Exporter");
our @EXPORT_OK = qw(parseArguments);
our @EXPORT = qw($buildType
	%config %consoleColors %timeout %npcs_lut %maps_lut
	@parseFiles $parseFiles);


# Constants
our $NAME = 'OpenKore';
our $VERSION = '1.2.1';
our $WEBSITE = 'http://openkore.sourceforge.net';
our $versionText = "*** $NAME $VERSION - Custom Ragnarok Online client ***\n***   $WEBSITE   ***\n";
our $welcomeText = "Welcome to X-$NAME.";
our $MAX_READ = 30000;

# Configuration variables
our $buildType;
our $daemon;
our %config;
our %consoleColors;
our %timeout;
our %npcs_lut;
our %maps_lut;

# Data files and folders
our $control_folder;
our $tables_folder;
our $logs_folder;
our $plugins_folder;
our $config_file;
our $items_control_file;
our $mon_control_file;
our $chat_file;
our $item_log_file;
our $shop_file;

our @parseFiles;
our $parseFiles;


BEGIN {
	if ($^O eq 'MSWin32' || $^O eq 'cygwin') {
		$buildType = 0;
	} else {
		$buildType = 1;
	}
}

sub MODINIT {
	$daemon = 0;
	$parseFiles = 0;
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
		'chat=s', \$chat_file,
		'shop=s', \$shop_file,
		'items=s', \$item_log_file);
	if ($help_option) {
		print "Usage: openkore.exe [options...]\n\n";
		print "The supported options are:\n\n";
		print "--help                     Displays this help message.\n";
		print "--daemon                   Start as daemon; don't listen for keyboard input.\n";
		print "--control=path             Use a different folder as control folder.\n";
		print "--tables=path              Use a different folder as tables folder.\n";
		print "--logs=path                Save log files in a different folder.\n";
		print "--plugins=path             Look for plugins in specified folder.\n";

		print "\n";
		print "--config=path/file         Which config.txt to use.\n";
		print "--mon_control=path/file    Which mon_control.txt to use.\n";
		print "--items_control=path/file  Which items_control.txt to use.\n";
		print "--chat=path/file           Which chat.txt to use.\n";
		print "--shop=path/file           Which shop.txt to use.\n";
		exit(0);
	}

	$config_file = "$control_folder/config.txt" if (!defined $config_file);
	$items_control_file = "$control_folder/items_control.txt" if (!defined $items_control_file);
	$mon_control_file = "$control_folder/mon_control.txt" if (!defined $mon_control_file);
	$chat_file = "$logs_folder/chat.txt" if (!defined $chat_file);
	$item_log_file = "$logs_folder/items.txt" if (!defined $item_log_file);
	$shop_file = "$control_folder/shop.txt" if (!defined $shop_file);
	$logs_folder = "logs" if (!defined $logs_folder);
	$plugins_folder = "plugins" if (!defined $plugins_folder);

	if (! -d $logs_folder) {
		if (!mkdir($logs_folder)) {
			print "Error: unable to create folder $logs_folder ($!)\n";
			<STDIN> if ($buildType == 0);
			exit 1;
		}
	}
}


return 1;
