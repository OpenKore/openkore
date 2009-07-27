package Misc::Config;

use strict;

# Coro Support
use Coro;

use Globals qw(%overallAuth %config %timeout);
use Log qw(message warning error debug);
use Plugins;
use FileParsers;
use Exporter;
use base qw(Exporter);

our %EXPORT_TAGS = (
	config  => [qw(
		auth
		configModify
		bulkConfigModify
		setTimeout
		saveConfigFile)],
);

our @EXPORT = (
	@{$EXPORT_TAGS{config}},
);

#######################################
#######################################
### CATEGORY: Configuration modifiers
#######################################
#######################################

sub auth {
	my $user = shift;
	my $flag = shift;

	lock (%overallAuth);

	if ($flag) {
		message TF("Authorized user '%s' for admin\n", $user), "success";
	} else {
		message TF("Revoked admin privilages for user '%s'\n", $user), "success";
	}
	$overallAuth{$user} = $flag;
	writeDataFile(Settings::getControlFilename("overallAuth.txt"), \%overallAuth);
}

##
# void configModify(String key, String value, ...)
# key: a key name.
# value: the new value.
#
# Changes the value of the configuration option $key to $value.
# Both %config and config.txt will be updated.
#
# You may also call configModify() with additional optional options:
# `l
# - autoCreate (boolean): Whether the configuration option $key
#                         should be created if it doesn't already exist.
#                         The default is true.
# - silent (boolean): By default, output will be printed, notifying the user
#                     that a config option has been changed. Setting this to
#                     true will surpress that output.
# `l`
sub configModify {
	my $key = shift;
	my $val = shift;
	my %args;

	lock (%config);

	if (@_ == 1) {
		$args{silent} = $_[0];
	} else {
		%args = @_;
	}
	$args{autoCreate} = 1 if (!exists $args{autoCreate});

	Plugins::callHook('configModify', {
		key => $key,
		val => $val,
		additionalOptions => \%args
	});

	if (!$args{silent} && $key !~ /password/i) {
		my $oldval = $config{$key};
		if (!defined $oldval) {
			$oldval = "not set";
		}

		if (!defined $val) {
			message TF("Config '%s' unset (was %s)\n", $key, $oldval), "info";
		} else {
			message TF("Config '%s' set to %s (was %s)\n", $key, $val, $oldval), "info";
		}
	}
	if ($args{autoCreate} && !exists $config{$key}) {
		my $f;
		if (open($f, ">>", Settings::getConfigFilename())) {
			print $f "$key\n";
			close($f);
		}
	}
	$config{$key} = $val;
	saveConfigFile();
}

##
# bulkConfigModify (r_hash, [silent])
# r_hash: key => value to change
# silent: if set to 1, do not print a message to the console.
#
# like configModify but for more than one value at the same time.
sub bulkConfigModify {
	my $r_hash = shift;
	my $silent = shift;
	my $oldval;

	lock (%config);

	foreach my $key (keys %{$r_hash}) {
		Plugins::callHook('configModify', {
			key => $key,
			val => $r_hash->{$key},
			silent => $silent
		});

		$oldval = $config{$key};

		$config{$key} = $r_hash->{$key};

		if ($key =~ /password/i) {
			message TF("Config '%s' set to %s (was *not-displayed*)\n", $key, $r_hash->{$key}), "info" unless ($silent);
		} else {
			message TF("Config '%s' set to %s (was %s)\n", $key, $r_hash->{$key}, $oldval), "info" unless ($silent);
		}
	}
	saveConfigFile();
}

##
# saveConfigFile()
#
# Writes %config to config.txt.
sub saveConfigFile {
	lock (%config);
	FileParsers::writeDataFileIntact(Settings::getConfigFilename(), \%config);
}

sub setTimeout {
	my $timeout = shift;
	my $time = shift;

	lock (%timeout);

	message TF("Timeout '%s' set to %s (was %s)\n", $timeout, $time, $timeout{$timeout}{timeout}), "info";
	$timeout{$timeout}{'timeout'} = $time;
	writeDataFileIntact2(Settings::getControlFilename("timeouts.txt"), \%timeout);
}

