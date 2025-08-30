# ====================
# LATAMTranslate v1.2
# Plugin author: Rubim, UnknownXD
# Plugin modified by: roxleopardo
# ====================

package LATAMTranslate;

use strict;
use Plugins;
use Globals;
use Settings;
use Utils;
use utf8;
use bytes;
use Log qw(message debug error);
use JSON::Tiny qw(from_json to_json);

our %strings_cache;

Plugins::register( 'LATAMTranslate', 'Fixes issues with localized strings.', \&onUnload );

my $hooks = Plugins::addHooks(
	['start3', \&checkServer, undef],
);
my $base_hooks;

my $plugin_path = $Plugins::current_plugin_folder;

sub checkServer {
	my $master = $masterServers{ $config{master} };
	if ( grep { $master->{serverType} eq $_ } qw(ROla) ) {
		my $base_hooks = Plugins::addHooks(
			['actor_setName', \&setName, undef],
            ['packet_pre/public_chat', \&messagePre, undef],
			['packet_pre/local_broadcast', \&messagePre, undef],
			['packet_pre/npc_talk', \&npcTalkPre, undef],
			['packet_pre/npc_talk_responses', \&npcTalkRespPre, undef],
		);
		loadJSON();
	}

}
# Load actor_name.json
sub loadJSON {
	message "Loading strings.json...\n", "LATAMTranslate";
	%strings_cache = ();

	my $file = "$plugin_path/strings.json";
	unless ( -r $file ) {
		error( "[LATAMTranslate] Can't read $file\n" );
		return;
	}

	open my $fh, '<', $file or do {
		error( "[LATAMTranslate] Failed to open $file: $!\n" );
		return;
	};

	local $/;	# Enable slurp mode
	my $json_text = <$fh>;
	close $fh;

	my $data = eval { from_json( $json_text ) };	# ← FIXED
	if ( $@ || ref( $data ) ne 'HASH' ) {
		error( "[LATAMTranslate] Failed to parse JSON: $@\n" );
		return;
	}

	%strings_cache = %{$data};
	my $count = scalar( keys %strings_cache );
	message "[LATAMTranslate] Loaded $count actor names from strings.json\n", "LATAMTranslate";
}

# Plugin cleanup
sub unload {
	Plugins::delHooks( $base_hooks );
	Plugins::delHooks( $hooks ) if ( $hooks );
	%strings_cache = ();
}

sub debug {
	my (undef, $args) = @_;
	message "[LATAMTranslate] Debug: " . Data::Dumper::Dumper($args) . "\n", "debug";
}

sub translate_token {
	my ($token) = @_;

	if (exists $strings_cache{$token}) {
		my $string = $strings_cache{$token};
        utf8::decode($string);
		return $string;
	} else {
		# print warning of missing token and the hex
		my $hex = unpack("H*", $token);
		message("[LATAMTranslate] Missing token: $token (hex: $hex)\n");
		return "[MISSING:$token]";
	}
}

sub setName {
	my ($hookName, $args) = @_;

	my $new_name = $args->{new_name};

	# Check for ∟...∟ (0x1C) encoded strings
	if (defined $new_name && $new_name =~ /\x1C([^\x1C]+)\x1C/) {
		my $token = $1;
		my $translated = translate_token($token);

		if ($translated !~ /^\[MISSING:/) {
			$args->{new_name} = $translated;
			$args->{return} = 1;  # Let the main setName apply our translation
		}
	}
}

sub npcTalkPre {
	my ( $self, $args ) = @_;
	my $message = $args->{msg} || '';

	my @tokens = $message =~ /\x1C([^\x1C]+)\x1C/g;

	if (@tokens) {
		my $last_token = $tokens[-1];
		my $translated = translate_token($last_token);
		$args->{msg} = $translated;
	}
}

sub npcTalkRespPre {
	my (undef, $args) = @_;

	my $raw_msg = $args->{RAW_MSG} || '';
	my $original_msg = $raw_msg;  # For debug

	my $hex_msg = unpack('H*', $raw_msg);

	#message Misc::visualDump($raw_msg);

	my $translated = $raw_msg;
	$translated =~ s/\x1C([^\x1C]+)\x1C/translate_token($1)/ge;
  
	my $new_size = bytes::length($translated);
	substr($translated, 2, 2, pack('v', $new_size));

	$args->{RAW_MSG} = $translated;
	$args->{RAW_MSG_SIZE} = $new_size;
}

sub messagePre {
	my ($hookName, $args) = @_;

	my $new_message = $args->{message};

	# Check for ∟...∟ (0x1C) encoded strings
	if (defined $new_message && $new_message =~ /\x1C([^\x1C]+)\x1C/) {
		my $token = $1;
		my $translated = translate_token($token);

		if ($translated !~ /^\[MISSING:/) {
			$args->{message} = $translated;
		}
	}
}
1;

