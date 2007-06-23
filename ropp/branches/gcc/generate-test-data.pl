use strict;
use Time::HiRes qw(time);
use Win32::API;

srand();

# Loading ropp.dll and importing functions
Win32::API->Import('ropp', 'CreateSitStand', 'PL' ,'N') or die "Can't import CreateSitStand\n$!";
Win32::API->Import('ropp', 'CreateAtk', 'PLL' ,'N') or die "Can't import CreateAtk\n$!";
Win32::API->Import('ropp', 'CreateSkillUse', 'PLLL' ,'N') or die "Can't import CreateSkillUse\n$!";

Win32::API->Import('ropp', 'SetMapSync', 'L') or die "Can't import SetMapSync\n$!";
Win32::API->Import('ropp', 'SetSync', 'L') or die "SetSync\n$!";
Win32::API->Import('ropp', 'SetAccountId', 'L') or die "Can't import SetAccountId\n$!";
Win32::API->Import('ropp', 'SetPacketIDs', 'LL') or die "Can't import SetPacketIDs\n$!";
Win32::API->Import('ropp', 'SetPacket', 'PLL') or die "Can't import SetPacket\n$!";

Win32::API->Import('ropp', 'DecodePacket', 'PL') or die "Can't import DecodePacket\n$!";
Win32::API->Import('ropp', 'GetKey', 'L' ,'N') or die "Can't import GetKey\n$!";

use constant MAX_INT => 4294967296;

my $f;
open($f, ">", "unittest.dat");
binmode $f;

my ($attackID, $skillUseID, $accountID, $syncMapSync, $syncSync, $LastPaddedPacket);

SetPacket(" " x 512, 512, 0);

for (my $i = 0; $i < 100; $i++) {
	$attackID = int rand(MAX_INT);
	$skillUseID = int rand(MAX_INT);
	$accountID = int rand(MAX_INT);
	$syncMapSync = int rand(MAX_INT);
	$syncSync = int rand(MAX_INT);
	print $f pack("V*", $attackID, $skillUseID, $accountID, $syncMapSync, $syncSync);

	SetPacketIDs($attackID, $skillUseID);

	my $monID = int rand(MAX_INT);
	my $flag = int rand(10);
	my $skillID = int rand(100);
	my $level = int rand(11);
	my $targetID = int rand(MAX_INT);
	print $f pack("V*", $monID, $flag, $skillID, $level, $targetID);
	
	printStr($f, generateSitStand(1)); # sit
	printStr($f, generateSitStand(0)); # stand
	printStr($f, generateAtk($monID, $flag));
	printStr($f, generateSkillUse($skillID, $level, $targetID));
}

close($f);

sub setHashData {
	SetAccountId($accountID);
	SetMapSync($syncMapSync);
	SetSync($syncSync);
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
	my $len = CreateAtk($packet, $targetId, $flag);
	return substr($packet, 0, $len);
}

sub generateSkillUse {
	my ($skillId, $skillLv, $targetId) = @_;
	my $packet = " " x 256;
	setHashData();
	my $len = CreateSkillUse($packet, $skillId, $skillLv, $targetId);
	return substr($packet, 0, $len);
}

sub printStr {
	my ($f, $str) = @_;
	print $f pack("V", length($str));
	print $f $str;
}

1;
