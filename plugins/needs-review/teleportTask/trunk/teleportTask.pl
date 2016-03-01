package teleportTask;

use strict;
use lib $Plugins::current_plugin_folder;

use Globals qw($taskManager);
use Log qw(warning);

my %tasks = qw(1 Task::Teleport::Random 2 Task::Teleport::Respawn);

use Task::Teleport::Random;
use Task::Teleport::Respawn;

my $Version = '0.01';

# preload modules which use useTeleport
use AI::Attack ();
use AI::CoreLogic ();
use AI::Slave ();
use ChatQueue ();
use Commands ();
use Misc ();
use Task::MapRoute ();
use Task::Route ();

*AI::Attack::useTeleport =
*AI::CoreLogic::useTeleport =
*AI::Slave::useTeleport =
*ChatQueue::useTeleport =
*Commands::useTeleport =
*Misc::useTeleport =
*Task::MapRoute::useTeleport =
*Task::Route::useTeleport =
*main::useTeleport =
sub {
	my ($use_lvl, undef, $emergency) = @_;
	
	$taskManager->add(
		$tasks{$use_lvl}->new(emergency => $emergency)
	);
};
