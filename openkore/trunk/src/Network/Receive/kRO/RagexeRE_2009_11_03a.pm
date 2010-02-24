#########################################################################
#	OpenKore - Packet sending
#	This module contains functions for sending packets to the server.
#
#	This software is open source, licensed under the GNU General Public
#	License, version 2.
#	Basically, this means that you're allowed to modify and distribute
#	this software. However, if you distribute modified versions, you MUST
#	also distribute the source code.
#	See http://www.gnu.org/licenses/gpl.html for the full license.
#
#	$Revision: 6687 $
#	$Id: kRO.pm 6687 2009-04-19 19:04:25Z technologyguild $
########################################################################
# Korea (kRO)
# The majority of private servers use eAthena, this is a clone of kRO

package Network::Receive::kRO::RagexeRE_2009_11_03a;

use strict;
use base qw(Network::Receive::kRO::RagexeRE_2009_10_27a);
#use Log qw(error);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	my %packets = (
		'07F7' => ['actor_display', 'v C a4 v3 V v5 a4 v5 a4 a2 v V C2 a6 C2 v2 Z*',	[qw(len object_type ID walk_speed opt1 opt2 option type hair_style weapon shield lowhead tick tophead midhead hair_color clothes_color head_dir guildID emblemID manner opt3 karma sex coords xSize ySize lv font name)]], # -1 # walking
		'07F8' => ['actor_display', 'v C a4 v3 V v10 a4 a2 v V C2 a3 C2 v2 Z*',			[qw(len object_type ID walk_speed opt1 opt2 option type hair_style weapon shield lowhead tophead midhead hair_color clothes_color head_dir guildID emblemID manner opt3 karma sex coords xSize ySize lv font name)]], # -1 # spawning
		'07F9' => ['actor_display', 'v C a4 v3 V v10 a4 a2 v V C2 a3 C3 v2 Z*',			[qw(len object_type ID walk_speed opt1 opt2 option type hair_style weapon shield lowhead tophead midhead hair_color clothes_color head_dir guildID emblemID manner opt3 karma sex coords xSize ySize act lv font name)]], # -1 # standing
	);

	foreach my $switch (keys %packets) {
		$self->{packet_list}{$switch} = $packets{$switch};
	}

	return $self;
}

=pod testing of object_type
my $actor = {
	0x0 => 'PC_TYPE',				# player
	0x1 => 'NPC_TYPE',
	0x2 => 'ITEM_TYPE',
	0x3 => 'SKILL_TYPE',
	0x4 => 'UNKNOWN_TYPE',
	0x5 => 'NPC_MOB_TYPE',			# monster
	0x6 => 'NPC_EVT_TYPE',			# npc
	0x7 => 'NPC_PET_TYPE',
	0x8 => 'NPC_HO_TYPE',			# homunculus
	0x9 => 'NPC_MERSOL_TYPE',
	0xa => 'NPC_ELEMENTAL_TYPE',
};

sub actor_display {
	my ($self, $args) = @_;
	$self->SUPER::actor_display($args);
	my $unpacked;
	if ($args->{switch} eq "07F7") {
		$unpacked = "move: 07F7, " . join(', ', @{$args}{qw(len object_type _ID walk_speed opt1 opt2 option type hair_style weapon shield lowhead _tick tophead midhead hair_color clothes_color head_dir _guildID _emblemID manner opt3 karma sex _coords xSize ySize lv font name)});
	} elsif ($args->{switch} eq "07F8") {
		$unpacked = "spawn: 07F8, " . join(', ', @{$args}{qw(len object_type _ID walk_speed opt1 opt2 option type hair_style weapon shield lowhead tophead midhead hair_color clothes_color head_dir _guildID _emblemID manner opt3 karma sex _coords xSize ySize lv font name)});
	} elsif ($args->{switch} eq "07F9") {
		$unpacked = "stand: 07F9, " . join(', ', @{$args}{qw(len object_type _ID walk_speed opt1 opt2 option type hair_style weapon shield lowhead tophead midhead hair_color clothes_color head_dir _guildID _emblemID manner opt3 karma sex _coords xSize ySize act lv font name)});
	}
	error ("$unpacked\n");
	error ("Actor type: $actor->{$args->{object_type}}\n");
}
=cut

=pod
//2009-11-03aRagexeRE
//0x07f7,0
//0x07f8,0
//0x07f9,0
=cut

1;