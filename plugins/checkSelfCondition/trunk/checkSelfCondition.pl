package checkSelfCondition;

#
# This plugin is licensed under the GNU GPL
# Copyright 2005 by kaliwanagan
# -------------------------------------------------- 
#
# This plugin hooks into checkSelfCondition in Misc.pm
# Instead of doing a return, set $args->{return} to the supposed return value.

use strict;
use Time::HiRes qw(time usleep);
use IO::Socket;
use Text::ParseWords;
use Config;
eval "no utf8;";
use bytes;

use Globals;
use Modules;
use Settings;
use Log qw(message warning error debug);
use FileParsers;
use Interface;
use Network::Receive;
use Network::Send;
use Commands;
use Misc;
use Plugins;
use Utils;
use ChatQueue;

Plugins::register('checkSelfCondition', 'enable custom conditions', \&onUnload);
my $hooks = Plugins::addHooks(
	['checkSelfCondition', \&whenAtCoords, undef],
);

sub onUnload {
    Plugins::delHooks($hooks);
}

###
# whenAtCoords (x, y [, range])
#
# Returns true when character position is at the specified x, y coordinates.
# If range is specified, returns true if within x +/- range and y +/- range.
#
# Example usage:
#
# useSelf_skill teleport {
# 	lvl 1
# 	whenAtCoords 34, 100, 2
# 	# teleport when at coordinates 34, 100 plus or minus 2 blocks
# 	timeout 3
# }
sub whenAtCoords {
	my ($hookName, $args) = @_;
	my $prefix = $args->{prefix};
	
	return if ($config{$prefix."_whenAtCoords"} eq '');
	my %range;
	($range{'x'}, $range{'y'}, $range{'range'}) = split / *, */, $config{$prefix."_whenAtCoords"};
	
	my $pos = main::calcPosition($char);
	my $inRange = (($pos->{'x'} <= ($range{'x'} + $range{'range'})) &&
		($pos->{'x'} >= ($range{'x'} - $range{'range'})) &&
		($pos->{'y'} <= ($range{'y'} + $range{'range'})) &&
		($pos->{'y'} >= ($range{'y'} - $range{'range'})));
	undef %range;
	$args->{return} = $inRange;
}

return 1;