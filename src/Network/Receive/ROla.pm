package Network::Receive::ROla;

use strict;
use base qw(Network::Receive::ServerType0);
use Globals qw($char $messageSender);
use I18N qw(bytesToString);
use Log qw(debug);

sub new {
	my ( $class ) = @_;
	my $self = $class->SUPER::new( @_ );

	my %packets = (
		'0097' => [ 'private_message',      'v Z24 V Z*',                                                  [qw(len privMsgUser flag privMsg)] ],                                                                                                                                                                                                                               # -1
		'009D' => [ 'item_exists',          'a4 V C v3 C2',                                                [qw(ID nameID identified x y amount subx suby)] ],
		'009E' => [ 'item_appeared',        'a4 v2 C v2 C2 v',                                             [qw(ID nameID type identified x y subx suby amount)] ],
		'01C8' => [ 'item_used',            'a2 V a4 v C',                                                 [qw(ID itemID actorID remaining success)] ],
		'07FD' => [ 'special_item_obtain',  'v C V c/Z a*',                                                [qw(len type nameID holder etc)] ],                                                                                                                                                                                                                                 # record "c/Z" (holder) means: if the first byte ('c') = 24(dec), then Z24, if 'c' = 18(dec), then Z18, еtc.
		'09FD' => [ 'actor_moved',          'v C a4 a4 v3 V v2 V2 v V v6 a4 a2 v V C2 a6 C2 v2 V2 C v Z*', [qw(len object_type ID charID walk_speed opt1 opt2 option type hair_style weapon shield lowhead tick tophead midhead hair_color clothes_color head_dir costume guildID emblemID manner opt3 stance sex coords xSize ySize lv font maxHP HP isBoss opt4 name)] ],
		'09FE' => [ 'actor_connected',      'v C a4 a4 v3 V v2 V2 v7 a4 a2 v V C2 a3 C2 v2 V2 C v Z*',     [qw(len object_type ID charID walk_speed opt1 opt2 option type hair_style weapon shield lowhead tophead midhead hair_color clothes_color head_dir costume guildID emblemID manner opt3 stance sex coords xSize ySize lv font maxHP HP isBoss opt4 name)] ],
		'09FF' => [ 'actor_exists',         'v C a4 a4 v3 V v2 V2 v7 a4 a2 v V C2 a3 C3 v2 V2 C v Z*',     [qw(len object_type ID charID walk_speed opt1 opt2 option type hair_style weapon shield lowhead tophead midhead hair_color clothes_color head_dir costume guildID emblemID manner opt3 stance sex coords xSize ySize state lv font maxHP HP isBoss opt4 name)] ],
		'0A09' => [ 'deal_add_other',       'V C V C3 a16 a25',                                            [qw(nameID type amount identified broken upgrade cards options)] ],
		'0A0A' => [ 'storage_item_added',   'a2 V V C4 a16 a25',                                           [qw(ID amount nameID type identified broken upgrade cards options)] ],
		'0A0B' => [ 'cart_item_added',      'a2 V V C4 a16 a25',                                           [qw(ID amount nameID type identified broken upgrade cards options)] ],
		'0A37' => [ 'inventory_item_added', 'a2 v V C3 a16 V C2 a4 v a25 C v',                             [qw(ID amount nameID identified broken upgrade cards type_equip type fail expire unknown options favorite viewID)] ],
		'0ADD' => [ 'item_appeared',        'a4 V v C v2 C2 v C v',                                        [qw(ID nameID type identified x y subx suby amount show_effect effect_type)] ],
		'0C32' => [ 'account_server_info',  'v a4 a4 a4 a4 a26 C x17 a*',                                  [qw(len sessionID accountID sessionID2 lastLoginIP lastLoginTime accountSex serverInfo)] ],
	);

	$self->{packet_list}{$_} = $packets{$_} for keys %packets;

	my %handlers = qw(
		received_characters 099D
		received_characters_info 082D
		sync_received_characters 09A0
		account_server_info 0C32
	);

	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;

	$self->{buying_store_items_list_pack} = "V v C V";
	$self->{makable_item_list_pack}       = "V4";
	$self->{npc_market_info_pack}         = "V C V2 v";
	$self->{npc_store_info_pack}          = "V V C V";
	$self->{vender_items_list_item_pack}  = 'V v2 C V C3 a16 a25 V v';
	$self->{rodex_read_mail_item_pack}    = 'v V C3 a16 a4 C a4 a25';

	return $self;
}

sub guild_name {
	my ($self, $args) = @_;

	my $guildID = $args->{guildID};
	my $emblemID = $args->{emblemID};
	my $mode = $args->{mode};
	my $guildName = bytesToString($args->{guildName});
	$char->{guild}{name} = $guildName;
	$char->{guildID} = $guildID;
	$char->{guild}{emblem} = $emblemID;

	debug "guild name: $guildName\n";

	# Skip in XKore mode 1 / 3
	return if $self->{net}->version == 1;

	# emulate client behavior
	$messageSender->sendGuildRequestInfo(3);
	$messageSender->sendGuildRequestInfo(1);		# Requests for Members list, list job title

}

1;
