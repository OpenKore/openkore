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
package Network::Receive::bRO;

use strict;
use base qw(Network::Receive::ServerType0);
use Globals qw(@articles $playersList $shopEarned $articles);
use Log qw(message);
use Translation qw(T TF);
use Misc qw(shopLog closeShop);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	
	my %packets = (
		'0097' => ['private_message', 'v Z24 V Z*', [qw(len privMsgUser flag privMsg)]],
		'09CB' => ['skill_used_no_damage', 'v V a4 a4 C', [qw(skillID amount targetID sourceID success)]],
		'09E5' => ['shop_sold2', 'v2 a4 V2', [qw(number amount charID time zeny)]],
	);
	
	foreach my $switch (keys %packets) { $self->{packet_list}{$switch} = $packets{$switch}; }
	
	my %handlers = qw(
		received_characters 099D
		received_characters_info 082D
		sync_received_characters 09A0
	);

	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;
	
	return $self;
}

sub shop_sold2 {
	my ($self, $args) = @_;

	# sold something
	my $number = $args->{number};
	my $amount = $args->{amount};
	my $earned = $args->{zeny};

	$articles[$number]{sold} += $amount;
	$shopEarned += $earned;
	$articles[$number]{quantity} -= $amount;
	my $msg = TF("sold: %s - %s %sz\n", $amount, $articles[$number]{name}, $earned);
	shopLog($msg);
	message($msg, "sold");

	# Call hook before we possibly remove $articles[$number] or
	# $articles itself as a result of the sale.
	Plugins::callHook(
		'vending_item_sold',
		{
			#These first two entries are equivalent to $args' contents.
			'vendShopIndex' => $number,
			'amount' => $amount,
			'vendArticle' => $articles[$number], #This is a hash
		}
	);

	# Adjust the shop's articles for sale, and notify if the sold
	# item and/or the whole shop has been sold out.
	if ($articles[$number]{quantity} < 1) {
		message TF("sold out: %s\n", $articles[$number]{name}), "sold";
		#$articles[$number] = "";
		if (!--$articles){
			message T("Items have been sold out.\n"), "sold";
			closeShop();
		}
	}
}

*parse_quest_update_mission_hunt = *Network::Receive::ServerType0::parse_quest_update_mission_hunt_v2;
*reconstruct_quest_update_mission_hunt = *Network::Receive::ServerType0::reconstruct_quest_update_mission_hunt_v2;

1;