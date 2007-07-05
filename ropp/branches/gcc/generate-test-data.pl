use strict;
use Time::HiRes qw(time);
use Win32::API;

srand();

# Loading ropp.dll and importing functions
Win32::API->Import('ropp', 'PP_CreateSitStand', 'PN' ,'N') or die "Can't import PP_CreateSitStand\n$!";
Win32::API->Import('ropp', 'PP_CreateAtk', 'PNN' ,'N') or die "Can't import PP_CreateAtk\n$!";
Win32::API->Import('ropp', 'PP_CreateSkillUse', 'PNNN' ,'N') or die "Can't import PP_CreateSkillUse\n$!";

Win32::API->Import('ropp', 'PP_SetMapSync', 'N') or die "Can't import PP_SetMapSync\n$!";
Win32::API->Import('ropp', 'PP_SetSync', 'N') or die "PP_SetSync\n$!";
Win32::API->Import('ropp', 'PP_SetAccountId', 'N') or die "Can't import PP_SetAccountId\n$!";
Win32::API->Import('ropp', 'PP_SetPacketIDs', 'NN') or die "Can't import PP_PP_SetPacketIDs\n$!";
Win32::API->Import('ropp', 'PP_SetPacket', 'PNN') or die "Can't import PP_SetPacket\n$!";

Win32::API->Import('ropp', 'PP_DecodePacket', 'PN') or die "Can't import PP_DecodePacket\n$!";
Win32::API->Import('ropp', 'PP_GetKey', 'N' ,'N') or die "Can't import PP_GetKey\n$!";

use constant MAX_SHORT => 65536;

my $f;
open($f, ">", "unittest.dat");
binmode $f;

my ($attackID, $skillUseID, $accountID, $syncMapSync, $syncSync, $LastPaddedPacket);

PP_SetPacket(" " x 512, 512, 0);

for (my $i = 0; $i < 500; $i++) {
	$attackID = int(rand(MAX_SHORT) & 0xFFFF);
	$skillUseID = int(rand(MAX_SHORT) & 0xFFFF);
	$accountID = randomInt();
	if (int(rand(2)) == 1) {
		# For some reason we need this, or algorithm 15
		# will never be unit tested.
		$accountID++;
	}
	$syncMapSync = randomInt();
	$syncSync = randomInt();
	print $f pack("V*", $attackID, $skillUseID, $accountID, $syncMapSync, $syncSync);

	PP_SetPacketIDs($attackID, $skillUseID);

	my $monID = ();
	my $flag = int rand(10);
	my $skillID = int rand(100);
	my $level = int rand(11);
	my $targetID = randomInt();
	print $f pack("V*", $monID, $flag, $skillID, $level, $targetID);
	
	printStr($f, generateSitStand(1)); # sit
	printStr($f, generateSitStand(0)); # stand
	printStr($f, generateAtk($monID, $flag));
	printStr($f, generateSkillUse($skillID, $level, $targetID));
}

close($f);

sub randomInt {
	return int((rand(MAX_SHORT) & 0xFFFF) * MAX_SHORT + (rand(MAX_SHORT) & 0xFFFF));
}

sub setHashData {
	PP_SetAccountId($accountID);
	PP_SetMapSync($syncMapSync);
	PP_SetSync($syncSync);
}

sub generateSitStand {
	my ($sit) = @_;
	my $packet = " " x 256;
	setHashData();
	my $len = PP_CreateSitStand($packet, $sit);
	return substr($packet, 0, $len);
}

sub generateAtk {
	my ($targetId, $flag) = @_;
	my $packet = " " x 256;
	setHashData();
	my $len = PP_CreateAtk($packet, $targetId, $flag);
	return substr($packet, 0, $len);
}

sub generateSkillUse {
	my ($skillId, $skillLv, $targetId) = @_;
	my $packet = " " x 256;
	setHashData();
	my $len = PP_CreateSkillUse($packet, $skillId, $skillLv, $targetId);
	return substr($packet, 0, $len);
}

sub printStr {
	my ($f, $str) = @_;
	print $f pack("V", length($str));
	print $f $str;
}

1;
