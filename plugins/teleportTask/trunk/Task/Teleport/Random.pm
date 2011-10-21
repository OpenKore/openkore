##
# MODULE DESCRIPTION: Random teleport task.
package Task::Teleport::Random;

use strict;

use Modules 'register';
use base 'Task::Teleport';
use Globals qw($char %config);

sub chatCommand { $config{teleportAuto_useChatCommand} }

sub getInventoryItem { $char->inventory->getByNameID(601) } # FIXME

sub hookArgs { {level => 1, emergency => $_[0]{emergency}} }

1;
