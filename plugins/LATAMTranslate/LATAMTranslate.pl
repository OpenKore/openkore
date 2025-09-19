# ====================
# LATAMTranslate v1.5
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
use Log qw(message debug error);
use JSON::Tiny qw(from_json to_json);

our %strings_cache;

our $RE_TOKEN_BLOB = qr{
    \x1C
    (
        [^\x1C]*
        (?: \x1C [^\x1C]* \x1C [^\x1C]* )*
    )
    \x1C
}x;

my $base_hooks;

my $plugin_path = $Plugins::current_plugin_folder;

load();
my $hooks = Plugins::addHooks(
	['start3', \&load, undef],
);

Plugins::register( 'LATAMTranslate', 'Fixes issues with localized strings.', \&unload );

sub load {
	my $master = $masterServers{ $config{master} };
	if ( grep { $master->{serverType} eq $_ } qw(ROla) ) {
		$base_hooks = Plugins::addHooks(
			['actor_setName', \&setName, undef],
			['packet_pre/public_chat', \&publicChatPre, undef],
			['packet_pre/local_broadcast', \&localBroadcastPre, undef],
			['packet_pre/system_chat', \&systemChatPre, undef],
			['packet_pre/npc_talk', \&npcTalkPre, undef],
			['pre/npc_talk_responses', \&npcTalkRespPre, undef]
		);
		loadJSON();
	}

}

# Plugin cleanup
sub unload {
	Plugins::delHooks($hooks) if ($hooks);
	Plugins::delHooks($base_hooks) if ($base_hooks);
	%strings_cache = ();
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

# Handles composite tokens of the type: ∟ID\x1Darg0\x1Darg1...∟
# Also supports U+2194 (↔) as a fallback separator in case it's rendered that way.
sub translate_composite_token {
    my ($blob) = @_;

    # Split into ID and parameters using 0x1D (GS) or U+2194 (↔) as separators
    my @parts = split(/\x1D|\x{2194}/, $blob);
    my $id    = shift @parts;

    # Try to find a template by ID; if not found, fallback to simple token translation (logs as MISSING)
    unless (exists $strings_cache{$id}) {
        return translate_token($blob);
    }

    my $template = $strings_cache{$id};

    # Replace placeholders {0}, {1}, {2} with the corresponding arguments
    for my $i (0..$#parts) {
        my $arg = $parts[$i] // '';
        if ($arg =~ /^\x1C([[:print:]]+?)\x1C$/) {
            $arg = translate_token($1);
        }
        $template =~ s/\{\Q$i\E\}/$arg/g;
    }

    return $template;
}

sub _translate_blob {
    my ($blob) = @_;
    return (index($blob, "\x1D") >= 0 || $blob =~ /\x{2194}/)
        ? translate_composite_token($blob)
        : translate_token($blob);
}

sub _translate_tokens_inplace {
    my ($sref) = @_;
    return unless defined $$sref;
    return unless index($$sref, "\x1C") >= 0;   # fast-path

    $$sref =~ s/$RE_TOKEN_BLOB/_translate_blob($1)/gex;
}

sub _translate_args_field {
    my ($args, $field) = @_;
    my $val = $args->{$field};
    return unless defined $val;
    _translate_tokens_inplace(\$val);
    $args->{$field} = $val;
}

sub setName {
    my (undef, $args) = @_;
    my $name = $args->{new_name};
    return unless defined $name;

    my $orig = $name;
    _translate_tokens_inplace(\$name);

    return if $name eq $orig;
    return if $name =~ /\[MISSING:/;

    $args->{new_name} = $name;
    $args->{return}   = 1;
}

sub npcTalkPre {
    my (undef, $args) = @_;
    _translate_args_field($args, 'msg');
}

sub npcTalkRespPre {
    my (undef, $args) = @_;
    my $responses = $args->{responses};

    for my $i (0 .. $#$responses) {
        utf8::encode($responses->[$i]);
        _translate_tokens_inplace(\$responses->[$i]);
    }
}

sub publicChatPre {
    my (undef, $args) = @_;
    _translate_args_field($args, 'message');
}

sub localBroadcastPre {
    my (undef, $args) = @_;
    _translate_args_field($args, 'message');
}

sub systemChatPre {
    my (undef, $args) = @_;
    _translate_args_field($args, 'message');
}

1;