package Network::Receive::kRO::RagexeRE_2016_02_03;

use strict;
use base qw(Network::Receive::kRO::RagexeRE_2016_01_27);
sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	my %packets = (
		'0086' => ['actor_display', 'a4 a6 V', [qw(ID coords tick)]],
		'01C3' => ['local_broadcast', 'v V v4 Z*', [qw(len color font_type font_size font_align font_y message)]],
		'02DA' => ['show_eq_msg_self', 'C', [qw(type)]],
		'0A3B' => ['hat_effect', 'v a4 C a*', [qw(len ID flag effect)]], # -1
		'0A30' => ['actor_info', 'a4 Z24 Z24 Z24 Z24 x4', [qw(ID name partyName guildName guildTitle)]],
		'099D' => ['received_characters', 'v a*', [qw(len charInfo)]],
		'08C8' => ['actor_action', 'a4 a4 a4 V3 x v C V', [qw(sourceID targetID tick src_speed dst_speed damage div type dual_wield_damage)]],
		'09FF' => ['actor_exists', 'v C a4 a4 v3 V v11 a4 a2 v V C2 a3 C3 v2 a9 Z*', [qw(len object_type ID charID walk_speed opt1 opt2 option type hair_style weapon shield lowhead tophead midhead hair_color clothes_color head_dir costume guildID emblemID manner opt3 stance sex coords xSize ySize act lv font opt4 name)]],
		'09FE' => ['actor_connected', 'v C a4 a4 v3 V v11 a4 a2 v V C2 a3 C2 v2 a9 Z*', [qw(len object_type ID charID walk_speed opt1 opt2 option type hair_style weapon shield lowhead tophead midhead hair_color clothes_color head_dir costume guildID emblemID manner opt3 stance sex coords xSize ySize lv font opt4 name)]],
		'09FD' => ['actor_moved', 'v C a4 a4 v3 V v5 a4 v6 a4 a2 v V C2 a6 C2 v2 a9 Z*', [qw(len object_type ID charID walk_speed opt1 opt2 option type hair_style weapon shield lowhead tick tophead midhead hair_color clothes_color head_dir costume guildID emblemID manner opt3 stance sex coords xSize ySize lv font opt4 name)]],	
	);

	foreach my $switch (keys %packets) {
		$self->{packet_list}{$switch} = $packets{$switch};
	}

	return $self;
}

1;
=pod
0x0369 => actor_action
0x096A => actor_info_request
0x0811 => actor_look_at
0x0368 => actor_name_request
0x0202 => buy_bulk_buyer
0x0817 => buy_bulk_closeShop
0x0815 => buy_bulk_openShop
0x0360 => buy_bulk_request
0x0940 => character_move
0x0361 => friend_request
0x0872 => homunculus_command
0x0947 => item_drop
0x0835 => item_list_res
0x095A => item_take
0x0819 => map_login
0x093E => party_join_request_by_name
0x083C => skill_use
0x0438 => skill_use_location
0x095D => storage_item_add
0x0954 => storage_item_remove
0x0873 => storage_password
0x0437 => sync



=cut
