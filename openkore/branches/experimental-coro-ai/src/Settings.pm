#########################################################################
#  OpenKore - Settings
#  Copyright (c) 2007 OpenKore Developers
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
# MODULE DESCRIPTION: Settings and configuration files management.
#
# Core OpenKore settings, such as OpenKore's program name and version number,
# are stored by this module.
#
# OpenKore uses two kinds of data files:
# `l
# - Control files. These configuration files define character-specific
#   behavior and can be changed at any time.
# - Table files. These files contain character-independent, but server-specific
#   information that OpenKore needs. These files are read-mostly (don't change
#   often).
# `l`
# This module is also responsible for data file management. It allows one to:
# `l
# - Register control or table files by name.
# - Locate control or table files from multiple possible locations.
# - (Re)load control or table files based on some search criteria.
# `l`
# Most of the functions for parsing configuration files are located in
# FileParsers.pm, while the variables which contain the configuration data are
# in Globals.pm.
#
# Finally, the Settings module provides support functions for commandline
# argument parsing.
package Settings;

use strict;
use Coro;
use FindBin qw($RealBin);
use lib "$RealBin";
use lib "$RealBin/src";
use lib "$RealBin/src/deps";
use Exporter;
use base qw(Exporter);
use Carp::Assert;
use UNIVERSAL qw(isa);
use Scalar::Util qw(reftype refaddr blessed);
use Getopt::Long;
use File::Spec;
use Log qw(message warning error debug);
use Translation qw(T TF);
use Utils::ObjectList;
use Utils::Exceptions;
use enum qw(CONTROL_FILE_TYPE TABLE_FILE_TYPE);
use Modules 'register';

our @EXPORT_OK = qw(%sys $interface_name);



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
our $VERSION = 'AI 2008';
# Translation Comment: Version String
our $SVN = T(" (Dev Version) ");
our $WEBSITE = 'http://www.openkore.com/';
# Translation Comment: Version String
our $versionText = "*** $NAME ${VERSION}${SVN} - " . T("Custom Ragnarok Online client") . " ***\n***   $WEBSITE   ***\n";
our $welcomeText = TF("Welcome to %s.", $NAME);


# Data file folders.
our @controlFolders :shared;
our @tablesFolders :shared;
our @pluginsFolders :shared;
# The registered data files.
our $files :shared;
# System configuration.
our %sys :shared;

our $fields_folder :shared;
our $logs_folder :shared;

our $config_file :shared;
our $mon_control_file :shared;
our $items_control_file :shared;
our $shop_file :shared;
our $recvpackets_name :shared;

our $chat_log_file :shared;
our $storage_log_file :shared;
our $shop_log_file :shared;
our $sys_file :shared;
our $monster_log_file :shared;
our $item_log_file :shared;

our $interface_name :shared;
our $lockdown :shared;
our $no_connect :shared;


my $pathDelimiter = ($^O eq 'MSWin32') ? ';' : ':';

###################################
### CATEGORY: Public functions
###################################

##
# int Settings::parseArguments()
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
	my %options;

	lock ($fields_folder);
	lock ($logs_folder);
	lock ($config_file);
	lock ($mon_control_file);
	lock ($items_control_file);
	lock ($shop_file);
	lock ($chat_log_file);
	lock ($storage_log_file);
	lock ($sys_file);
	lock ($interface_name);
	lock ($lockdown);
	lock ($shop_log_file);
	lock ($monster_log_file);
	lock ($item_log_file);
	lock ($files);

	undef $fields_folder;
	undef $logs_folder;
	undef $config_file;
	undef $mon_control_file;
	undef $items_control_file;
	undef $shop_file;
	undef $chat_log_file;
	undef $storage_log_file;
	undef $sys_file;
	undef $interface_name;
	undef $lockdown;
	
	$files = ObjectList->new();

	local $SIG{__WARN__} = sub {
		ArgumentException->throw($_[0]);
	};
	GetOptions(
		'control=s',          \$options{control},
		'tables=s',           \$options{tables},
		'plugins=s',          \$options{plugins},
		'fields=s',           \$fields_folder,
		'logs=s',             \$logs_folder,

		'config=s',           \$config_file,
		'mon_control=s',      \$mon_control_file,
		'items_control=s',    \$items_control_file,
		'shop=s',             \$shop_file,
		'chat-log=s',         \$chat_log_file,
		'storage-log=s',      \$storage_log_file,
		'sys=s',              \$sys_file,

		'interface=s',        \$interface_name,
		'lockdown',           \$lockdown,
		'help',	              \$options{help},

		'no-connect',         \$no_connect
	);

	if ($options{control}) {
		setControlFolders(split($pathDelimiter, $options{control}));
	} else {
		setControlFolders("control");
	}
	if ($options{tables}) {
		setTablesFolders(split($pathDelimiter, $options{tables}));
	} else {
		setTablesFolders("tables");
	}
	if ($options{plugins}) {
		setPluginsFolders(split($pathDelimiter, $options{plugins}));
	} else {
		setPluginsFolders("plugins");
	}

	$fields_folder = "fields" if (!defined $fields_folder);
	$logs_folder = "logs" if (!defined $logs_folder);
	$chat_log_file = File::Spec->catfile($logs_folder, "chat.txt");
	$storage_log_file = File::Spec->catfile($logs_folder, "storage.txt");
	$shop_log_file = File::Spec->catfile($logs_folder, "shop_log.txt");
	$monster_log_file = File::Spec->catfile($logs_folder, "monster_log.txt");
	$item_log_file = File::Spec->catfile($logs_folder, "item_log.txt");
	if (!defined $interface_name) {
		if ($ENV{OPENKORE_DEFAULT_INTERFACE} && $ENV{OPENKORE_DEFAULT_INTERFACE} ne "") {
			$interface_name = $ENV{OPENKORE_DEFAULT_INTERFACE};
		} else {
			$interface_name = "Console"
		}
	}

	return 0 if ($options{help});
	if (! -d $logs_folder) {
		if (!mkdir($logs_folder)) {
			IOException->throw("Unable to create folder $logs_folder ($!)");
		}
	}
	return 1;
}

##
# String Settings::getUsageText()
#
# Return the usage text that should be displayed.
sub getUsageText {
	my $text = qq{
		Usage: openkore.exe [options...]

		General path options:
		--control=PATHS           Specify folders in which to look for control files.
		--tables=PATHS            Specify folders in which to look for table files.
		--plugins=PATH            Specify folders in which to look for plugins.
		For the above options, you can specify multiple paths, delimited by '$pathDelimiter'.

		--fields=PATH             Specify the folder in which to look for field files.
		--logs=PATH               Save log files in the specified folder.

		Control files lookup options:
		--config=FILENAME         Which config.txt to use.
		--mon_control=FILENAME    Which mon_control.txt to use.
		--items_control=FILENAME  Which items_control.txt to use.
		--shop=FILENAME           Which shop.txt to use.
		--chat-log=FILENAME       Which chat log file to use.
		--storage-log=FILENAME    Which storage log file to use.
		--sys=FILENAME            Which sys.txt to use.

		Other options:
		--interface=NAME          Which interface to use at startup.
		--lockdown                Disable potentially insecure features.
		--help                    Displays this help message.

		Developer options:
		--no-connect              Do not connect to any servers.
	};
	$text =~ s/^\n//s;
	$text =~ s/^\t\t?//gm;
	return $text;
}

##
# void Settings::setControlFolders(Array<String> folders)
#
# Set the folders in which to look for control files.
sub setControlFolders {
	lock (@controlFolders);
	@controlFolders = @_;
}

sub getControlFolders {
	return @controlFolders;
}

##
# void Settings::setTablesFolders(Array<String> folders)
#
# Set the folders in which to look for table files.
sub setTablesFolders {
	lock (@tablesFolders);
	@tablesFolders = @_;
}

sub getTablesFolders {
	return @tablesFolders;
}

##
# void Settings::setPluginsFolders(Array<String> folders)
#
# Set the folders in which to look for plugins.
sub setPluginsFolders {
	lock (@pluginsFolders);
	
	@pluginsFolders = @_;
}

##
# Array<String> Settings::getPluginsFolders()
#
# Get the folders in which to look for plugins.
sub getPluginsFolders {
	return @pluginsFolders;
}

##
# Settings::addControlFile(String name, options...)
# Returns: A handle for this data file, which can be used by Settings::removeFile() or Settings::loadByHandle().
#
# Register a control file. This file will be eligable for (re)loading
# when one of the load() functions is called.
#
# The following options are allowed:
# `l
# - loader (required): must be either a reference to a function, or
#       be an array in which the first element is a function reference.
#       This function will be used to load this control file. In case
#       of an array, all but the first element of that array will be passed
#       to the load function as additional parameters.
# - autoSearch (boolean): whether the full filename of this control file
#       should be looked up by looking into one of the folders specified by
#       Settings::setControlFolders(). If disabled, it will be assumed that
#       $name is a correct absolute or relative path. The default is enabled.
# `l`
sub addControlFile {
	my $name = shift;
	return _addFile($name, CONTROL_FILE_TYPE, @_);
}

##
# Settings::addTableFile(String name, options...)
#
# This is like Settings::addControlFile(), but for table files.
sub addTableFile {
	my $name = shift;
	return _addFile($name, TABLE_FILE_TYPE, @_);
}

##
# void Settings::removeFile(handle)
#
# Unregister a file that was registered by Settings::addControlFile()
# or Settings::addTableFile().
sub removeFile {
	my ($handle) = @_;
	
	lock ($files);
	
	$files->remove($files->get($handle));
}

##
# void loadByHandle(handle, [Function progressHandler])
# handle: A handle, as returned by Settings::addControlFile() or
#         Settings::addTableFile().
# progressHandler: A function which will be called when the filename
#                  resolved.
#
# Load or reload a data file as specified by the given data file handle.
# Throws FileNotFoundException if the file cannot be found in any of the
# search locations.
# Note that the data file loader function may throw additional exceptions.
#
# The progress handler function, if specified, will be called when the
# full filename of this data file has been resolved (that is, it has been
# found in one of the search locations), but before the file is actually
# loaded. It is useful for displaying progress reports.
#
# The progress handler function is called with two arguments: the filename,
# and the data file's type (which can be Settings::CONTROL_FILE_TYPE or
# Settings::TABLE_FILE_TYPE).
# For example:
# <pre class="example">
# Settings::loadByHandle($handle, sub {
#     my ($filename, $type) = @_;
#     print "$_[0] is about to be loaded!\n";
#     if ($type == Settings::CONTROL_FILE_TYPE) {
#         print "And it's a control file.\n";
#     } else {
#         print "And it's a table file.\n";
#     }
# });
# </pre>
sub loadByHandle {
	my ($handle, $progressHandler) = @_;
	
	assert(defined $handle) if DEBUG;
	my $object = $files->get($handle);
	assert(defined $object) if DEBUG;

	my $filename;
	if ($object->{autoSearch}) {
		if ($object->{type} == CONTROL_FILE_TYPE) {
			$filename = _findFileFromFolders($object->{name}, \@controlFolders);
		} else {
			$filename = _findFileFromFolders($object->{name}, \@tablesFolders);
		}
	} else {
		$filename = $object->{name};
	}
	if (!defined($filename) || ! -f $filename) {
		$filename = $object->{name} if (!defined $filename);
		if ($object->{type} == CONTROL_FILE_TYPE) {
			FileNotFoundException->throw(
				message => TF("Cannot load control file %s", $filename),
				filename => $filename);
		} else {
			FileNotFoundException->throw(
				message => TF("Cannot load table file %s", $filename),
				filename => $filename);
		}
	} elsif ($progressHandler) {
		$progressHandler->($filename, $object->{type});
	}

	if (ref($object->{loader}) eq 'ARRAY') {
		my @array = @{$object->{loader}};
		my $loader = shift @array;
		$loader->($filename, @array);
	} else {
		$object->{loader}->($filename);
	}
}

##
# void Settings::loadAll(regexp, [Function progressHandler])
#
# (Re)loads all registered data files whose name matches the given regular expression.
# This method follows the same contract as
# Settings::loadByHandle(), so see that method for parameter descriptions
# and exceptions.
sub loadByRegexp {
	my ($regexp, $progressHandler) = @_;
	my @result;
	
	lock ($files);
	
	foreach my $object (@{$files->getItems()}) {
		if ($object->{name} =~ /$regexp/) {
			loadByHandle($object->{index}, $progressHandler);
		}
	}
}

##
# void Settings::loadAll([Function progressHandler])
#
# (Re)loads all registered data files. This method follows the same contract as
# Settings::loadByHandle(), so see that method for parameter descriptions
# and exceptions.
sub loadAll {
	my ($progressHandler) = @_;
	
	lock ($files);
	
	foreach my $object (@{$files->getItems()}) {
		loadByHandle($object->{index}, $progressHandler);
	}
}

##
# int Settings::getSVNRevision()
#
# Return OpenKore's SVN revision number, or undef if that information cannot be retrieved.
sub getSVNRevision {
	my $f;
	if (open($f, "<", "$RealBin/.svn/entries")) {
		my $revision;
		eval {
			die unless <$f> =~ /^\d+$/;	# We only support the non-XML format
			die unless <$f> eq "\n";	# Empty string for current directory.
			die unless <$f> eq "dir\n";	# We expect a directory entry.
			$revision = <$f>;
			$revision =~ s/[\r\n]//g;
			undef $revision unless $revision =~ /^\d+$/;
		};
		close($f);
		return $revision;
	} else {
		return;
	}
}

sub loadSysConfig {
	_processSysConfig(0);
}

sub writeSysConfig {
	_processSysConfig(1);
}


##########################################
### CATEGORY: Data file lookup functions
##########################################

##
# String Settings::getControlFilename(String name)
# name: A valid base file name.
# Returns: A valid filename, or undef if not found.
# Ensures: if defined($result): -f $result
#
# Get a control file by its name. This file will be looked up
# in all possible locations, as specified by earlier calls
# to Settings::setControlFolders().
sub getControlFilename {
	lock (@controlFolders);
	
	return _findFileFromFolders($_[0], \@controlFolders);
}

##
# String Settings::getTableFilename(String name)
# name: A valid base file name.
# Ensures: if defined($result): -f $result
#
# Get a table file by its name. This file will be looked up
# in all possible locations, as specified by earlier calls
# to Settings::setTabblesFolders().
sub getTableFilename {
	lock (@tablesFolders);
	
	return _findFileFromFolders($_[0], \@tablesFolders);
}

sub getConfigFilename {
	lock ($config_file);
	
	if (defined $config_file) {
		return $config_file;
	} else {
		return getControlFilename("config.txt");
	}
}

sub setConfigFilename {
	my ($new_filename) = @_;
	my $current_filename = getConfigFilename();
	
	lock ($files);
	lock ($config_file);
	
	foreach my $object (@{$files->getItems()}) {
		if ($object->{name} eq $current_filename) {
			$object->{name} = $new_filename;
			last;
		}
	}
	$config_file = $new_filename;
}

sub getMonControlFilename {
	lock ($mon_control_file);
	
	if (defined $mon_control_file) {
		return $mon_control_file;
	} else {
		return getControlFilename("mon_control.txt");
	}
}

sub getItemsControlFilename {
	lock ($items_control_file);
	
	if (defined $items_control_file) {
		return $items_control_file;
	} else {
		return getControlFilename("items_control.txt");
	}
}

sub getShopFilename {
	lock ($shop_file);
	
	if (defined $shop_file) {
		return $shop_file;
	} else {
		return getControlFilename("shop.txt");
	}
}

sub getSysFilename {
	lock ($sys_file);
	
	if (defined $sys_file) {
		return $sys_file;
	} else {
		return getControlFilename("sys.txt");
	}
}

sub getRecvPacketsFilename {
	lock ($recvpackets_name);
	
	return getTableFilename($recvpackets_name || "recvpackets.txt");
}

sub setRecvPacketsName {
	my ($new_name) = @_;
	
	lock ($recvpackets_name);
	lock ($files);
	
	if ($recvpackets_name ne $new_name) {
		my $current_filename = getRecvPacketsFilename();
		foreach my $object (@{$files->getItems()}) {
			if ($object->{name} eq $current_filename) {
				$object->{name} = getTableFilename($new_name || "recvpackets.txt");
				last;
			}
		}
		$recvpackets_name = $new_name;
		return 1;
	} else {
		return undef;
	}
}


##########################
# Private methods
##########################

sub _assertNameIsBasename {
	my (undef, undef, $file) = File::Spec->splitpath($_[0]);
	if ($file ne $_[0]) {
		ArgumentException->throw("Name must be a valid file base name.");
	}
}

sub _findFileFromFolders {
	my ($name, $folders) = @_;
	_assertNameIsBasename($name);
	foreach my $dir (@{$folders}) {
		my $filename = File::Spec->catfile($dir, $name);
		if (-f $filename) {
			return $filename;
		}
	}
	return undef;
}

sub _addFile {
	my $name = shift;
	my $type = shift;
	my %options = @_;
	
	if (!$options{loader}) {
		ArgumentException->throw("The 'loader' option must be specified.");
	}
	my $object = {
		type => $type,
		name => $name,
		mustExist  => exists($options{mustExist}) ? $options{mustExist} : 1,
		autoSearch => exists($options{autoSearch}) ? $options{autoSearch} : 1,
		loader     => $options{loader}
	};
	$object->{index} = ObjectList::_findEmptyIndex($files->{OL_items});
	my $index = $files->add(bless($object, 'Settings::Handle'));
	return $index;
}

sub _processSysConfig {
	my ($writeMode) = @_;
	my ($f, @lines, %keysNotWritten);
	my $sysFile = getSysFilename();

	lock (%sys);

	return if (!$sysFile || !open($f, "<:utf8", $sysFile));
	
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

	if ($writeMode && open($f, ">:utf8", $sysFile)) {
		foreach my $line (@lines) {
			print $f "$line\n";
		}
		foreach my $key (keys %keysNotWritten) {
			print $f "$key $sys{$key}\n";
		}
		close $f;
	}
}

1;
