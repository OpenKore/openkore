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
					["headers",         T("Display headers for the Adventure Agency workflow.")],
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

# Cache to avoid reading servers.txt multiple times
my %serverConfigCache = ();
 
sub getApiHeaders {
    my %headers = (
        GID       => unpack('V', $char->{charID}),
        AID       => $AdventureAgencyContext->{AID},
        AuthToken => $AdventureAgencyContext->{AuthToken},
        CharName  => $char->{name},
    );
    
    # Get server configuration
    my $master = $masterServers{ $config{master} };
    my %serverConfig = getServerConfig($master->{serverType});
    $headers{WorldName} = $serverConfig{worlds}{$config{server}} // '';
    
    return %headers;
} 

sub getServerConfig {
    my ($serverType) = @_;
	
    return %{$serverConfigCache{$serverType}} if exists $serverConfigCache{$serverType};
    
    my %config = (
        worlds => {0 => 'Freya', 1 => 'Nidhogg', 2 => 'Yggdrasil'},  # Default fallback for ROla
        ip => 'lt-account-01.gnjoylatam.com',  # fallback
        api_port => 2052  # Adventure Agency API port
    );
    
    my $foundInFile = 0;
     
    my $serversFile = Settings::getTableFilename("servers.txt");
    
    if (-f $serversFile) {
        if (open(my $fh, '<:encoding(UTF-8)', $serversFile)) {
            my $currentSection = '';
            my $foundServerType = '';
            my $currentIP = '';
            
            while (my $line = <$fh>) {
                chomp $line;
                $line =~ s/^\s+|\s+$//g; # trim whitespace
                
                # Skip comments and empty lines
                next if $line =~ /^#/ || $line eq '';
                
                # Parse section headers like [Latam - ROla: Freya/Nidhogg/Yggdrasil]
                if ($line =~ /^\[(.+)\]$/) {
                    $currentSection = $1;
                    $foundServerType = '';
                    $currentIP = '';
                    next;
                }
                
                # Look for serverType line
                if ($line =~ /^serverType\s+(.+)$/) {
                    $foundServerType = $1;
                    next;
                }
                
                # Look for IP line
                if ($line =~ /^ip\s+(.+)$/) {
                    $currentIP = $1;
                    next;
                }
                
                # If we found the right serverType and have both section and IP
                if ($foundServerType eq $serverType && $currentSection && $currentIP) {
                    # Store the IP
                    $config{ip} = $currentIP;
                    $foundInFile = 1;
                    
                    # Extract world names from section title
                    # Example: "Latam - ROla: Freya/Nidhogg/Yggdrasil" -> "Freya/Nidhogg/Yggdrasil"
                    if ($currentSection =~ /:?\s*([^:]+)$/) {
                        my $worldsStr = $1;
                        # Split by / or comma and clean up
                        my @worlds = split(/[\/,]/, $worldsStr);
                        
                        # Clear default worlds and replace with file data
                        $config{worlds} = {};
                        for my $i (0..$#worlds) {
                            my $world = $worlds[$i];
                            $world =~ s/^\s+|\s+$//g; # trim
                            $config{worlds}{$i} = $world if $world;
                        }
                        last;
                    }
                }
            }
            close($fh);
        } else {
            warning TF("Could not read %s: %s. Using hardcoded values.\n", $serversFile, $!);
        }
    } else {
        warning TF("File not found: %s. Using hardcoded values.\n", $serversFile);
    }
      
    # Cache the result
    $serverConfigCache{$serverType} = \%config;
    
    return %config;
}

sub buildApiUrl {
    my ($endpoint) = @_;
    my $master = $masterServers{ $config{master} };
    my %serverConfig = getServerConfig($master->{serverType});
    
    return "http://$serverConfig{ip}:$serverConfig{api_port}$endpoint";
}

sub cmdAdventureAgency {

	if (!$net || $net->getState() != Network::IN_GAME) {
		error TF("You must be logged in the game to use this command '%s'\n", shift);
		return;
	}

	my ($cmd, $args_string) = @_;
	my @args = Commands::parseArgs($args_string, 2);
		
	if ($args[0] eq 'list') {
		my %headers = getApiHeaders();
		listParties($headers{GID}, $headers{AID}, $headers{WorldName}, $headers{AuthToken});
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

		message TF("[AdventureAgency] Sent join request for party ID %d (GID: %d, AID: %d)\n", $partyIndex, $targetGID, $targetAID);
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
	
	if ($args[0] eq 'headers'){
		listHeaders();
		return;
	}
}

sub createParty {
    my ($params) = @_;
    return unless validateApiHeaders();
    
    # Default party parameters
    my %party_params = (
        MinLV => 1,
        MaxLV => 99,
        Memo => 'R>All', 
        Tanker => 1,
        Dealer => 1,
        Healer => 1,
        Assist => 1,
        Type => 0  
    );

    # Parse custom parameters if provided
    if (defined $params && length $params) {

        # Extract memo with quotes if present
        if ($params =~ /memo='([^']*)'/) {
            $party_params{Memo} = $1;
            $params =~ s/memo='[^']*'//;
        } elsif ($params =~ /memo=(\S+)/) {
            $party_params{Memo} = $1;
            $params =~ s/memo=\S+//;
        }
        
        # Process other parameters
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

    my %headers = getApiHeaders();

    message TF("[AdventureAgency] Creating party: %s (Lv %d-%d)\n", $party_params{Memo}, $party_params{MinLV}, $party_params{MaxLV});
    
    # Send party creation request
    my $ua = LWP::UserAgent->new(timeout => 30);
    my $apiUrl = buildApiUrl('/party/add');    
    my $resp = $ua->request(
        POST $apiUrl,
        'Content-Type' => 'multipart/form-data',
        Content => [
            AID       => $headers{AID},
            GID       => $headers{GID},
            AuthToken => $headers{AuthToken},
            WorldName => $headers{WorldName},
            CharName  => $headers{CharName},
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

    # Process response
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
    return unless validateApiHeaders();
     
    my %headers = getApiHeaders();

    message T("[AdventureAgency] Removing your party from Adventure Agency\n");
      
    # Send deletion request
    my $ua = LWP::UserAgent->new(timeout => 30);
    my $apiUrl = buildApiUrl('/party/del');    
    my $resp = $ua->request(
        POST $apiUrl,
        'Content-Type' => 'multipart/form-data',
        Content => [
            AID       => $headers{AID},
            GID       => $headers{GID},
            WorldName => $headers{WorldName},
            AuthToken => $headers{AuthToken},
            MasterAID => $headers{AID},   # Use own AID to delete own party
        ],
    );

    # Process response
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

sub validateApiHeaders { 

    my %headers = getApiHeaders();
 
    unless (defined $headers{GID} && defined $headers{AID} && length $headers{WorldName} && defined $headers{AuthToken}) {
        error T("[AdventureAgency] API headers not available. Make sure you're logged in.\n");
        return 0;
    }
    return 1;
}

sub listParties {
    my ($GID, $AID, $WorldName, $AuthToken) = @_;

    unless (defined $GID && defined $AID && length $WorldName && defined $AuthToken) {
        error T("[AdventureAgency] Missing headers – please run 'agency headers' first\n");
        return;
    }

    # Clear cache before fetching
    @allParties = ();

    my $ua    = LWP::UserAgent->new;
    my $url   = buildApiUrl('/party/list');
    my $page = 1;
	my $totalPage;
	
	do {
		message TF("[AdventureAgency] Fetching page %d …\n", $page);

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
    message T("\n\n------------------- Adventure Agency Party List (All Pages) -------------------\n\n");
    my $i = 1;
    for my $p (@allParties) {
        my @r;
        push @r, 'T' if $p->{Tanker};
        push @r, 'D' if $p->{Dealer};
        push @r, 'H' if $p->{Healer};
        push @r, 'A' if $p->{Assist};
        message TF(
            "ID:%3d|Lv:%3d–%3d|Party:%-24s|Rec:%-4s|Owner:%s\n",
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

sub listHeaders {
	my %headers = getApiHeaders();
	message "\r\n\r\n[AdventureAgency] AID: $headers{AID} | GID: $headers{GID} | WorldName: $headers{WorldName} | AuthToken: $headers{AuthToken}\r\n\r\n";
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
        error TF("[AdventureAgency] No party found at index %d\n", $index + 1);
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
