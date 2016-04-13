##
# MODULE DESCRIPTION: Respawn teleport task.
package Task::Teleport::Respawn;

use strict;

use Modules 'register';
use base 'Task::Teleport';
use Globals qw($char %config);

sub chatCommand { $config{saveMap_warpChatCommand} }

sub getInventoryItem { $char->inventory->getByNameID(602) } # FIXME

sub hookArgs { {level => 2, emergency => $_[0]{emergency}} }

1;
