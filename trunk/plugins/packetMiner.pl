# Packet Miner v1.1
# By Jojobaoil
#

package packetMiner;

use strict;
use Time::HiRes qw(time);
use Globals;
use Plugins;
use Log qw(debug message warning error);

my @minePacketsOut = ("007E", "0089","0085","0090","00A7","0113","0116");
my @minePacketsIn = ("received_sync");

Plugins::register('packetMiner', 'PacketMiner by jojo', \&onUnload, \&onReload);

message "Packet Miner plugin loaded.\n", "success";

my @mangleHooks;
my @mangleHookNames;
my $logfile = "$Settings::logs_folder/packetMiner.txt";

for (my $i = 0; $i < @minePacketsOut; $i++) {
	my $hookName = "packet_outMangle/$minePacketsOut[$i]";
	push @mangleHookNames, $hookName;
	push @mangleHooks, Plugins::addHook($hookName, \&minePacket);
	debug "Mining packet - $hookName\n";
}

for (my $i = 0; $i < @minePacketsIn; $i++) {
	my $hookName = "packet_mangle/$minePacketsIn[$i]";
	push @mangleHookNames, $hookName;
	push @mangleHooks, Plugins::addHook($hookName, \&minePacket);
	debug "Mining packet - $hookName\n";
}

sub onUnload {
	Plugins::delHook(pop(@mangleHookNames), pop(@mangleHooks)) while (@mangleHooks > 0);
}

sub onReload {
	&onUnload;
}

sub minePacket {
	my ($hookName, $args) = @_;

	return 0 unless ($net->version == 1);

	my $dump;
	my $msg = (substr($hookName, 0, 13) eq "packet_mangle")? substr($args->{RAW_MSG}, 2) : $args->{data};
	my $puncations = quotemeta '~!@#$%^&*()_+|\"\'';

	$dump = "\n\n================================================\n" .
	"$hookName  - " . length($msg) . " bytes\n" .
	main::getFormattedDate(int(time)) . "\n";

	for (my $i = 0; $i < length($msg); $i += 16) {
		my $line;
		my $data = substr($msg, $i, 16);
		my $rawData = '';

		for (my $j = 0; $j < length($data); $j++) {
			my $char = substr($data, $j, 1);

			if (($char =~ /\W/ && $char =~ /\S/ && !($char =~ /[$puncations]/))
			|| ($char eq chr(10) || $char eq chr(13) || $char eq "\t")) {
				$rawData .= '.';
			} else {
				$rawData .= substr($data, $j, 1);
			}
		}

		$line = main::getHex(substr($data, 0, 8));
		$line .= '    ' . main::getHex(substr($data, 8)) if (length($data) > 8);

		$line .= ' ' x (50 - length($line)) if (length($line) < 54);
		$line .= "    $rawData\n";
		$line = sprintf("%3d>  ", $i) . $line;
		$dump .= $line;
	}

	# Find information
	foreach my $ID (@monstersID) {
		my $name = (defined $monsters{$ID})? $monsters{$ID}->name : 'unknown';
		$name .= " (" . main::getHex($ID) . ")";
		undef pos($msg);
		if ($msg =~ m/\Q$ID\E/g && length($ID) > 0) {
			my $loc = pos($msg) - length($ID);
			$dump .= "Monster reference to $name found at byte: $loc\n";
			last;
		}
	}
	foreach my $ID (@playersID) {
		my $name = (defined $players{ID})? $players{$ID}->name : 'unknown';
		$name .= " (" . main::getHex($ID) . ")";
		undef pos($msg);
		if ($msg =~ m/\Q$ID\E/g && length($ID) > 0) {
			my $loc = pos($msg) - length($ID);
			$dump .= "Player reference of $name found at byte: $loc\n";
			last;
		}
	}
	foreach my $ID (@npcsID) {
		my $name = (defined $npcs{ID})? $npcs{$ID}{name} : 'unknown';
		$name .= " (" . main::getHex($ID) . ")";
		undef pos($msg);
		if ($msg =~ m/\Q$ID\E/g) {
			my $loc = pos($msg) - length($ID);
			$dump .= "NPC reference of $name found at byte: $loc\n";
			last;
		}
	}
	undef pos($msg);
	if ($msg =~ m/\Q$accountID\E/g && defined($accountID) && length($accountID) > 0) {
		my $loc = pos($msg) - length($accountID);
		$dump .= "Account ID reference (" . main::getHex($accountID) . ") found at byte: $loc\n";
	}
	undef pos($msg);
	if ($msg =~ m/\Q$charID\E/g && defined($charID) && length($charID) > 0) {
		my $loc = pos($msg) - length($charID);
		$dump .= "Character ID reference (" . main::getHex($charID) . ") found at byte: $loc\n";
	}

	if (open (FILE, ">> $logfile")) {
		print FILE $dump;
		close(FILE);
	}

	return 0;
}


1;