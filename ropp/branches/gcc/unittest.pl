use strict;
use Time::HiRes qw(time);
use Win32::API;

srand();

# Loading ropp.dll and importing functions
Win32::API->Import('ropp', 'CreateSitStand', 'PN' ,'N') or die "Can't import CreateSitStand\n$!";
Win32::API->Import('ropp', 'CreateAtk', 'PNN' ,'N') or die "Can't import CreateAtk\n$!";
Win32::API->Import('ropp', 'CreateSkillUse', 'PNNN' ,'N') or die "Can't import CreateSkillUse\n$!";

Win32::API->Import('ropp', 'SetMapSync', 'N') or die "Can't import SetMapSync\n$!";
Win32::API->Import('ropp', 'SetSync', 'N') or die "SetSync\n$!";
Win32::API->Import('ropp', 'SetAccountId', 'N') or die "Can't import SetAccountId\n$!";
Win32::API->Import('ropp', 'SetPacketIDs', 'NN') or die "Can't import SetPacketIDs\n$!";
Win32::API->Import('ropp', 'SetPacket', 'PNN') or die "Can't import SetPacket\n$!";

Win32::API->Import('ropp', 'DecodePacket', 'PN') or die "Can't import DecodePacket\n$!";
Win32::API->Import('ropp', 'GetKey', 'N' ,'N') or die "Can't import GetKey\n$!";

use constant MAX_INT => 4294967296;

my $f;
open($f, "<", "unittest.dat");
binmode $f;

my ($attackID, $skillUseID, $accountID, $syncMapSync, $syncSync, $LastPaddedPacket);
my $i = 1;
our $fails = 0;
while (!eof($f)) {
	$attackID = readInt($f);
	$skillUseID = readInt($f);
	$accountID = readInt($f);
	$syncMapSync = readInt($f);
	$syncSync = readInt($f);

	SetPacketIDs($attackID, $skillUseID);

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
# 179 -> 176 -> 165
print "Failures: $fails\n";
close($f);

sub setHashData {
	SetAccountId(unpack("L1", $accountID));
	SetMapSync(unpack("L1", $syncMapSync));
	SetSync(unpack("L1", $syncSync));
}

sub generateSitStand {
	my ($sit) = @_;
	my $packet = " " x 256;
	setHashData();
	my $len = CreateSitStand($packet, $sit);
	return substr($packet, 0, $len);
}

sub generateAtk {
	my ($targetId, $flag) = @_;
	my $packet = " " x 256;
	setHashData();
	my $len = CreateAtk($packet, unpack("L1", $targetId), $flag);
	return substr($packet, 0, $len);
}

sub generateSkillUse {
	my ($skillId, $skillLv, $targetId) = @_;
	my $packet = " " x 256;
	setHashData();
	my $len = CreateSkillUse($packet, $skillId, $skillLv, unpack("L1", $targetId));
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
