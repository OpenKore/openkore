#########################################################################
#  OpenKore - Network subsystem
#  Copyright (c) 2006 OpenKore Team
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#########################################################################
# twRO (Taiwan)
# Servertype overview: http://www.openkore.com/wiki/index.php/ServerType
package Network::Receive::twRO;

use strict;
use Globals;
use base qw(Network::Receive::ServerType0);
use Log qw(message warning error debug);
use Network::MessageTokenizer;

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	my %packets = (
		'0078' => ['actor_display',	'C a4 v14 a4 a2 v2 C2 a3 C3 v',				[qw(object_type ID walk_speed opt1 opt2 option type hair_style weapon lowhead shield tophead midhead hair_color clothes_color head_dir guildID emblemID manner opt3 karma sex coords unknown1 unknown2 act lv)]], # 55 # standing
		'007C' => ['actor_display',	'C a4 v14 C2 a3 C2',						[qw(object_type ID walk_speed opt1 opt2 option hair_style weapon lowhead type shield tophead midhead hair_color clothes_color head_dir karma sex coords unknown1 unknown2)]], # 42 # spawning 
		'022C' => ['actor_display', 'C a4 v3 V v5 V v5 a4 a2 v V C2 a6 C2 v',	[qw(object_type ID walk_speed opt1 opt2 option type hair_style weapon shield lowhead tick tophead midhead hair_color clothes_color head_dir guildID emblemID manner opt3 karma sex coords unknown1 unknown2 lv)]], # 65 # walking 
		'0097' => ['private_message', 'v Z28 Z*', [qw(len privMsgUser privMsg)]],
	);

	foreach my $switch (keys %packets) {
		$self->{packet_list}{$switch} = $packets{$switch};
	}

	return $self;
}

sub items_nonstackable {
	my ($self, $args) = @_;

	my $items = $self->{nested}->{items_nonstackable};

	if($args->{switch} eq '00A4' || # inventory
	   $args->{switch} eq '00A6' || # storage
	   $args->{switch} eq '0122'    # cart
	) {
		return $items->{type1};

	} elsif ($args->{switch} eq '0295' || # inventory
		 $args->{switch} eq '0296' || # storage
		 $args->{switch} eq '0297'    # cart
	) {
		return $items->{type2};

	} elsif ($args->{switch} eq '02D0' || # inventory
		 $args->{switch} eq '02D1' || # storage
		 $args->{switch} eq '02D2'    # cart
	) {
		return $items->{($rpackets{'00AA'} == 7)? "type3" : "type4"}; #Proved in twRO
	} else {
		warning("items_nonstackable: unsupported packet ($args->{switch})!\n");
	}
}

1;