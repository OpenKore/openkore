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
########################################################################
# Korea (kRO) #bysctnightcore
# The majority of private servers use eAthena, this is a clone of kRO
package Network::Receive::kRO::RagexeRE_2018_02_21a;
use strict;
use base qw(Network::Receive::kRO::RagexeRE_2018_02_13a);
use I18N qw(bytesToString stringToBytes);
use Log qw(message debug error);
use Translation;

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	
	my %packets = (
		'0AF7' => ['character_name', 'x2 a4 Z24', [qw(flag ID name)]],	
		'0206' => ['friend_logon1', 'a4 a4 C Z24', [qw(friendAccountID friendCharID isNotOnline charname)]],
	);
	
	$self->{packet_list}{$_} = $packets{$_} for keys %packets;
	
	return $self;
}

sub friend_logon1 {
	my ($self, $args) = @_;
	if ($args->{isNotOnline} = 0) {
		message TF("Friend %s has connected\n", bytesToString($args->{charname}));
	} else {
		message TF("Friend %s has disconnected\n", bytesToString($args->{charname}));
	}
}


1;
