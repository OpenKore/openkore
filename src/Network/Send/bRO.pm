#############################################################################
#  OpenKore - Network subsystem												#
#  This module contains functions for sending messages to the server.		#
#																			#
#  This software is open source, licensed under the GNU General Public		#
#  License, version 2.														#
#  Basically, this means that you're allowed to modify and distribute		#
#  this software. However, if you distribute modified versions, you MUST	#
#  also distribute the source code.											#
#  See http://www.gnu.org/licenses/gpl.html for the full license.			#
#############################################################################
# bRO (Brazil)
package Network::Send::bRO;
use strict;
use base 'Network::Send::ServerType0';
use Log qw(debug);
use Translation qw(T TF);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	
	my %handlers = qw(
		master_login 02B0
		buy_bulk_vender 0801
		party_setting 07D7
		send_equip 0998
		pet_capture 08B5
	);
	
	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;
	
	return $self;
}

sub sendTop10 {
	my ($self, $type) = @_;
	my $type_msg;
	
	$self->sendToServer(pack("v2", 0x097C, $type));
	
	if ($type == 0x0) { $type_msg = T("Blacksmith"); }
	elsif ($type == 0x1) { $type_msg = T("Alchemist"); }
	elsif ($type == 0x2) { $type_msg = T("Taekwon"); }
	elsif ($type == 0x3) { $type_msg = T("PK"); }
	else { $type_msg = T("Unknown"); }
	
	debug TF("Sent Top 10 %s request\n", $type_msg), "sendPacket", 2;
}

sub sendTop10Blacksmith {
	sendTop10(shift, 0x0);
}

sub sendTop10Alchemist {
	sendTop10(shift, 0x1);
}

sub sendTop10Taekwon {
	sendTop10(shift, 0x2);
}

sub sendTop10PK {
	sendTop10(shift, 0x3);
}

1;