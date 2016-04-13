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


my $f;
open($f, "<", "unittest.dat");
binmode $f;

my ($attackID, $skillUseID, $accountID, $syncMapSync, $syncSync, $LastPaddedPacket);
my $i = 1;
our $fails = 0;

PP_SetPacket(" " x 512, 512, 0);

while (!eof($f)) {
	$attackID = readInt($f);
	$skillUseID = readInt($f);
	$accountID = readInt($f);
	$syncMapSync = readInt($f);
	$syncSync = readInt($f);

	PP_SetPacketIDs($attackID, $skillUseID);

	my $monID = readInt($f);
	my $flag = readInt($f);
	my $skillID = readInt($f);
	my $level = readInt($f);
	my $targetID = readInt($f);

	#print "Test $i\n";
	equals(readStr($f), generateSitStand(1)); # sit
	equals(readStr($f), generateSitStand(0)); # stand
	equals(readStr($f), generateAtk($monID, $flag));
	equals(readStr($f), generateSkillUse($skillID, $level, $targetID));
	$i++;
}
# 179 -> 176 -> 165 -> 162 -> 53 -> 7
print "Failures: $fails\n";
close($f);

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

sub readInt {
	my ($f) = @_;
	my ($buf, $len);
	read $f, $buf, 4;
	return unpack("V", $buf);
}

sub readStr {
	my ($f) = @_;
	my ($buf, $len);
	$len = readInt($f);
	read($f, $buf, $len);
	return $buf;
}

sub equals {
	if ($_[0] ne $_[1]) {
		print "Not equal\n";
		$fails++;
	}
}

1;
