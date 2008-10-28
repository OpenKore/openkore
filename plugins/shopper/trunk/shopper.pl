package shopper;

#
# This plugin is licensed under the GNU GPL
# Copyright 2006 by kaliwanagan
# --------------------------------------------------
#

use strict;
use Plugins;
use Globals;
use Log qw(message warning error debug);
use AI;
use Misc;
use Network;
use Network::Send;

Plugins::register('shopper', 'automatically buy items from merchant vendors', \&Unload);
my $AI_pre = Plugins::addHook('AI_pre', \&AI_pre);
my $encounter = Plugins::addHook('packet_vender', \&encounter);
my $storeList = Plugins::addHook('packet_vender_store', \&storeList);

my @vendorList;

sub Unload {
	Plugins::delHook('AI_pre', $AI_pre);
	Plugins::delHook('packet_vender', $encounter);
	Plugins::delHook('packet_vender_store', $storeList);
}

my $delay = 1;
my $time = time;

sub AI_pre {
	if (AI::is('checkShop') && main::timeOut($time, $delay)) {
		my $vendorID = AI::args->{vendorID};
		$messageSender->sendEnteringVender($vendorID);
		AI::dequeue;
	}
	$time = time;
}

# we encounter a vend shop
sub encounter {
	my ($packet, $args) = @_;
	my $ID = $args->{ID};

	# don't check the same store twice
	# FIXME: clear the vendor list from time to time or else
	# it will get very large
	#foreach my $vendorID (@vendorList) {
	#	return if ($ID == $vendorID);
	#}
	#push (@vendorList, $ID);
	AI::queue('checkShop', {vendorID => $ID});
}

# we're currently inside a store if we receive this packet
sub storeList {
	my ($packet, $args) = @_;
	my $venderID = $args->{venderID};
	my $price = $args->{price};
	my $name = $args->{name};
	my $number = $args->{number};
	my $amount = $args->{amount};

	my $prefix = "shopper_";
	my $i = 0;
	while (exists $config{$prefix.$i}) {
		my $maxPrice = $config{$prefix.$i."_maxPrice"};
		my $maxAmount = $config{$prefix.$i."_maxAmount"};

		my $invIndex = main::findIndexString_lc($char->{'inventory'}, "name", $config{$prefix.$i});
		my $item = $char->{'inventory'}[$invIndex];

		if (main::checkSelfCondition($prefix.$i) &&
			($price <= $maxPrice) &&
			(lc($name) eq lc($config{$prefix.$i}))
			)
		{
			message "$name found!!! Buying it for $price (max price: $maxPrice).\n";
			$messageSender->sendBuyVender($venderID, $number, $maxAmount);
			configModify($prefix.$i."_disabled", 1);
		}
		$i++;
	}
}

return 1;

