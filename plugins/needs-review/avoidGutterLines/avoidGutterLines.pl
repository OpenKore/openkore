#############################################################################
# avoidGutterLines plugin by imikelance										
#																			
# Openkore: http://openkore.com/											
# Openkore Brazil: http://openkore.com.br/										
#																																				
# 05:15 sexta-feira, 6 de janeiro de 2012
#
# Usage:
#	# bRO: Impacto de Tyr
#	attackSkillSlot Bowling Bash {
#		avoidGutterLines 1
#	}
#																			
# This source code is licensed under the									
# GNU General Public License, Version 3.									
# See http://www.gnu.org/licenses/gpl.html									
#############################################################################
package avoidGutterLines;

use strict;
use Config;
eval "no utf8;";

use Globals;
use Log qw(message warning error debug);
use Misc;
use Plugins;

Plugins::register('avoidGutterLines', 'avoid using bowling bash inside gutterlines', \&onUnload);
my $hooks = Plugins::addHooks(
	['avoidGutterLines', \&avoidGutterLines, undef],
);

sub onUnload {
    Plugins::delHooks($hooks);
}

sub avoidGutterLines {
	my (undef, $args) = @_;
	my $prefix = $args->{prefix};
	if ($config{$prefix."_avoidGutterLines"}) {
        my $pos = main::calcPosition($char);
			if ($pos->{x}%40 <= 4 || $pos->{y}%40 <= 4) {
			$args->{return} = 0;
		}
    }
}

return 1;