package webMonitorPlugin;

# webMonitorV2 - Web interface to monitor yor bots
# Copyright (C) 2012 BonScott
# thanks to iMikeLance
#
# How use:
# Add in your config.txt
#
# webPort XXXX
# 
# Where XXXX is a number of your choice. Ex:
# webPort 1020
# 
# Set only one port for each bot. For more details, visit:
# [OpenKoreBR]
#
# [OpenKore International]
#
#############################################

use strict;
use Plugins;
use Settings;
use FindBin qw($RealBin);
use lib "$RealBin/plugins/webMonitor";
use webMonitorServer;
use chatLogWebMonitor;
use logConsole;
use Globals;
use Log qw(warning message error);

# Initialize some variables as well as plugin hooks

my $port;
my $bind;
my $webserver;

Plugins::register('webMonitor', 'Web interface to monitor yor bots', \&Unload);
my $hook = Plugins::addHooks(['AI_post', \&mainLoop], ['start3', \&post_loading]);

##### Seting webServer after of plugins loads
sub post_loading {
	$port = $config{webPort};
	$bind = "localhost";
    warning "webPort: ".$config{webPort}."\n";
	print "$config{webPort}\n";
	$webserver = new webMonitorServer($port, $bind);
}
sub Unload {
	Plugins::delHooks($hook);
}
sub mainLoop {
	return if !$webserver;
	$webserver->iterate;
}

1;