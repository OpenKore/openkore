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

package Network::Receive::kRO::RagexeRE_2010_03_03a;

use strict;
use base qw(Network::Receive::kRO::RagexeRE_2010_02_23a);
use Log qw(message);
use Translation;

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	my %packets = (
		'0810' => ['open_buying_store', 'c', [qw(amount)]], #3
	);

	foreach my $switch (keys %packets) {
		$self->{packet_list}{$switch} = $packets{$switch};
	}

	return $self;
}

sub open_buying_store {
	my($self, $args) = @_;
	my $amount = $args->{amount};
	message TF("Your buying store can buy %d items \n", $amount);
}

=pod
//2010-03-03aRagexeRE
//0x0810,3
//0x0811,-1
//0x0812,86
//0x0813,6
//0x0814,6
//0x0815,-1
//0x0817,-1
//0x0818,6
//0x0819,4
=cut

1;