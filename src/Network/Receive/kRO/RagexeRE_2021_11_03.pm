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
# Korea (kRO) # by alisonrag
# The majority of private servers use eAthena, this is a clone of kRO
package Network::Receive::kRO::RagexeRE_2021_11_03;
use strict;
use base qw(Network::Receive::kRO::RagexeRE_2020_07_23);
use Globals qw($masterServer $messageSender);
use Plugins;

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	my %packets = (
		# Lastro emits this zero-filled 2560-byte map initialization frame
		# before its load-info and offline-message packets.
		'0000' => ['lastro_ignored'],
		'0AD5' => ['second_check', 'V V', [qw(pincode AID)]], #10
		'0AD6' => ['lastro_ignored'],
		# ZC_NOTIFY_SETTARGET is a target ID followed by a target-state byte.
		# It is a 7-byte packet in the Lastro web client, unlike the stock 2021
		# client packet recorded in the original recvpackets table.
		'0AF1' => ['lastro_ignored'],
		'0AF5' => ['lastro_loadinfo', 'a43 C a12', [qw(unknown startAutofollow trailing)]], #58
		'0AF6' => ['lastro_reload_info', 'C V', [qw(id value)]], #7
		'0AFC' => ['lastro_ignored'],
		'0B7A' => ['npc_market_info', 'v a*', [qw(len itemList)]], # Lastro NPC market list
	);

	$self->{packet_list}{$_} = $packets{$_} for keys %packets;
	# Lastro extends ZC_NPC_MARKET_OPEN with the item's map location.
	$self->{npc_market_info_pack} = 'V C V2 v x4';

	return $self;
}

sub second_check {
	my ($self, $args) = @_;
	$messageSender->sendCheckBin($args->{AID}, $args->{pincode});
}

sub lastro_ignored {
}

sub lastro_loadinfo {
	my ($self, $args) = @_;
	return unless $masterServer && $masterServer->{lastroAutoFollow};

	Plugins::callHook('lastro_autofollow_state', {
		enabled => $args->{startAutofollow} ? 1 : 0,
		source => 'loadinfo',
	});
}

sub lastro_reload_info {
	my ($self, $args) = @_;
	return unless $masterServer && $masterServer->{lastroAutoFollow};
	return unless defined $args->{id} && $args->{id} == 37;

	Plugins::callHook('lastro_autofollow_state', {
		enabled => $args->{value} ? 1 : 0,
		source => 'reloadinfo',
	});
}

1;
