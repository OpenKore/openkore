# Packet Miner v1.2
# By Jojobaoil
#

package packetMiner;

use strict;
use Time::HiRes qw(time);
use Globals;
use Plugins;
use Log qw(debug message error);

# Change these to the packets to be mined
my @minePacketsOut = ("007E", "0089", "0085", "0090", "00A7", "0113", "0116");
my @minePacketsIn = ("007F");

# Make sure we're using a version of OpenKore we can use
my @koreVersion = split /\./, $Settings::VERSION;
if ($koreVersion[0] < 1 ||
	$koreVersion[1] < 9 ||
	$koreVersion[2] < 1) {
	
	# Bad version.
	error "Packet Miner requires use a newer version of $Settings::NAME.\n";
	return 0;
}

Plugins::register('packetMiner', 'PacketMiner by Jojoba Oil', \&onUnload, \&onReload);

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

	unless ($net->version == 1) {
		error "Packet Miner must be used with XKore mode 1. Disabling plugin...\n";
		onUnload;
		return 0;
	}

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
	findIDList(\@monstersID, \%monsters, \$dump, 1);
	findIDList(\@playersID, \%players, \$dump, 1);
	findIDList(\@npcsID, \%npcs, \$dump, 0);
	
	if (defined $accountID && length($accountID) > 0) {
		pos($msg) = 0;
		while ($msg =~ m/\Q$accountID\E/g) {
			my $loc = pos($msg) - length($accountID);
			$dump .= "Account ID reference (" . main::getHex($accountID) . ") found at offset: $loc\n";
		}
	}
	if (defined $charID && length($charID) > 0) {
		pos($msg) = 0;
		while ($msg =~ m/\Q$charID\E/g) {
			my $loc = pos($msg) - length($charID);
			$dump .= "Character ID reference (" . main::getHex($charID) . ") found at offset: $loc\n";
		}
	}

	# Append the mined packet to the log.
	if (open (FILE, ">> $logfile")) {
		print FILE $dump;
		close(FILE);
	}

	return 0;
}

sub findIDList {
	my ($rarray, $rhash, $rdump, $isActor) = @_;
	
	foreach my $ID (@$rarray) {
		my $name = (defined $rhash->{$ID})
			? ($isActor? $rhash->{$ID}->name
				: $rhash->{$ID}{name})
			: 'Unknown';
		$name .= " (" . main::getHex($ID) . ")";
		if (length($ID) > 0) {
			pos($msg) = 0;
			while ($msg =~ m/\Q$ID\E/g) {
				my $loc = pos($msg) - length($ID);
				$$rdump .= "$name referenced at offset: $loc.\n";
			}
		}
	}
}


1;