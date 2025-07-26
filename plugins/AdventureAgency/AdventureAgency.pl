# This script was made possible by Ricardo Ribeiro and BackhausMat

#	TODO:
# log when party request was accepted, rejected or full
# create group on agency
# delete group on agency
# change group on agency
# search for especific group on agency

# this script is yet a POC. if the community adopts it, we can work to make it more robust and native on openkore.

package AdventureAgency;

use strict;
use utf8;
use Plugins;
use Commands;
use Globals;
use Settings;
use Network::Receive;
use Log qw(message warning error);
use Translation qw(T TF);
use LWP::UserAgent;
use HTTP::Request::Common qw(POST);
use JSON::Tiny qw(decode_json encode_json);
use Encode;
use Data::Dumper;

Plugins::register( "AdventureAgency", "Implements the Adventure Agency workflow on openkore.", \&unload );

my $AdventureAgencyContext = {};
my $commandID;
my $base_hooks;
my $hooks = Plugins::addHooks( ['start3', \&Init, undef], );

my @allParties;

sub Init {
	my $master = $masterServers{ $config{master} };
	if ( grep { $master->{serverType} eq $_ } qw(ROla) ) {
		$base_hooks = Plugins::addHooks(
			['Network::serverRecv', \&serverReceivedPackets, undef ],
		);
		$commandID = Commands::register(
			[
				'agency',
				[
					T("Manages the Adventure Agency."),
					["list",         T("Display current parties available on Adventure Agency.")],
					["headers",      T("Display headers for the Adventure Agency workflow.")],
					["join <ID>",    T("Join the Adventure with the given numeric ID.")]
				],
				\&cmdAdventureAgency
			]
		);
	}
}

sub cmdAdventureAgency {

	if (!$net || $net->getState() != Network::IN_GAME) {
		error TF("You must be logged in the game to use this command '%s'\n", shift);
		return;
	}

	my ($cmd, $args_string) = @_;
	my @args = Commands::parseArgs($args_string, 2);
		
	if ($args[0] eq 'list') {
		my $GID       = unpack('V', $char->{charID});
		my $AID       = $AdventureAgencyContext->{AID};
		my %hardcoded = (0 => 'Freya', 1 => 'Nidhogg', 2 => 'Yggdrasil');
		my $WorldName = $hardcoded{$config{server}} // '';
		my $AuthToken = $AdventureAgencyContext->{AuthToken};

		listParties($GID, $AID, $WorldName, $AuthToken);
		return;
	}

	if ($args[0] eq 'join') {
		my $partyIndex = $args[1];
		unless (defined $partyIndex && $partyIndex =~ /^\d+$/) {
			error TF("Usage: agency join <ID>\n");
			return;
		}
		
		my ($targetGID, $targetAID) = getPartyTarget($partyIndex);
		unless (defined $targetGID && defined $targetAID) {
			error T("Invalid party index or data missing.\n");
			return;
		}


		my $packet = build_party_packet($targetGID, $targetAID);
		my $hex = uc unpack('H*', $packet);
		message "Hex Packet: $hex\n";
		$messageSender->sendToServer($packet);

		message TF("→ Sent join request for party ID %d (GID: %d, AID: %d)\n", $partyIndex, $targetGID, $targetAID);
		return;
	}
	
	#Hey bro, this is here just for debug purposes, it should be remove on release.
	if ($args[0] eq 'headers'){
		listHeaders();
		return;
	}
}

sub listParties {
    my ($GID, $AID, $WorldName, $AuthToken) = @_;

    unless (defined $GID && defined $AID && length $WorldName && defined $AuthToken) {
        error T("Missing headers – please run 'agency headers' first\n");
        return;
    }

    my $ua    = LWP::UserAgent->new;
    my $url   = 'http://lt-account-01.gnjoylatam.com:2052/party/list';
    my $page = 1;
	my $totalPage;
	
	do {
		message TF("→ Fetching page %d …\n", $page);

		my $resp = $ua->request(
			POST $url,
			Content_Type => 'form-data',
			Content      => [
				GID       => $GID,
				AID       => $AID,
				WorldName => $WorldName,
				AuthToken => $AuthToken,
				page      => $page,
			],
		);

		unless ($resp->is_success) {
			error TF("HTTP POST failed on page %d: %s\n", $page, $resp->status_line);
			return;
		}

		my $body = Encode::encode('utf8', Encode::decode('latin1', $resp->content));
		my $data = eval { decode_json($body) };
		if ($@) {
			error TF("JSON decode error on page %d: %s\n", $page, $@);
			return;
		}

		if (!defined $totalPage) {
			$totalPage = $data->{totalPage} || 1;
		}

		my $entries = $data->{data};
		unless (ref($entries) eq 'ARRAY') {
			warning TF("No 'data' array on page %d. Stopping.\n", $page);
			last;
		}

		push @allParties, @$entries;
		$page++;

	} while ($page <= $totalPage);

    @allParties = sort { $a->{MinLV} <=> $b->{MinLV} } @allParties;
    message T("\n\n------------------------------- Adventure Agency Party List (All Pages) ------------------------------------------\n\n");
    my $i = 1;
    for my $p (@allParties) {
        my @r;
        push @r, 'T' if $p->{Tanker};
        push @r, 'D' if $p->{Dealer};
        push @r, 'H' if $p->{Healer};
        push @r, 'A' if $p->{Assist};
        message TF(
            "ID: %3d | Lv: %3d–%3d | Party: %-24s | Rec: %-4s | Owner: %s\n",
            $i++,
            $p->{MinLV},
            $p->{MaxLV},
            $p->{Memo},
            join('', @r),
            $p->{CharName},
        );
    }
    message T("----------------------------------------------------------------------------------------------------------------------\n");
}

sub listHeaders {
	my $currentGID = unpack('V', $char->{charID});
	my %hardcodedWorlds = ( 0 => 'Freya', 1 => 'Nidhogg', 2 => 'Yggdrasil' );
	message "\r\n\r\nAID: $AdventureAgencyContext->{AID} | GID: $currentGID | WorldName: $hardcodedWorlds{$config{server}} | AuthToken: $AdventureAgencyContext->{AuthToken}\r\n\r\n";
}

sub serverReceivedPackets {
    my (undef, $args) = @_;
    my $msg = $args->{msg};
    my $messageID = uc(unpack("H2", substr($$msg, 1, 1))) . uc(unpack("H2", substr($$msg, 0, 1)));

    return unless $messageID eq '0C32';

	if($messageID eq '0C32'){
		$AdventureAgencyContext->{AuthToken} = unpack("A16", substr($$msg, 47, 16));
		$AdventureAgencyContext->{AID} = unpack('V', substr($$msg, 8, 4));
	}

	return;
}

sub getPartyTarget {
    my ($index) = @_;

    $index--;

    if (!defined $allParties[$index]) {
        error TF("No party found at index %d\n", $index + 1);
        return;
    }

    my $entry = $allParties[$index];
    my $targetGID = $entry->{GID};
    my $targetAID = $entry->{AID};

    return ($targetGID, $targetAID);
}

sub build_party_packet {
    my ($gid, $aid) = @_;
    return pack("vVV", 0x0AE6, $gid, $aid);
}

sub unload {
	Plugins::delHooks( $base_hooks );
	Plugins::delHooks( $hooks ) if ( $hooks );
	Commands::unregister($commandID) if $commandID;
}

1;
