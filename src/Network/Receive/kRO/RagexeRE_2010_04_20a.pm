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

package Network::Receive::kRO::RagexeRE_2010_04_20a;

use strict;
use base qw(Network::Receive::kRO::RagexeRE_2010_04_14d);
use Globals qw(%buyerLists @buyerListsID $char @selfBuyerItemList);
use I18N qw(bytesToString);
use Log qw(error message);
use Misc qw(inventoryItemRemoved itemNameSimple);
use Utils::DataStructures qw(binAdd);
use Translation;

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
		my %packets = (
		'0814' => ['buying_store_found', 'a4 Z*', [qw(ID title)]], #86
		'081A' => ['buying_buy_fail', 'v', [qw(result)]], #4
		'081B' => ['buying_store_update', 'v2 V', [qw(itemID count zeny)]], #10
		'081C' => ['buying_store_item_delete', 'v2 V', [qw(index amount zeny)]], #10
		'0824' => ['buying_store_fail', 'v2', [qw(result itemID)]], #6
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

sub buying_buy_fail {
	my ($self, $args) = @_;
	if ($args->{result} == 3) {
		error T("Failed to buying (insufficient zeny).\n");
	} elsif ($args->{result} == 4) {
		message T("Buying up complete.\n");
	} else {
		error TF("Failed to buying (unknown error: %s).\n", $args->{result});
	}
}

sub buying_store_update {
	my($self, $args) = @_;
	if(@selfBuyerItemList) {
		for(my $i = 0; $i < @selfBuyerItemList; $i++) {
			print "$_->{amount}          $args->{count}\n";
			$_->{amount} = $args->{count} if($_->{itemID} == $args->{itemID});
			print "$_->{amount}          $args->{count}\n";
		}
	}
}

sub buying_store_item_delete {
	my($self, $args) = @_;
	return unless changeToInGameState();
	my $item = $char->inventory->getByServerIndex($args->{index});
	my $zeny = $args->{amount} * $args->{zeny};
	if ($item) {
	#	buyingstoreitemdelete($item->{invIndex}, $args->{amount});
		inventoryItemRemoved($item->{invIndex}, $args->{amount});
	#	Plugins::callHook('buying_store_item_delete', {index => $item->{invIndex}});
	}
	message TF("You have sold %s. Amount: %s. Total zeny: %sz\n", $item, $args->{amount}, $zeny);# msgstring 1747

}
sub changeToInGameState {
	Network::Receive::changeToInGameState;
}

sub buying_store_fail {
	my ($self, $args) = @_;
	if ($args->{result} == 5) {
		error T("The deal has failed.\n");# msgstring 58
	} 	elsif ($args->{result} == 6) {
		error TF("%s item could not be sold because you do not have the wanted amount of items.\n", itemNameSimple($args->{itemID}));# msgstring 1748
	} 	elsif ($args->{result} == 7) {
		error T("Failed to deal because you have not enough Zeny.\n");# msgstring 1746
	} else {
		error TF("Unknown 'buying_store_fail' result: %s.\n", $args->{result});
	}
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