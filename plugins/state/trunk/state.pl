#########################################################################
# This software is open source, licensed under the GNU General Public
# License, version 2.
# Basically, this means that you're allowed to modify and distribute
# this software. However, if you distribute modified versions, you MUST
# also distribute the source code.
# See http://www.gnu.org/licenses/gpl.html for the full license.
#########################################################################

package state;
use strict;
use Data::YAML::Writer;

use Globals;
use Utils;

my $hook = Plugins::addHook('mainLoop_post', sub {
	# Update state.yml
	if (timeOut($AI::Timeouts::stateUpdate, 0.5)) {
		my %state;
		my $f;
		$AI::Timeouts::stateUpdate = time;

		if ($field{name} && $net->getState() == Network::IN_GAME) {
			my $pos = calcPosition($char);
			%state = (
				connectionState => 'in game',
				fieldName => $field{name},
				fieldBaseName => $field{baseName},
				charName => $char->{name},
				x => $pos->{x},
				y => $pos->{y}
			);
			$state{actors} = {};
			foreach my $actor (@{$npcsList->getItems()}, @{$playersList->getItems()}, @{$monstersList->getItems()}, @{$slavesList->getItems()}) {
				my $actorType = $actor->{actorType};
				$state{actors}{$actorType} ||= [];
				push @{$state{actors}{$actorType}}, {
					x => $actor->{pos_to}{x},
					y => $actor->{pos_to}{y}
				};
			}
		} else {
			%state = (
				connectionState => 'not logged in'
			);
		}
		if ($bus && $bus->getState() == Bus::Client::CONNECTED()) {
			$state{bus}{host} = $bus->serverHost();
			$state{bus}{port} = $bus->serverPort();
			$state{bus}{clientID} = $bus->ID();
		}

		if (open($f, ">:utf8", "$Settings::logs_folder/state_".$config{'username'}.".yml")) {
			my $writer = new Data::YAML::Writer();
			$writer->write(\%state, $f);
			close $f;
		}
	}
});

Plugins::register('state', 'state.yml updater', sub {
	Plugins::delHook($hook);
});
