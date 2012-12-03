#########################################################################
#  OpenKore - Packet Receiveing
#  This module contains functions for Receiveing packets to the server.
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http:#//www.gnu.org/licenses/gpl.html for the full license.
#
#  $Revision: 6687 $
#  $Id: kRO.pm 6687 2009-04-19 19:04:25Z technologyguild $
########################################################################
# Korea (kRO)
# The majority of private servers use eAthena, this is a clone of kRO

package Network::Receive::kRO::RagexeRE_2010_03_09a;

use strict;
use base qw(Network::Receive::kRO::RagexeRE_2010_03_03a);
use Globals qw(%buyerLists @buyerListsID);
use Utils::DataStructures qw(binRemove);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
		my %packets = (
		'0816' => ['buying_store_lost', 'a4', [qw(ID)]], #6
	);

	foreach my $switch (keys %packets) {
		$self->{packet_list}{$switch} = $packets{$switch};
	}

	return $self; 
}
sub buying_store_lost {
	my ($self, $args) = @_;

	my $ID = $args->{ID};
	binRemove(\@buyerListsID, $ID);
	delete $buyerLists{$ID};
}
=pod
//2010-03-09aRagexeRE
//0x0813,-1
//0x0814,2
//0x0815,6
//0x0816,6
//0x0818,-1
//0x0819,10
//0x081A,4
//0x081B,4
//0x081C,6
//0x081D,22
//0x081E,8
=cut

1;