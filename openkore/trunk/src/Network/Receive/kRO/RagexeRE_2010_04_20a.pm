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

package Network::Receive::kRO::RagexeRE_2010_04_20a;

use strict;
use base qw(Network::Receive::kRO::RagexeRE_2010_04_14d);
use Globals qw(%buyerLists @buyerListsID);
use I18N qw(bytesToString);
use Utils::DataStructures qw(binAdd);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
		my %packets = (
		'0814' => ['buying_store_found', 'a4 Z*', [qw(ID title)]], #86
	);

	foreach my $switch (keys %packets) {
		$self->{packet_list}{$switch} = $packets{$switch};
	}

	return $self; 
}
sub buying_store_found {
	my ($self, $args) = @_;
	my $ID = $args->{ID};
	
	if (!$buyerLists{$ID} || !%{$buyerLists{$ID}}) {
		binAdd(\@buyerListsID, $ID);
		Plugins::callHook('packet_buying', {ID => unpack 'V', $ID});
	}
	$buyerLists{$ID}{title} = bytesToString($args->{title});
	$buyerLists{$ID}{id} = $ID;
}
=pod
//2010-04-20aRagexeRE
//0x0812,8
//0x0814,86
//0x0815,2
//0x0817,6
//0x0819,-1
//0x081a,4
//0x081b,10
//0x081c,10
//0x0824,6
=cut

1;