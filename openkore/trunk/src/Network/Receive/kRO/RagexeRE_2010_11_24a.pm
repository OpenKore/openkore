package Network::Receive::kRO::RagexeRE_2010_11_24a;

use strict;
use base qw(Network::Receive::kRO::RagexeRE_2010_08_03a);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	
	my %packets = (
		'0856' => ['actor_display', 'v C a4 v3 V v5 a4 v6 a4 a2 v V C2 a6 C2 v2 Z*', [qw(len object_type ID walk_speed opt1 opt2 option type hair_style weapon shield lowhead tick tophead midhead hair_color clothes_color head_dir costume guildID emblemID manner opt3 stance sex coords xSize ySize lv font name)]], # -1 # walking provided by try71023 TODO: costume
		'0857' => ['actor_display', 'v C a4 v3 V v11 a4 a2 v V C2 a3 C3 v2 Z*', [qw(len object_type ID walk_speed opt1 opt2 option type hair_style weapon shield lowhead tophead midhead hair_color clothes_color head_dir costume guildID emblemID manner opt3 stance sex coords xSize ySize act lv font name)]], # -1 # spawning provided by try71023
		'0858' => ['actor_display', 'v C a4 v3 V v11 a4 a2 v V C2 a3 C2 v2 Z*', [qw(len object_type ID walk_speed opt1 opt2 option type hair_style weapon shield lowhead tophead midhead hair_color clothes_color head_dir costume guildID emblemID manner opt3 stance sex coords xSize ySize lv font name)]], # -1 # standing provided by try71023
		# 0x0859,-1
	);
	foreach my $switch (keys %packets) {
		$self->{packet_list}{$switch} = $packets{$switch};
	}
	
	return $self;
}

1;
