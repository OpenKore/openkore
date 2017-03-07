#########################################################################
#  OpenKore - Packet Receiveing
#  This module contains functions for Receiveing packets to the server.
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#
#  $Revision: 6687 $
#  $Id: kRO.pm 6687 2009-04-19 19:04:25Z technologyguild $
########################################################################
# Korea (kRO)
# The majority of private servers use eAthena, this is a clone of kRO

package Network::Receive::kRO::Sakexe_2005_05_30a;

use strict;
use base qw(Network::Receive::kRO::Sakexe_2005_05_23a);

use Globals qw(%config $char);
use I18N qw(bytesToString);
use Log qw(message);
use Misc qw(configModify);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	my %packets = (
		'022E' => ['homunculus_property', 'Z24 C v16 V2 v2', [qw(name state level hunger intimacy accessory atk matk hit critical def mdef flee aspd hp hp_max sp sp_max exp exp_max points_skill attack_range)]], # 71
		'0235' => ['skills_list'], # -1 # homunculus skills
		# 0x0236,10
		'0238' => ['top10_pk_rank'], #  282
	);
	
	foreach my $switch (keys %packets) {
		$self->{packet_list}{$switch} = $packets{$switch};
	}

	return $self;
}

# attack_range param was added
sub homunculus_property {
	my ($self, $args) = @_;

	my $slave = $char->{homunculus} or return;

	foreach (@{$args->{KEYS}}) {
		$slave->{$_} = $args->{$_};
	}
	$slave->{name} = bytesToString($args->{name});

	Network::Receive::slave_calcproperty_handler($slave, $args);
	Network::Receive::kRO::Sakexe_0::homunculus_state_handler($slave, $args);

	# ST0's counterpart for ST kRO, since it attempts to support all servers
	# TODO: we do this for homunculus, mercenary and our char... make 1 function and pass actor and attack_range?
	# or make function in Actor class
	if ($config{homunculus_attackDistanceAuto} && $config{attackDistance} != $slave->{attack_range} && exists $slave->{attack_range}) {
		message TF("Autodetected attackDistance for homunculus = %s\n", $slave->{attack_range}), "success";
		configModify('homunculus_attackDistance', $slave->{attack_range}, 1);
		configModify('homunculus_attackMaxDistance', $slave->{attack_range}, 1);
	}
}


=pod
//2005-05-30aSakexe
0x022e,71
0x0235,-1
0x0236,10
0x0237,2,rankingpk,0
0x0238,282
=cut

1;