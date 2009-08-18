#  kRO Client 2009-02-25b (eA packet version 23)
# Servertype overview: http://www.openkore.com/wiki/index.php/ServerType
package Network::Receive::ServerType8_5;

use strict;
use Network::Receive;
use base qw(Network::Receive);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new;
	
	# OLD $self->{packet_list}{'0078'} = ['actor_display', 'x1 a4 v14 a4 x7 C1 a3 x2 C1 v1', [qw(ID walk_speed opt1 opt2 option type hair_style weapon lowhead shield tophead midhead hair_color clothes_color head_dir guildID sex coords act lv)]];
	# OLD $self->{packet_list}{'007C'} = ['actor_display', 'x1 a4 v14 C2 a3 C2', [qw(ID walk_speed opt1 opt2 option hair_style weapon lowhead type shield tophead midhead hair_color clothes_color head_dir karma sex coords unknown1 unknown2)]];
	# OLD $self->{packet_list}{'022C'} = ['actor_display', 'x1 a4 v4 x2 v5 V1 v3 x4 a4 a4 v x2 C2 a5 x3 v', [qw(ID walk_speed opt1 opt2 option type hair_style weapon shield lowhead timestamp tophead midhead hair_color guildID emblemID visual_effects stance sex coords lv)]];

	$self->{packet_list}{'0078'} = ['actor_display', 'x a4 v14 a4 a2 v2 C2 a3 C3 v', [qw(ID walk_speed opt1 opt2 option type hair_style weapon lowhead shield tophead midhead hair_color clothes_color head_dir guildID emblemID manner opt3 karma sex coords unknown1 unknown2 act lv)]]; #standing
	$self->{packet_list}{'007C'} = ['actor_display', 'x a4 v14 C2 a3 C2', [qw(ID walk_speed opt1 opt2 option hair_style weapon lowhead type shield tophead midhead hair_color clothes_color head_dir karma sex coords unknown1 unknown2)]]; #spawning
	$self->{packet_list}{'022C'} = ['actor_display', 'x a4 v3 V v5 V v5 a4 a2 v V C2 a5 x C2 v', [qw(ID walk_speed opt1 opt2 option type hair_style weapon shield lowhead tick tophead midhead hair_color clothes_color head_dir guildID emblemID manner opt3 karma sex coords unknown1 unknown2 lv)]]; # walking

	return $self;
}

# Overrided method.
sub received_characters_blockSize {
	return 108;
}

1;
