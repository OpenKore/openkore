# Description: Simple POC for Adventure Agency integration
# Authors: Ricardo Ribeiro and Mateus Backhaus

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
					["list",            T("Display current parties available on Adventure Agency.")],
					["header",          T("Display header for the Adventure Agency workflow.")],
					["join <ID>",       T("Join the Adventure with the given numeric ID.")],
					["create <params>", T("Create a new party (e.g. minlv=50 maxlv=99 memo='R>All' tanker=1 type=0).")],
					["update <params>", T("Update your party (e.g. minlv=50 maxlv=99 memo='R>You' tanker=1 type=0).")],
					["delete",          T("Delete your own party from Adventure Agency.")]
				],
				\&cmdAdventureAgency
			]
		);
	}
}

sub getData {
    my %header = (
        GID       => unpack('V', $char->{charID}),
        AID       => $AdventureAgencyContext->{AID},
        AuthToken => $AdventureAgencyContext->{AuthToken},
        CharName  => $char->{name},
    );
    
    my $master = $masterServers{ $config{master} };
 
    my $serverTitle = $config{master}; 
    
    my %worldNames = ();
    if ($serverTitle && $serverTitle =~ /:?\s*([^:]+)$/) {
        my $worldsStr = $1;
        my @worlds = split(/[\/,]/, $worldsStr);
        for my $i (0..$#worlds) {
            my $world = $worlds[$i];
            $world =~ s/^\s+|\s+$//g;
            $worldNames{$i} = $world if $world;
        }
    }
    
    $header{WorldName} = $worldNames{$config{server}} // '';
    
    return (%header, master => $master);
} 



sub cmdAdventureAgency {
	if (!$net || $net->getState() != Network::IN_GAME) {
		error TF("You must be logged in the game to use this command '%s'\n", shift);
		return;
	}

	my ($cmd, $args_string) = @_;
	my @args = Commands::parseArgs($args_string, 2);
		
	if ($args[0] eq 'list') {
		my %data = getData();
		listParties($data{GID}, $data{AID}, $data{WorldName}, $data{AuthToken}, $data{master});
		return;
	}

	if ($args[0] eq 'join') {
		my $partyIndex = $args[1];
		unless (defined $partyIndex && $partyIndex =~ /^\d+$/) {
			error TF("Usage: agency join <ID>\n");
			return;
		}
		
		my ($targetGID, $targetAID, $targetMinLV, $targetMaxLV) = getPartyTarget($partyIndex);
		unless (defined $targetGID && defined $targetAID) {
			error T("Invalid party index or data missing.\n");
			return;
		}

		if ($char->{party} && $char->{party}{name} && $char->{party}{name} ne '') {
			error TF("[AdventureAgency] You are already in a party: $char->{party}{name}\n");
			return;
		}

		if ($char->{lv} < $targetMinLV || $char->{lv} > $targetMaxLV) {
			error TF("[AdventureAgency] Your level ($char->{lv}) does not match this party's required range: $targetMinLV–$targetMaxLV.\n");
			return;
		}

		my $packet = build_party_packet($targetGID, $targetAID);
		$messageSender->sendToServer($packet);

		message TF("[AdventureAgency] Sent join request for party ID %d.\n", $partyIndex);
		return;
	}

	if ($args[0] eq 'create') {
		my $createArgs = $args_string;
		$createArgs =~ s/^create\s*//;
		if (!defined $createArgs || !length $createArgs) {
			$createArgs = "";
		}
		createParty($createArgs);
		return;
	}

	if ($args[0] eq 'update') {
		my $updateArgs = $args_string;
		$updateArgs =~ s/^update\s*//;
		if (!defined $updateArgs || !length $updateArgs) {
			$updateArgs = "";
		}
		createParty($updateArgs);
		return;
	}

	if ($args[0] eq 'delete') { 
		deleteParty();
		return;
	}
	
	if ($args[0] eq 'header'){
		listheader();
		return;
	}
}

sub createParty {
    my ($params) = @_;
    return unless validateApiheader();
    
    my %party_params = (
        MinLV  => 1,
        MaxLV  => 99,
        Memo   => 'R>All', 
        Tanker => 1,
        Dealer => 1,
        Healer => 1,
        Assist => 1,
        Type   => 0  
    );

    if (defined $params && length $params) {

        if ($params =~ /memo='([^']*)'/) {
            $party_params{Memo} = $1;
            $params =~ s/memo='[^']*'//;
        } elsif ($params =~ /memo=(\S+)/) {
            $party_params{Memo} = $1;
            $params =~ s/memo=\S+//;
        }
        
        my @param_list = split /\s+/, $params;

        for my $param (@param_list) {
            next unless length $param;
            if ($param =~ /^minlv=(\d+)$/) { $party_params{MinLV} = $1; }
            elsif ($param =~ /^maxlv=(\d+)$/) { $party_params{MaxLV} = $1; }
            elsif ($param =~ /^tanker=([01])$/) { $party_params{Tanker} = $1; }
            elsif ($param =~ /^dealer=([01])$/) { $party_params{Dealer} = $1; }
            elsif ($param =~ /^healer=([01])$/) { $party_params{Healer} = $1; }
            elsif ($param =~ /^assist=([01])$/) { $party_params{Assist} = $1; }
            elsif ($param =~ /^type=(\d+)$/) { $party_params{Type} = $1; }
            elsif ($param !~ /^memo=/) {
                warning TF("[AdventureAgency] Unknown parameter: %s\n", $param);
            }
        }
    }

    my %data = getData();

    message TF("[AdventureAgency] Creating party: %s (Lv %d-%d)\n", $party_params{Memo}, $party_params{MinLV}, $party_params{MaxLV});
    
    my $ua = LWP::UserAgent->new(timeout => 30);
    my $apiUrl = "http://$data{master}->{ip}:2052/party/add";    
    my $resp = $ua->request(
        POST $apiUrl,
        'Content-Type' => 'multipart/form-data',
        Content => [
            AID       => $data{AID},
            GID       => $data{GID},
            AuthToken => $data{AuthToken},
            WorldName => $data{WorldName},
            CharName  => $data{CharName},
            MinLV     => $party_params{MinLV},
            MaxLV     => $party_params{MaxLV},
            Tanker    => $party_params{Tanker},
            Healer    => $party_params{Healer},
            Dealer    => $party_params{Dealer},
            Assist    => $party_params{Assist},
            Type      => $party_params{Type},
            Memo      => $party_params{Memo},
        ],
    );

    if ($resp->is_success) {
       
        my $body = Encode::encode('utf8', Encode::decode('latin1', $resp->content));
       
        my $data = eval { decode_json($body) };
       
        if ($data && $data->{Type} == 1) {
            message TF("[AdventureAgency] Party created successfully on Adventure Agency!\n");
            if ($data->{PartyID}) {
                message TF("[AdventureAgency] Party ID: %s\n", $data->{PartyID});
            }               
        } else {
            message TF("[AdventureAgency] Party creation response: %s\n", $body);
            if ($data && $data->{Message}) {
                message TF("[AdventureAgency] Server message: %s\n", $data->{Message});
            }
        }
    } else {
        error TF("[AdventureAgency] Failed to create party: %s\n", $resp->status_line);
    }
}

sub deleteParty {
    return unless validateApiheader();
     
    my %data = getData();

    message T("[AdventureAgency] Removing your party from Adventure Agency\n");
      
    my $ua = LWP::UserAgent->new(timeout => 30);
    my $apiUrl = "http://$data{master}->{ip}:2052/party/del";    
    my $resp = $ua->request(
        POST $apiUrl,
        'Content-Type' => 'multipart/form-data',
        Content => [
            AID       => $data{AID},
            GID       => $data{GID},
            WorldName => $data{WorldName},
            AuthToken => $data{AuthToken},
            MasterAID => $data{AID},  
        ],
    );

    if ($resp->is_success) {
        my $body = Encode::encode('utf8', Encode::decode('latin1', $resp->content));
        my $data = eval { decode_json($body) };
        if ($data && $data->{Type} == 1) {
            message TF("[AdventureAgency] Party deleted successfully!\n");  
        } else {
            message TF("[AdventureAgency] Party deletion response: %s\n", $body);
            if ($data && $data->{Message}) {
                message TF("[AdventureAgency] Server message: %s\n", $data->{Message});
            }
        }
    } else {
        error TF("[AdventureAgency] Failed to delete party: %s\n", $resp->status_line);
    }
}

sub validateApiheader { 

    my %data = getData();
 
    unless (defined $data{GID} && defined $data{AID} && length $data{WorldName} && defined $data{AuthToken}) {
        error T("[AdventureAgency] API header not available. Make sure you're logged in.\n");
        return 0;
    }
    return 1;
}

sub listParties {
    my ($GID, $AID, $WorldName, $AuthToken, $master) = @_;

    unless (defined $GID && defined $AID && length $WorldName && defined $AuthToken) {
        error T("[AdventureAgency] Missing headers.\n");
        return;
    }

    @allParties = ();

    my $ua    = LWP::UserAgent->new;
    my $url   = "http://$master->{ip}:2052/party/list";
    my $page = 1;
	my $totalPage;
	
	message TF("[AdventureAgency] Loading party listings from the Adventure Agency, please wait...\n");
	
	do {
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
			error TF("[AdventureAgency] HTTP POST failed on page %d: %s\n", $page, $resp->status_line);
			return;
		}

		my $body = Encode::encode('utf8', Encode::decode('latin1', $resp->content));
		my $data = eval { decode_json($body) };
		if ($@) {
			error TF("[AdventureAgency] JSON decode error on page %d: %s\n", $page, $@);
			return;
		}

		if (!defined $totalPage) {
			$totalPage = $data->{totalPage} || 1;
		}

		my $entries = $data->{data};
		unless (ref($entries) eq 'ARRAY') {
			warning TF("[AdventureAgency] No 'data' array on page %d. Stopping.\n", $page);
			last;
		}

		push @allParties, @$entries;
		$page++;

	} while ($page <= $totalPage);

    @allParties = sort { $a->{MinLV} <=> $b->{MinLV} } @allParties;
    message T("\n------------------- Adventure Agency Party List (All Pages) -------------------\n\n");
    my $i = 1;
    for my $p (@allParties) {
        my @r;
        push @r, 'T' if $p->{Tanker};
        push @r, 'D' if $p->{Dealer};
        push @r, 'H' if $p->{Healer};
        push @r, 'A' if $p->{Assist};
        message TF(
            "ID:%3d| Lv:%3d–%3d| Party:%-24s| Rec:%-4s| Owner:%s\n",
            $i++,
            $p->{MinLV},
            $p->{MaxLV},
            $p->{Memo},
            join('', @r),
            $p->{CharName},
        );
    }
    message T("--------------------------------------------------------------------------------------\n");
}

sub listheader {
	my %data = getData();
	message "\r\n\r\n[AdventureAgency] AID: $data{AID} | GID: $data{GID} | WorldName: $data{WorldName} | AuthToken: $data{AuthToken}\r\n\r\n";
}

sub serverReceivedPackets {
    my (undef, $args) = @_;
    my $msg = $args->{msg};
    my $messageID = uc(unpack("H2", substr($$msg, 1, 1))) . uc(unpack("H2", substr($$msg, 0, 1)));

    return unless $messageID eq '0C32' || $messageID eq '0AFA' || $messageID eq '0AE4';

	if($messageID eq '0C32'){
		$AdventureAgencyContext->{AuthToken} = unpack("A16", substr($$msg, 47, 16));
		$AdventureAgencyContext->{AID} = unpack('V', substr($$msg, 8, 4));
		return;
	}

	if($messageID eq '0AFA'){
		my $partyOwner = unpack("Z24", substr($$msg, 2, 24));
		my $partyName  = unpack("Z24", substr($$msg, 26, 24));
		error "[AdventureAgency] $partyOwner DENIED your entrance on party $partyName.\n";
		return;
	}

	if($messageID eq '0AE4'){
		my $partyName = unpack("Z24", substr($$msg, 23, 24));
		message "[AdventureAgency] You were accepted into $partyName party.\n";
		return;
	}

	return;
}

sub getPartyTarget {
    my ($index) = @_;

    $index--;

    if (!defined $allParties[$index]) {
        error TF("[AdventureAgency] No party found at index %d, run 'agency list' first.\n", $index + 1);
        return;
    }

    my $entry = $allParties[$index];
    my $targetGID = $entry->{GID};
    my $targetAID = $entry->{AID};
	my $targetMinLV = $entry->{MinLV};
	my $targetMaxLV = $entry->{MaxLV};

    return ($targetGID, $targetAID, $targetMinLV, $targetMaxLV);
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