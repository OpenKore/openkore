package autoBreakTime;
use strict;

use Globals qw/%config $net/;
use Log qw/message debug/;
use Misc qw/relog chatLog/;
use Translation qw/T TF/;
use Utils qw/timeOut/;

my $hooks = Plugins::addHooks(
	['mainLoop_pre', \&mainLoop_pre],
);

Plugins::register('breakTime', 'config.autoBreakTime', sub { Plugins::delHooks($hooks) });

*AI::CoreLogic::processAutoBreakTime = sub {}; # for pre-2.1

our $timeout;
my @wdays = qw/sun mon tue wed thu fri sat/;

sub mainLoop_pre {
	return unless timeOut $timeout, 30;
	
	my (undef, $min, $hour, undef, undef, undef, $wday) = localtime;
	debug sprintf("autoBreakTime: %s %s:%s\n", $wdays[$wday], $hour, $min), __PACKAGE__, 2;
	for (my $i = 0 and my $prefix; exists $config{$prefix = "autoBreakTime_$i"}; $i++) {
		next unless $config{$prefix} =~ /^(?:all|$wdays[$wday])$/i;
		
		my ($now, $start, $stop) = map { sub { ($_[0]*60 + $_[1])*60 } ->(@$_) } [$hour, $min], map {[split /:/]} (
			$config{"${prefix}_startTime"}, $config{"${prefix}_stopTime"}
		);
		
		if ($now >= $start && ($now < $stop xor $stop < $start)) {
			my $duration = ($stop - $now) % (60*60*24);
			
			if ($net && $net->getState != Network::NOT_CONNECTED) {
				message TF("\nDisconnecting due to break time: %s to %s\n\n",
					$config{"${prefix}_startTime"}, $config{"${prefix}_stopTime"}
				), "system";
				chatLog("k", TF("*** Disconnected due to Break Time: %s to %s ***\n",
					$config{"${prefix}_startTime"}, $config{"${prefix}_stopTime"}
				));
			}
			
			relog $duration, 'SILENT';
			last
		}
	}
	
	$timeout = time;
}

1;
