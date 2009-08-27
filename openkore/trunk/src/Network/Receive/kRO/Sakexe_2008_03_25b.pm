#########################################################################
#  OpenKore - Packet sending
#  This module contains functions for sending packets to the server.
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

package Network::Receive::kRO::Sakexe_2008_03_25b;

use strict;
use Network::Receive::kRO::Sakexe_2008_03_18a;
use base qw(Network::Receive::kRO::Sakexe_2008_03_18a);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	my %packets = (
		# 0x02f3,-1
		# 0x02f4,-1
		# 0x02f5,-1
		# 0x02f6,-1
		# 0x02f7,-1
		# 0x02f8,-1
		# 0x02f9,-1
		# 0x02fa,-1
		# 0x02fb,-1
		# 0x02fc,-1
		# 0x02fd,-1
		# 0x02fe,-1
		# 0x02ff,-1
		# 0x0300,-1
	);
	
	foreach my $switch (keys %packets) {
		$self->{packet_list}{$switch} = $packets{$switch};
	}

	return $self;
}


=pod

//2008-03-25bSakexe
0x02f3,-1
0x02f4,-1
0x02f5,-1
0x02f6,-1
0x02f7,-1
0x02f8,-1
0x02f9,-1
0x02fa,-1
0x02fb,-1
0x02fc,-1
0x02fd,-1
0x02fe,-1
0x02ff,-1
0x0300,-1
=cut

1;