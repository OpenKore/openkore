package AI::Slave::Mercenary;

use strict;
use base qw/AI::Slave/;

sub checkSkillOwnership { $_[1]->getOwnerType == Skill::OWNER_MERC }

1;
