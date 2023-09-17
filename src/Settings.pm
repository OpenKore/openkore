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
use lib 'src/deps';
use lib 'src';
use Exporter;
use base qw(Exporter);
use Carp::Assert;
use FindBin qw($RealBin);
use Getopt::Long;
use File::Path qw/make_path/;
use File::Spec;
use Translation qw(T TF);
use Utils::ObjectList;
use Utils::Exceptions;
use List::MoreUtils qw( uniq );
use Globals qw( %config @servers );

use enum qw(CONTROL_FILE_TYPE TABLE_FILE_TYPE);


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
our $VERSION = 'what-will-become-2.1';
# Translation Comment: Version String
#our $SVN = T(" (SVN Version) ");
our $WEBSITE = 'https://openkore.com/';
# Translation Comment: Version String
our $versionText = "*** $NAME ${VERSION} ( version " . getRevisionString() . ' ) - ' . T("Custom Ragnarok Online client") . " ***\n***   $WEBSITE   ***\n";
our $welcomeText = TF("Welcome to %s.", $NAME);


# Data file folders.
our @controlFolders;
our @tablesFolders;
our @pluginsFolders;
# The registered data files.
our $files;
# System configuration.
our %sys;
our %options;

our $fields_folder;
our $logs_folder;
our $maps_folder;

our $config_file;
our $mon_control_file;
our $items_control_file;
our $shop_file;
our $buyer_shop_file;
our $recvpackets_name;

# The base log file names, as set by the command line.
our $base_chat_log_file;
our $base_console_log_file;
our $base_storage_log_file;
our $base_shop_log_file;
our $base_monster_log_file;
our $base_player_log_file;
our $base_item_log_file;
our $base_dead_log_file;

# The final log file names, as modified by logAppendUsername, etc.
our $chat_log_file;
our $console_log_file;
our $storage_log_file;
our $shop_log_file;
our $monster_log_file;
our $player_log_file;
our $item_log_file;
our $dead_log_file;

our $sys_file;

our $interface;
our $lockdown;
our $starting_ai;
our $command;
our $no_connect;


my $pathDelimiter = ($^O eq 'MSWin32') ? ';' : ':';

sub MODINIT {
	$files = new ObjectList();
}
use Modules 'register';
our @EXPORT_OK = qw(%sys %options);


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
	# my %options;

	undef $fields_folder;
	undef $logs_folder;
	undef $maps_folder;
	undef $config_file;
	undef $mon_control_file;
	undef $items_control_file;
	undef $shop_file;
	undef $buyer_shop_file;
	undef $chat_log_file;
	undef $console_log_file;
	undef $storage_log_file;
	undef $sys_file;
	undef $interface;
	undef $lockdown;

	# Allow plugins to have their own command line options.
	Getopt::Long::Configure( 'pass_through' );

	GetOptions(
		'control=s',		\$options{control},
		'tables=s',			\$options{tables},
		'plugins=s',		\$options{plugins},
		'fields=s',			\$fields_folder,
		'logs=s',			\$logs_folder,
		'maps=s',			\$maps_folder,

		'config=s',			\$config_file,
		'mon_control=s',	\$mon_control_file,
		'items_control=s',	\$items_control_file,
		'shop=s',			\$shop_file,
		'buyer_shop=s',		\$buyer_shop_file,
		'chat-log=s',		\$base_chat_log_file,
		'console-log=s',	\$base_console_log_file,
		'storage-log=s',	\$base_storage_log_file,
		'sys=s',			\$sys_file,

		'interface=s',		\$interface,
		'lockdown',			\$lockdown,
		'ai=s',				\$starting_ai,
		'command=s',		\$command,
		'help',				\$options{help},
		'version|v',		\$options{version},

		'no-connect',		\$no_connect
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
	$maps_folder = "map" unless defined $maps_folder;
	$base_chat_log_file ||= File::Spec->catfile($logs_folder, "chat.txt");
	$base_console_log_file ||= File::Spec->catfile($logs_folder, "console.txt");
	$base_storage_log_file ||= File::Spec->catfile($logs_folder, "storage.txt");
	$base_shop_log_file = File::Spec->catfile($logs_folder, "shop_log.txt");
	$base_monster_log_file = File::Spec->catfile($logs_folder, "monster_log.txt");
	$base_player_log_file = File::Spec->catfile($logs_folder, "player_log.txt");
	$base_item_log_file = File::Spec->catfile($logs_folder, "item_log.txt");
	$base_dead_log_file = File::Spec->catfile($logs_folder, "dead_log.txt");
	update_log_filenames();

	if (!defined $interface) {
		if ($ENV{OPENKORE_DEFAULT_INTERFACE} && $ENV{OPENKORE_DEFAULT_INTERFACE} ne "") {
			$interface = $ENV{OPENKORE_DEFAULT_INTERFACE};
		} else {
			$interface = "Console"
		}
	}
	if ($starting_ai) {
		$AI::AI = AI::AUTO()   if $starting_ai =~ /^(on|auto)$/;
		$AI::AI = AI::MANUAL() if $starting_ai =~ /^manual$/;
		$AI::AI = AI::OFF()    if $starting_ai =~ /^off$/;
	}

	return 0 if ($options{help});
	return 0 if ($options{version});
	if (! -d $logs_folder) {
		#if (!mkdir($logs_folder)) {
		if (! make_path($logs_folder)) {
			IOException->throw("Unable to create folder $logs_folder ($!)");
		}
	}
	return 1;
}

sub update_log_filenames {
	my @logAppend;
	push @logAppend, "_$config{username}_$config{char}" if $config{logAppendUsername} && $config{username};
	push @logAppend, "_$servers[$config{server}]{name}" if $config{logAppendServer}   && $config{server};
	my $logAppend = join '', @logAppend;

	$chat_log_file    = substr( $base_chat_log_file,    0, length( $base_chat_log_file ) - 4 ) . "$logAppend.txt";
	$console_log_file = substr( $base_console_log_file, 0, length( $base_console_log_file ) - 4 ) . "$logAppend.txt";
	$storage_log_file = substr( $base_storage_log_file, 0, length( $base_storage_log_file ) - 4 ) . "$logAppend.txt";
	$shop_log_file    = substr( $base_shop_log_file,    0, length( $base_shop_log_file ) - 4 ) . "$logAppend.txt";
	$monster_log_file = substr( $base_monster_log_file, 0, length( $base_monster_log_file ) - 4 ) . "$logAppend.txt";
	$player_log_file = substr( $base_player_log_file,   0, length( $base_player_log_file ) - 4 ) . "$logAppend.txt";
	$item_log_file    = substr( $base_item_log_file,    0, length( $base_item_log_file ) - 4 ) . "$logAppend.txt";
	$dead_log_file    = substr( $base_dead_log_file,    0, length( $base_dead_log_file ) - 4 ) . "$logAppend.txt";
}

##
sub parseServerType {
	my $type = shift;

	my $mode = 0; # Mode is Old by Default
	my $class = "ServerType0";
	my $param;

	# Remove Blanks
	$type =~ s/^\s*//;
	$type =~ s/\s*$//;

	$type = 0 if $type eq '';

	# Type checking
	if ($type =~ /^([0-9_]+)/) {
		# Old ServerType
		($type) = $type =~ /^([0-9_]+)/;
		$class = "ServerType" . $type;
	} else {
		# New ServerType based on Server name
		($class, $param) = $type =~ /^([a-zA-Z0-9]+)(?:_([a-zA-Z0-9_]+))?/;
		$mode = 1;
	}

	return ($mode, $class, $param);
}

##
# String Settings::getUsageText()
#
# Return the usage text that should be displayed.
sub getUsageText {
	my $text = qq{
		Usage: openkore.pl [options...]

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
		--console-log=FILENAME    Which console log file to use.
		--storage-log=FILENAME    Which storage log file to use.
		--sys=FILENAME            Which sys.txt to use.

		Other options:
		--interface=NAME          Which interface to use at startup.
		--lockdown                Disable potentially insecure features.
		--ai                      Starting AI mode (on, manual, off) (default: on)
		--command=COMMAND         Initial command to place on the AI queue
		--help                    Displays this help message.
		--version                 Displays the program version.

		Developer options:
		--no-connect              Do not connect to any servers.
	};
	my $data = { options => [] };
	Plugins::callHook( usage => $data );
	if ( @{ $data->{options} } ) {
		foreach my $plugin ( uniq sort map { $_->{plugin} || 'unknown' } @{ $data->{options} } ) {
			$text .= "\nOptions for the '$plugin' plugin:\n";
			foreach ( grep { $plugin eq ( $_->{plugin} || 'unknown' ) } @{ $data->{options} } ) {
				$text .= sprintf "%-2s %-22s %s\n", $_->{short} || '', $_->{long} || '', $_->{description} || '';
			}
		}
	}
	$text =~ s/\n*$/\n/s;
	$text =~ s/^\n//s;
	$text =~ s/^\t\t?//gm;
	return $text;
}

##
# void Settings::setControlFolders(Array<String> folders)
#
# Set the folders in which to look for control files.
sub setControlFolders {
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
	@tablesFolders = @_;
}

# FIXME: should be f(Array<String> folders), not f(String folders)?
sub addTablesFolders {
	if (defined(my $root = getTablepackFolder())) {
		unshift @tablesFolders, grep -d, map { File::Spec->catdir($root, $_) } split ';', shift
	}
}

sub getTablesFolders {
	return @tablesFolders;
}

# undef if there is folder(s) specified in --tables, otherwise tables path
# TODO: way to reconfigure only that path? (by now it's always 'tables')
sub getTablepackFolder {
	return $tablesFolders[$#tablesFolders];
}

##
# void Settings::setPluginsFolders(Array<String> folders)
#
# Set the folders in which to look for plugins.
sub setPluginsFolders {
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
	assert(defined $handle, "Can't load by handle with undefined handle") if DEBUG;
	my $object = $files->get($handle);
	assert(defined $object, "Can't retrieve file in list from handle") if DEBUG;

	my $filename;
	my $internalFilename = $object->{internalName} || $object->{name};

	#hooks of type 'pre_load_' make it possible to change the filename before openkore searches for it (this filename must contain file name and file path)
	my $pre_load = {internalFilename => $internalFilename, filename => $filename};
	Plugins::callHook('pre_load_'.$internalFilename, $pre_load);
	if ($pre_load->{return}) {
		 $filename = $pre_load->{filename};
	} elsif ($object->{autoSearch} && $object->{type} == CONTROL_FILE_TYPE) {
		$filename = _findFileFromFolders($object->{name}, \@controlFolders);
	} elsif ($object->{autoSearch} && $object->{type} == TABLE_FILE_TYPE) {
		$filename = _findFileFromFolders($object->{name}, \@tablesFolders);
	} elsif (!$object->{autoSearch}) {
		$filename = $object->{name};
	}

	# If we should auto-create this file, do so.
	# Prefer the default folder, which is the last folder in the list of folders.
	if ( ( !defined( $filename ) || !-f $filename ) && $object->{createIfMissing} ) {
		my @dirs = $object->{type} == CONTROL_FILE_TYPE ? @controlFolders : @tablesFolders;
		my $dir = ( grep { -d $_ } @dirs )[-1];
		my $fp;
		if ( $dir && open $fp, '>>', "$dir/$object->{name}" ) {
			close $fp;
			$filename = "$dir/$object->{name}";
		}
	}

	if (!defined($filename) || ! -f $filename) {
		return unless $object->{mustExist};

		$filename = $object->{name} || $object->{internalName} if (!defined $filename);
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

	#hooks of type 'load_' make it possible to change file loader so plugins can change the parsing method of a file
	#hooks of type 'pos_load_' make it possible to manipulate the extracted data after the parsing is over for a given file or simply do something when it ends.
	my $load = {filename => $filename};
	my $pos_load = {filename => $filename};
	if (ref($object->{loader}) eq 'ARRAY') {
		my @array = @{$object->{loader}};
		my $loader = shift @array;
		$load->{args} = \@array;
		Plugins::callHook('load_'.$internalFilename, $load);
		unless ($load->{return}) {
			$loader->($filename, @array);
		}
		$pos_load->{args} = \@array;
		Plugins::callHook('pos_load_'.$internalFilename, $pos_load);
	} else {
		Plugins::callHook('load_'.$internalFilename, $load);
		unless ($load->{return}) {
			$object->{loader}->($filename);
		}
		Plugins::callHook('pos_load_'.$internalFilename, $pos_load);
	}

	# Call onLoaded Handler after file beeng loaded without exceptions.
	# onLoaded must be REF to CODE (sub, function, etc.)
	if (defined $object->{onLoaded}) {
		if (ref($object->{onLoaded}) eq 'CODE') {
			$object->{onLoaded}->($filename);
		}
	}
	$object->{path} = $filename if defined $filename;
}

##
# void Settings::loadByRegexp(regexp, [Function progressHandler])
#
# Calls 'loadFiles' with the list of registered data files whose name matches the given regular expression.
sub loadByRegexp {
	my ($regexp, $progressHandler) = @_;
	loadFiles([grep { $_->{path} =~ /$regexp/ } @{$files->getItems}], $progressHandler);
}

##
# void Settings::loadAll([Function progressHandler])
#
# Calls 'loadFiles' with the list of all registered data files.
sub loadAll {
	my ($progressHandler) = @_;
	loadFiles($files->getItems, $progressHandler);
}

##
# void Settings::loadFiles(files, [Function progressHandler])
#
# (Re)loads all registered data files given in 'files'.
# Use this method to load a specific list of files.
# This method follows the same contract as
# Settings::loadByHandle(), so see that method for parameter descriptions
# and exceptions.
sub loadFiles {
	my ($files, $progressHandler) = @_;

	Plugins::callHook('preloadfiles', {files => $files});

	my $i = 1;
	foreach my $object (@$files) {
		Plugins::callHook('loadfiles', {
			files => $files,
			current => $i
		});
		loadByHandle($object->{index}, $progressHandler);
		$i++;
	}

	Plugins::callHook('postloadfiles', {files => $files});
}

##
# str Settings::getRevisionString()
#
# Return OpenKore's revision as a string to be displayed to the user.
sub getRevisionString {
	my @revisions;

	# The best and most accurate version is the git commit sha, if available.
	my $git = getGitRevision();
	if ( $git ) {
		push @revisions, "git:$git";
	}

	# "Download ZIP" on github sets the file creation times to (around) the
	# last time a commit was uploaded to github. This can help make a good
	# guess about what version is in use.
	my $time = ( stat( __FILE__ ) )[10] || ( stat( _ ) )[9];
	if ( $time ) {
		my ( $sec, $min, $hour, $day, $month, $year ) = gmtime( $time );
		push @revisions, sprintf 'ctime:%04d_%02d_%02d', $year + 1900, $month + 1, $day;
	}

	push @revisions, '?' if !@revisions;

	join ' ', @revisions;
}

##
# int Settings::getGitRevision()
#
# Return OpenKore's Git revision number, or undef if that information cannot be retrieved.
sub getGitRevision {
	use Git;
	my $git = Git::detect_git( $RealBin );
	return if !$git;
	my ( $sec, $min, $hour, $day, $month, $year ) = gmtime( $git->{timestamp} );
	sprintf '%7.7s_%04d-%02d-%02d', $git->{sha}, $year + 1900, $month + 1, $day;
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
	return _findFileFromFolders($_[0], \@controlFolders);
}

##
# String Settings::getTableFilename(String name)
# name: A valid base file name.
# Ensures: if defined($result): -f $result
#
# Get a table file by its name. This file will be looked up
# in all possible locations, as specified by earlier calls
# to Settings::setTablesFolders().
sub getTableFilename {
	return _findFileFromFolders($_[0], \@tablesFolders);
}

sub getConfigFilename {
	if (defined $config_file) {
		return $config_file;
	} else {
		return getControlFilename("config.txt");
	}
}

sub setConfigFilename {
	my ($new_filename) = @_;
	my $current_filename = getConfigFilename();
	foreach my $object (@{$files->getItems()}) {
		if ($object->{name} eq $current_filename) {
			$object->{name} = $new_filename;
			last;
		}
	}
	$config_file = $new_filename;
}

sub getMonControlFilename {
	if (defined $mon_control_file) {
		return $mon_control_file;
	} else {
		return getControlFilename("mon_control.txt");
	}
}

sub setMonControlFilename {
	my ($new_filename) = @_;
	my $current_filename = getMonControlFilename();
	foreach my $object (@{$files->getItems()}) {
		if ($object->{name} eq $current_filename) {
			$object->{name} = $new_filename;
			last;
		}
	}
	$mon_control_file = $new_filename;
}

sub getItemsControlFilename {
	if (defined $items_control_file) {
		return $items_control_file;
	} else {
		return getControlFilename("items_control.txt");
	}
}

sub setItemsControlFilename {
	my ($new_filename) = @_;
	my $current_filename = getItemsControlFilename();
	foreach my $object (@{$files->getItems()}) {
		if ($object->{name} eq $current_filename) {
			$object->{name} = $new_filename;
			last;
		}
	}
	$items_control_file = $new_filename;
}

sub getShopFilename {
	if (defined $shop_file) {
		return $shop_file;
	} else {
		return getControlFilename("shop.txt");
	}
}

sub getBuyerShopFilename {
	if (defined $buyer_shop_file) {
		return $buyer_shop_file;
	} else {
		return getControlFilename("buyer_shop.txt");
	}
}

sub setShopFilename {
	my ($new_filename) = @_;
	my $current_filename = getShopFilename();
	foreach my $object (@{$files->getItems()}) {
		if ($object->{name} eq $current_filename) {
			$object->{name} = $new_filename;
			last;
		}
	}
	$shop_file = $new_filename;
}

sub setBuyerShopFilename {
	my ($new_filename) = @_;
	my $current_filename = getBuyerShopFilename();
	foreach my $object (@{$files->getItems()}) {
		if ($object->{name} eq $current_filename) {
			$object->{name} = $new_filename;
			last;
		}
	}
	$buyer_shop_file = $new_filename;
}


sub getSysFilename {
	if (defined $sys_file) {
		return $sys_file;
	} else {
		return getControlFilename("sys.txt");
	}
}

sub getRecvPacketsFilename {
	return ($recvpackets_name || "recvpackets.txt");
}

sub setRecvPacketsName {
	my ($new_name) = @_;
	if ($recvpackets_name ne $new_name) {
		my $current_filename = getRecvPacketsFilename();
		foreach my $object (@{$files->getItems()}) {
			if ($object->{name} eq $current_filename) {
				$object->{name} = ($new_name || "recvpackets.txt");
				$recvpackets_name = $object->{name};
				return 1;
				# last;
			}
		}
	}
	return undef;
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
		createIfMissing => $options{createIfMissing},
		autoSearch => exists($options{autoSearch}) ? $options{autoSearch} : 1,
		onLoaded => exists($options{onLoaded}) ? $options{onLoaded} : undef,
		internalName => exists($options{internalName}) ? $options{internalName} : undef,
		loader     => $options{loader}
	};
	my $index = $files->add(bless($object, 'Settings::Handle'));
	$object->{index} = $index;
	return $index;
}

sub _processSysConfig {
	my ($writeMode) = @_;
	my ($f, @lines, %keysNotWritten);
	my $sysFile = getSysFilename();
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
