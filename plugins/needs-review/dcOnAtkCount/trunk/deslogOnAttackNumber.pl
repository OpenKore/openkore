# Add in config.txt:
#    dcOnAtkCount_atkCount X
#    dcOnAtkCount_action ACTION
#
# - Replace X for number of attacks that the BOT can make the monsters;
# - Replace ACTION for a command that execute after exceed the limit of attacks
#   If nothing is specified the BOT will disconnect and it will return only when typed
#   in console "connect"
#
# Useful in GM testings that the suspicious character who
# is attacking a certain monster even though it is cured.
#
# Topic: http://forums.openkore.com/viewtopic.php?f=34&t=25155&p=74352#p74352
# ------------------
# Plugin by KeplerBR
# Idea by LututuiBR

package dcOnAtkCount;
	use strict;
	use warnings;
	use Plugins;
	use Log qw(warning);
	use Misc qw(offlineMode);
	use Globals;
	use Settings;
	use Network::PacketParser;

	# Register Plugin and Hooks
	Plugins::register("dcOnAtkCount", "Disconnect after attack X times a particular monster", \&on_unload);
		my $hooks = Plugins::addHooks(
			['packet/actor_action', \&action],
		);

	# On Unload code
	sub on_unload {
		Plugins::delHook("packet/actor_action", $hooks);
	}

	# On Action
	sub action {
	my ($self, $args) = @_;
		
	if ($args->{type} == ACTION_ATTACK) {
	my $monster = $monstersList->getByID($args->{targetID});
		if ($config{dcOnAtkCount_atkCount} && $monster->{numAtkFromYou} && $monster->{numAtkFromYou} >= $config{dcOnAtkCount_atkCount}) {
		warning "Security of plugin dcOnAtkCount activated!\n";
			if ($config{dcOnAtkCount_action}) {
				Commands::run($config{dcOnAtkCount_action});
			} else {
				offlineMode;
			}
		}
	}
	}

1;