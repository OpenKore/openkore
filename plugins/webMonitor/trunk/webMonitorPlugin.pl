package webMonitorPlugin;

# webMonitor - an HTTP interface to monitor bots
# Copyright (C) 2006 kaliwanagan
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#############################################
# [PT-BR] Projeto recontinuado em 2012 por KeplerBR
#  Agradecimentos ao llbranco, ao iMike e ao Swapmwalker
# Tradução de PT-BR para EN por Swapmwalker
# [ENG] Project continued on 2012 by KeplerBR
#  Thanks to llbranco, iMike and Swapmwalker
# PT-BR to EN translation by Swapmwalker
#
# [PT-BR] Tópico no fórum brasileiro: http://openkore.com.br/index.php?/topic/2749-plugin-webmonitor/
# [EN] Topic in the international forum: http://forums.openkore.com/viewtopic.php?f=36&t=17768&p=63194


use strict;
use Plugins;
use Settings;
use FindBin qw($RealBin);
use lib "$RealBin/plugins/webMonitor";
use webMonitorServer;
use chatLogWebMonitor;
use richLogWebMonitor;

###
# Initialize some variables as well as plugin hooks
#
my $port = 1025;
my $bind = "localhost";
my $webserver = new webMonitorServer($port, $bind);

Plugins::register('webMonitor', 'an HTTP interface to monitor bots', \&Unload);
my $hook = Plugins::addHook('AI_post', \&mainLoop);

sub Unload {
	Plugins::delHook('AI_post', $hook);
}

###
# Main loop
#
sub mainLoop {
	$webserver->iterate;
}

1;