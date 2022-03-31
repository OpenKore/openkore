#########################################################################
#  OpenKore - Padded packets emulator
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#########################################################################

# See src/auto/XSTools/PaddedPackets/README.TXT for more information.
# Parts of this module is implemented in src/auto/XSTools/PaddedPackets/PaddedPackets.xs

package Network::PaddedPackets;

use strict;
use XSTools;

use Modules 'register';
use Globals qw($masterServer $accountID $syncMapSync $syncSync %config);
use Plugins;

XSTools::bootModule("Network::PaddedPackets");


our ($enabled, $attackID, $skillUseID);

sub init {
	Plugins::addHook('Network::serverConnect/master', \&reset);
	Plugins::addHook('map_loaded', \&reset);
}

sub reset {
	if ($masterServer) {
		$enabled = $masterServer->{paddedPackets};
		$attackID   = hex($masterServer->{paddedPackets_attackID}) || 0x89;
		$skillUseID = hex($masterServer->{paddedPackets_skillUseID}) || 0x113;
	} else {
		$enabled = 0;
		$attackID = 0x89;
		$skillUseID = 0x113;
	}
	setPacketIDs($attackID, $skillUseID);
	$attackID   = sprintf('%04X', $attackID);
	$skillUseID = sprintf('%04X', $skillUseID);
}


######################################


sub setHashData {
	setAccountId(unpack("L1", $accountID));
	setMapSync(unpack("L1", $syncMapSync));
	setSync(unpack("L1", $syncSync));
}

sub generateSitStand {
	my ($sit) = @_;
	my $packet = " " x 256;
	setHashData();
	my $len = createSitStand($packet, $sit);
	return substr($packet, 0, $len);
}

sub generateAtk {
	my ($targetId, $flag) = @_;
	my $packet = " " x 256;
	setHashData();
	my $len = createAtk($packet, unpack("L1", $targetId), $flag);
	return substr($packet, 0, $len);
}

sub generateSkillUse {
	my ($skillId, $skillLv, $targetId) = @_;
	my $packet = " " x 256;
	setHashData();
	my $len = createSkillUse($packet, $skillId, $skillLv, unpack("L1", $targetId));
	return substr($packet, 0, $len);
}

1;
