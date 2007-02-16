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
##
# MODULE DESCRIPTION: Settings and configuration loading
#
# This module:
# `l
# - Handles commandline argument parsing.
# - Keeps a list of configuration files.
# - Contains functions which are used for loading configuration.
# `l`
#
# The functions for parsing configuration files are in FileParsers.pm.
# The variables which contain the configuration data are in Globals.pm.

package Settings;

use strict;
use Exporter;
use base qw(Exporter);
use Getopt::Long;

use Modules 'register';
use Globals;
use Plugins;
use Utils::DataStructures qw(binAdd);
use Utils::Exceptions;
use Log qw(warning error);
use Translation qw(T TF);

our @EXPORT_OK = qw(parseArguments addConfigFile delConfigFile %sys $VERSION);


###################################
### CATEGORY: Constants
###################################

##
# String $Settings::NAME
#
# The name of this program, usually "OpenKore".

##
# String $Settings::VERSION
#
# The version number of this program.

# Translation Comment: Strings for the name and version of the application
our $NAME = 'OpenKore';
our $VERSION = '1.9.4';
# Translation Comment: Version String
our $CVS = T(" (SVN version)");
our $WEBSITE = 'http://www.openkore.com/';
# Translation Comment: Version String
our $versionText = "*** $NAME ${VERSION}${CVS} - " . T("Custom Ragnarok Online client") . " ***\n***   $WEBSITE   ***\n";
our $welcomeText = TF("Welcome to %s.", $NAME);
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
our $storage_file;
our $shop_log_file;
our $shop_file;
our $def_field;
our $monster_log;
our $default_interface;
our $no_connect;

# System configuration
our %sys;

# Configuration files and associated file parsers
our @configFiles;

# Other stuff
my $pathDelimiter = ($^O eq 'MSWin32') ? ';' : ':';
our $usageText = <<EOF;
Usage: openkore.exe [options...]

The supported options are:
--help                     Displays this help message.
--control=path             Use a different folder as control folder.
--tables=path              Use a different folder as tables folder.
--logs=path                Save log files in a different folder.
--plugins=paths            Look for plugins in specified folder. You can
                           specify multiple paths, delimited by '$pathDelimiter'.
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

Developer options:
--no-connect               Do not connect to any servers.
EOF



##
# Settings::parseArguments()
# Returns: 1 on success, 0 if a 'usage' text should be displayed.
#
# Parse commandline arguments. Various variables within the Settings
# module will be filled with values.
#
# This function will also attempt to create necessary folders. If
# one of the folders cannot be created, then an IOException is thrown,
# although the variables are already filled.
#
# If the arguments are not correct, then an ArgumentException is thrown.
sub parseArguments {
	$control_folder = "control";
	$tables_folder = "tables";
	$logs_folder = "logs";
	$plugins_folder = "plugins";
	$def_field = "fields";

	# We don't pre-define the values for other variables here.
	# Defining variables that include other variables (that may be changed later) is a bad thing.
	# Example: since control_folder == control by default, even if the user sets control_folder == conf as a getopt
	# $config_file will still be control/config.txt since $control_folder was set to control when $config_file was defined.
	undef $config_file;
	undef $mon_control_file;
	undef $items_control_file;
	undef $pickupitems_file;
	undef $chat_file;
	undef $shop_file;
	undef $storage_file;
	undef $monster_log;
	undef $item_log_file;
	undef $default_interface;
	undef $no_connect;

	my $help_option;
	my $warnText;
	local $SIG{__WARN__} = sub {
		ArgumentException->throw($_[0]);
	};
	GetOptions(
		'help',	              \$help_option,
		'control=s',          \$control_folder,
		'tables=s',           \$tables_folder,
		'logs=s',             \$logs_folder,
		'plugins=s',          \$plugins_folder,
		'fields=s',           \$def_field,

		'config=s',           \$config_file,
		'mon_control=s',      \$mon_control_file,
		'items_control=s',    \$items_control_file,
		'pickupitems=s',      \$pickupitems_file,
		'chat=s',             \$chat_file,
		'shop=s',             \$shop_file,
		'storage=s',          \$storage_file,
		'monsters=s',         \$monster_log,
		'items=s',            \$item_log_file,

		'interface=s',        \$default_interface,

		'no-connect',         \$no_connect
	);

	# This is where variables depending on other userconfigable variables should be set..
	# after we see what the user is changing...
	$config_file        = "$control_folder/config.txt" if (!defined $config_file);
	$mon_control_file   = "$control_folder/mon_control.txt" if (!defined $mon_control_file);
	$items_control_file = "$control_folder/items_control.txt" if (!defined $items_control_file);
	$pickupitems_file   = "$control_folder/pickupitems.txt" if (!defined $pickupitems_file);
	$chat_file          = "$logs_folder/chat.txt" if (!defined $chat_file);
	$shop_file          = "$control_folder/shop.txt" if (!defined $shop_file);
	$monster_log        = "$logs_folder/monsters.txt" if (!defined $monster_log);
	$item_log_file      = "$logs_folder/items.txt" if (!defined $item_log_file);
	$storage_file       = "$logs_folder/storage.txt" if (!defined $storage_file);
	$shop_log_file    ||= "$logs_folder/shop.txt";
	if (!defined $default_interface) {
		if ($ENV{OPENKORE_DEFAULT_INTERFACE} && $ENV{OPENKORE_DEFAULT_INTERFACE} ne "") {
			$default_interface = $ENV{OPENKORE_DEFAULT_INTERFACE};
		} else {
			$default_interface = "Console"
		}
	}

	return 0 if ($help_option);
	if (! -d $logs_folder) {
		if (!mkdir($logs_folder)) {
			IOException->throw("Unable to create folder $logs_folder ($!)");
		}
	}
	return 1;
}

sub loadSysConfig {
	_processSysConfig(0);
}

sub writeSysConfig {
	_processSysConfig(1);
}

sub _processSysConfig {
	my ($writeMode) = @_;
	my ($f, @lines, %keysNotWritten);
	return if (!open($f, "<:utf8", "$control_folder/sys.txt"));
	
	if ($writeMode) {
		foreach my $key (keys %sys) {
			$keysNotWritten{$key} = 1;
		}
	}

	while (!eof($f)) {
		my ($line, $key, $val);
		$line = <$f>;
		$line =~ s/[\r\n]//g;

		if ($line eq '' || $line =~ /^#/) {
			if ($writeMode) {
				push @lines, $line;
			} else {
				next;
			}
		}

		($key, $val) = split / /, $line, 2;
		if ($writeMode) {
			if (exists $sys{$key}) {
				push @lines, "$key $sys{$key}";
				delete $keysNotWritten{$key};
			}
		} else {
			$sys{$key} = $val;
		}
	}
	close $f;

	if ($writeMode && open($f, ">:utf8", "$control_folder/sys.txt")) {
		foreach my $line (@lines) {
			print $f "$line\n";
		}
		foreach my $key (keys %keysNotWritten) {
			print $f "$key $sys{$key}\n";
		}
		close $f;
	}
}


##
# Settings::addConfigFile(String file, r_store, parser_func)
# file: The configuration file to add.
# r_store: A reference to a variable (of any type) that's used to store the configuration data.
# parser_func: A function which parses $file and put the result into r_store.
# Returns: an ID which you can pass to Settings::delConfigFile() or Settings::load()
#
# Adds a configuration file to the internal configuration file list. The configuration file won't be
# loaded immediately.
# Configuration files in the list are (re)loaded:
# `l
# - At startup
# - When the user types the 'reload' command.
# `l`
# If you want to load this configuration file now, use Settings::load().
#
# parser_func is called like this: $parser_func->($file, $r_store);
#
# See also: Settings::delConfigFile(), Settings::load(), FileParsers.pm
#
# Example:
# # Configuration file account.txt looks like this:
# username blabla
# password 1234
#
# # Perl source:
# use FileParsers; # This is where parseDataFile() is defined
#
# # Add configuration file
# my %account;
# my $ID = Settings::addConfigFile("account.txt", \%account, \&parseDataFile);
# # %account is now still empty
# Settings::load($ID);             # Now account.txt is loaded %account is filled
# print "$account{username}\n";    # -> "blabla"
#
# Settings::delConfigFile($ID);
sub addConfigFile {
	my ($file, $r_store, $func) = @_;
	my %item;

	$item{file} = $file;
	$item{hash} = $r_store;
	$item{func} = $func;
	return binAdd(\@configFiles, \%item);
}

##
# Settings::delConfigFile(ID)
# ID: An ID, as returned by Settings::addConfigFile()
#
# Removes a configuration file from the internal configuration file list.
# See also: Settings::addConfigFile()
sub delConfigFile {
	my $ID = shift;
	delete $configFiles[$ID];
}

sub load {
	my $items = shift;
	my @array;

	if (!defined $items) {
		@array = @configFiles;
	} elsif (!ref($items)) {
		push @array, $configFiles[$items];
	} elsif (ref($items) eq 'ARRAY') {
		@array = @{$items};
	}

	Plugins::callHook('preloadfiles', {files => \@array});
	my $i = 1;
	foreach (@array) {
		if (-f $_->{file}) {
			Log::message(TF("Loading %s...\n", $_->{file}), "load");
		} elsif ($_->{file} !~ /(portalsLOS|npcs)\.txt$/i) {
			Log::error(TF("Error: Couldn't load %s\n", $_->{file}), "load");
			return 0;
		}

		Plugins::callHook('loadfiles', {files => \@array, current => $i});
		return 0 unless $_->{func}->($_->{file}, $_->{hash});
		$i++;
	}
	Plugins::callHook('postloadfiles', {files => \@array});
	return 1;
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

1;
