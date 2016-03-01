############################################################
#
# merchantdb
# version 0.1.3.6
# Copyright (C) 2004 nic0nac 
# 
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
# 
#
# The idea: 
# running around an manually checking prices from other mercs 
# is a pain. let a bot do the job. check on a web-site what he found.
# when the bot finds very cheap offers (hot-deals) let him buy it.
#
# What it does:
# when walked around in a given map with merchants the bot 
# checks at 'packet_vender' hook for available merchants. Now
# it searches in database table 'shopvisit' for the merchants user ID
# to check when the merc was visited the last time. if the last check 
# wasn't longer ago than $visitTimeout seconds, the bot will ask RO 
# for the mercs shop list and write the present date and time into the 
# database. 
# 
# at the hook 'packet_vender_store' mercDbFill will be called. it parses  
# the venderList and writes it into the mysql table 'shopcont'.
# 
# HOT DEALS:
# when you put in your config.txt item-names or 'all' after 'merchantDB_shoppinglist'
# the bot will buy it, when it is discovered as hot deal. it buys all hot-deals with 'all'.
# hot-deals are offered items with a price that is under the average price minus it's
# standard deviation. 
#
# the webfrontend is done in php, because i know php better than perl ;)
# it shows for all found items and cards the min, max, average price and the standard 
# deviation of the price, and the "hot-deal" barrier.
# you can search for cards inserted into items, as well as see what merc
# offered which items. and so on. should be self explaining.
#
# requirements:
# - any, even a new born RO char :)
# - openkore cvs
# - mysql database (can probably be changed to another database due to Mysql)
# - webserver with php-4 support
# - perl modules: Mysql, CGI::Enurl, Date::Format, TimeDate, DBD::mysql, DBI
#
# <quote=tofu_soldier>
# so, if any of you intended to get the plugin mercDB.pl running correctly
# in win32, get to ppm and have these installed:
# install CGI::Enurl
# (not sure if you need to do this as well)install CGI
# install TimeDate
# install Mysql
# install DBD::mysql
# </quote>
#
# Installation:
# - copy this file into the plugin folder of openkore
# - create a mysql database ($database)
# - create a new mysql-user that can read and write the roshop tables 
#   ($dbUser and $dbPassword)
# - set up the mysql tables with the roshop.sql file
# - change the mysql access informations here and in the index.php
# - put the following into your config.txt
#   merchantDB 1
#   # items you wanna buy, must be written like in the Vender Store List,
#   # separated by comma; make it "all" to buy all hot deals
#   merchantDB_shoppinglist Aquamarine, Red Potion, +6 Stiletto [Drops*2] [2]
# - copy the index.php on your webserver 
# - send your char into a city or other place where merchants are
# - have it walk around the merchants
# - check index.php for the results
#
# To-do:
# - performance problems
# - add NPC dealer prices 
#
# Fixed:
# - the name of the shop owner and the shops are right. the shop owner
#   might be updateted later but should be as good as openkore gives em
#   to the plugin
# - elemental weapons are recognized
# - update existing entries in the database (price changes etc.)
# - the number of slots is correct now
# - it works with the changed vender store list in cvs (openkore 1.3.0pre)
# - didn't occure to me for 2 weeks: after some time running, openkore crashes 
#   with an "segmentation fault" i can't tell if it is an problem caused by my 
#   plugin or a general openkore problem. parallel running bots not using this 
#   plugin do crash as well.
# 
# Known bugs:
#
# Planned features:
# - waypoint plugin: the bots walks along a predefined route
# - upload a store.txt to the web-frontend and get a version with best / 
#   average prices from the database
# - check the prices in-game via chat-commands send to the bot
#
# Note: 
# i tested this only on linux 2.6.5-7.95-default with mysql MySQL 4.0.18-Max, 
# PHP Version 4.3.4 so your mileage may vary.
#
# Thanks:
# - my bot-hating, RO-playing friends, who love the results of what i do with openkore ;)
# - the developers of openkore, without i would have stopped playing RO a long time ago
# - the members of the openkore-forum for theire support and feedback
# 
# Apologies:
# this plugin may be a total waste of time for you, because it only checks the 
# prices goods are offered for and not the prices of the sales. i offer my 
# excuses to you, but i found no way to check the real sales-prices.
# and i apologise for my bad english. my english teacher would laugh her ass of
# if she could read this ;) 



package merchantdb;

# i dont know if i need all of them
use Globals;
use strict;
use Plugins;
use Settings;
use Log qw(message warning error debug);

#use Mysql;
use DBI;
use CGI::Enurl;
use Date::Format;
use Date::Language;
#use Statistics::Basic::Mean;
#use Statistics::Basic::StdDev;

Plugins::register('merchantdb', 'little shopping helper.', \&Unload);
my $startHook = Plugins::addHook('start3', \&init);
my ($venderHook, $venderStoreHook, $charNameUpdateHook);

# seconds till next shopvisit
my $visitTimeout = 600; 

sub init {
	if ($Globals::config{'merchantDB'}) { 
		$venderHook = Plugins::addHook('packet_vender', \&Called);
		$venderStoreHook = Plugins::addHook('packet_vender_store', \&mercDbFill);
		$charNameUpdateHook = Plugins::addHook('charNameUpdate', \&charNameUpdate);
	}
}

my $result 	= 0;
# the database depending variables could be added to config.txt
my $dbUser	= "roshop";	# the name of the mysql user that has read/write access to database $database
my $dbPassword	= "roshop";	# his password
my $database	= "ro_shop";	# the used database
my $dbHostname	= "localhost";	# mysql server 
my $dbPort	= "3306";	# mysql server port
my $dsn		= "DBI:mysql:database=$database;host=$dbHostname;port=$dbPort"; 
my $dbh;

my $elementName;
my $starCrumbs;
my $insertTemp;
my $servername;

sub Unload {
	Plugins::delHook('start3', $startHook);
	if (defined $venderHook) {
		Plugins::delHook('packet_vender', $venderHook);
		Plugins::delHook('packet_vender_store', $venderStoreHook);
		Plugins::addHook('charNameUpdate', $charNameUpdateHook);
	}
}

sub Called{
	my $visitQuery;
	my $insertQuery;
	$servername = $::servers[$::config{'server'}]{'name'};
	$servername =~ s/\s+$//;
	
	# connecting to the database
	$dbh		= DBI->connect($dsn, $dbUser, $dbPassword) or die $dbh->errstr;

#	print "ID: " . unpack("L1",$::ID) . "\n";

	# we check all available merchants
	for (my $i = 0; $i < @::venderListsID; $i++) {
		next if ($::venderListsID[$i] eq "");
		my $shopOwnerID = unpack("L1",$::venderListsID[$i]);

		# we query the database for the last time we visited the merchant $shopOwnerID
		my $lastVisitQuery = "SELECT * FROM shopvisit WHERE shopOwnerID = '$shopOwnerID' AND server='$servername'";
		my $sth = $dbh->prepare($lastVisitQuery);
		$sth->execute or die $dbh->errstr;
		my $rv = $sth->rows;
		my $tooEarly = 0;
		if ($rv){
			my @row_ary = $sth->fetchrow_array;
			my $nextTime = @row_ary[2] + $visitTimeout;
			if (($nextTime) < time) {
				# if the last visit isnt long enough away we set the flag $tooEarly
				$tooEarly = -1;
			}
		}
		
		if ((!$rv) || ($tooEarly)){
			# merchant was never visited before or the last visit is long enough away
			# tell kore to get the venderList
			main::sendEnteringVender(\$::remote_socket, $::venderListsID[$i]);
			
			# update shopvisit database
			my $selectQuery = "SELECT * FROM shopvisit WHERE shopOwnerID = '$shopOwnerID' AND server='$servername'";
#			print $selectQuery . "\n";
			my $sth = $dbh->prepare($selectQuery);
			$sth->execute or die $dbh->errstr;

			my $rv = $sth->rows;
			
			if ($rv){
				$visitQuery = "UPDATE shopvisit SET shopOwnerID = '$shopOwnerID', time = " . time . " WHERE shopOwnerID = '$shopOwnerID' AND server='$servername'";
			} else {
				$visitQuery = "INSERT INTO shopvisit SET shopOwnerID = '$shopOwnerID', time = " . time . ", server='$servername'";
			}
			
			my $sth2 = $dbh->prepare($visitQuery);
			$sth2->execute or die $dbh->errstr;
			
		}
	}
	$dbh->disconnect;
	return $result;
}

### 
### mercDbFill()
###
### writes shop informations into database
###
###

###
### Database Structure 
###
### s. ro_database.sql
	
sub mercDbFill{
	my $itemName;
	my $shopName ;
	my $datum = time2str("%d.%m.%Y %T", time);
	my $map;
	my $card1ID = 0;
	my $card2ID = 0;
	my $card3ID = 0;
	my $card4ID = 0;
	my $avg_price;
	my $std_price;
	$elementName = "";
	$starCrumbs = "";
	
	$servername = $::servers[$::config{'server'}]{'name'};
	$servername =~ s/\s+$//;
	
	# connecting to the database
	$dbh = DBI->connect($dsn, $dbUser, $dbPassword) or die $dbh->errstr;

	#print "Shop-Owner: " . $shopOwner . "(" . $shopOwnerID .")\n";
	#print "Shop-Array: " . $::venderItemList . "\n";
	if (!($::venderItemList[$::number]{'name'} eq "")) {

		#
		# check if the offered items are already in the database
		#
		
		my $shopOwnerID = unpack("L1",$::venderID);
		my $shopOwner = $::players{$::venderID}{'name'};
		$shopOwner =~ s/\\/\\\\/g;
		$shopOwner =~ s/'/\\'/g;
		my $iid = $::venderItemList[$::number]{'nameID'};
		my $custom = unpack("C1", substr($::msg, $::i + 13, 1));
		my $cardDB = substr($::msg, $::i + 14, 8);
		my $suffix = "";
		my @cards;
		my %cards;
		for (my $i = 0; $i < 4; $i++) {
			my $card = unpack("S1", substr($cardDB, $i*2, 2));
			last unless $card;
			push(@cards, $card);
			($cards{$card} ||= 0) += 1;
		}
		
		if ($cards[0] == 254) {
			# Alchemist-made potion
			#
			# Ignore the "cards" inside.
		} elsif ($cards[0] == 255) {
			# Forged item
			#
			my $elementID = $cards[1] % 10;
			$elementName = $::elements_lut{$elementID};
			$starCrumbs = ($cards[1] >> 8) / 5;	
		} elsif (@cards) {
			# Carded item
			#
			# List cards in alphabetical order.
			# Stack identical cards.
			# e.g. "Hydra*2,Mummy*2", "Hydra*3,Mummy"
			$card1ID = ($cards[0]>0?$cards[0]:0);
			$card2ID = ($cards[1]>0?$cards[1]:0);
			$card3ID = ($cards[2]>0?$cards[2]:0);
			$card4ID = ($cards[3]>0?$cards[3]:0);
		}
		
		#
		# hot deal check
		# this is placed here, because here are all needed variables filled
		
		# query for the average price and the standard deviation of all prices for this item
		
		my $avg_std_query = "SELECT AVG( price ) AS mid, STD( price ) AS dev FROM `shopcont` ";
		$avg_std_query .= " WHERE itemID = '$iid'";
		$avg_std_query .= " AND custom = '$custom'";
		$avg_std_query .= " AND server = '$servername'";
		$avg_std_query .= " AND card1ID = '$card1ID'";
		$avg_std_query .= " AND card2ID = '$card2ID'";
		$avg_std_query .= " AND card3ID = '$card3ID'";
		$avg_std_query .= " AND card4ID = '$card4ID'";
		$avg_std_query .= " AND element = '$elementName'";
		$avg_std_query .= " AND star_crumb = '$starCrumbs'";
		$avg_std_query .= " GROUP BY itemID;";
		
#		print $avg_std_query . "\n";

		my $sth = $dbh->prepare($avg_std_query);
		$sth->execute or die $dbh->errstr;

		my $rv_avg = $sth->rows;
#		print "erg: $rv_avg \n";
		if ($rv_avg) {
			my @avgStd = $sth->fetchrow_array;
			$avg_price = @avgStd[0];
			$std_price = @avgStd[1];
#			print "avg: " . @avgStd[0] . " / std: " . @avgStd[1] . "\n";
		}
		
		# if actual price is lower than average price minus standard deviation it's a HOT DEAL
		
		my $barrier_price = $avg_price - $std_price;
		if ($::venderItemList[$::number]{'price'} < $barrier_price){
			#
			# HOT DEAL !!!!!!!!!!!!
			#
			print " HOT DEAL !!!!!!!!! \n";	
#			print $avg_price . " - " . $std_price . " = " . $barrier_price . " // price: " . $::venderItemList[$::number]{'price'} ."\n";
#			print $avg_std_query . "\n";
			
			my @shoppinglist = split(/,/, $Settings::config{"merchantDB_shoppinglist"});
			my $buyitem;
			my $itemNameLong;
			$itemNameLong = ::itemName({nameID => $iid, cards => $cardDB, upgrade => $custom});
			foreach $buyitem(@shoppinglist){
				$buyitem =~ s/^ +//;
				$buyitem =~ s/ +$//;
#				print "bi: " . $buyitem . " / in: " . $itemNameLong . "\n";
				if (($buyitem eq "all") || ($buyitem eq $itemNameLong)){					
					# ok, its in our list ...
					if ($chars[$config{'char'}]{'zenny'} >= $::venderItemList[$::number]{'price'}){
						# ... and we have the money to buy it, let's go shopping
						::sendBuyVender(\$::remote_socket, $::venderID, $::number, 1);
					} else {
						print " ... but no money!\n";
					}
				} else {
					print " ... not on my list!\n";
				}
			}	
		}
		
		# hot deal check END
		#
		
		my $selectQuery = "SELECT * FROM shopcont WHERE";
		$selectQuery .= " shopOwnerID = '$shopOwnerID'";
		$selectQuery .= " AND itemID = '$iid'";
		$selectQuery .= " AND custom = '$custom'";
		$selectQuery .= " AND server = '$servername'";
		$selectQuery .= " AND card1ID = '$card1ID'";
		$selectQuery .= " AND card2ID = '$card2ID'";
		$selectQuery .= " AND card3ID = '$card3ID'";
		$selectQuery .= " AND card4ID = '$card4ID'";
		$selectQuery .= " AND element = '$elementName' \n";
		$selectQuery .= " AND star_crumb = '$starCrumbs' \n";
		
#		print $selectQuery . "\n";
		my $sth = $dbh->prepare($selectQuery);
		$sth->execute or die $dbh->errstr;

		my $rv = $sth->rows;
#		print "erg: $rv \n";
		my $test;
		my $insertQuery2 = "";
		
		$insertTemp = " custom = '" . $custom . "', \n";
		if ($cards[0] == 255) {
			# Forged item
			#
			# Display e.g. "VVS Earth" or "Fire"
			my $elementID = $cards[1] % 10;
			$elementName = $::elements_lut{$elementID};
			$starCrumbs = ($cards[1] >> 8) / 5;
			$suffix .= ('V'x$starCrumbs)."S " if $starCrumbs;
			$suffix .= $elementName;
			
			$insertTemp .= " element = '$elementName', \n";
			$insertTemp .= " star_crumb = '$starCrumbs', \n";
			
			# the second card slot holds the user_id of the BS who crafted the weapon
			#$insertQuery2 .= " crafted_by = '" . $cards[3] . "', \n";
			
		} elsif (@cards) {
			# Carded item
			#
			# List cards in alphabetical order.
			# Stack identical cards.
			# e.g. "Hydra*2,Mummy*2", "Hydra*3,Mummy"
			#$suffix = join(',', map { 
			#	cardName($_).($cards{$_} > 1 ? "*$cards{$_}" : '')
			#} sort { cardName($a) cmp cardName($b) } keys %cards);
			
			for (my $c=0; $c<=4; $c++){
				if ($cards[$c]) {
					my $d = $c + 1;
					$insertTemp .= " card" . $d . "ID = '" . $cards[$c] . "', \n";
					$insertQuery2 .= " card" . $d . " = '". main::cardName($cards[$c])."', \n";
				}
			}	
		}
		
		
		if (!$rv) {
		
			#
			# this item wasn't offered by this dealer on this server
			#
			
			$itemName = $::venderItemList[$::number]{'name'};
			$itemName = main::itemNameSimple($iid);
			$itemName =~ s/\\/\\\\/g;
			$itemName =~ s/'/\\'/g;
			my $shopOwnerIDBin = pack("L1",$shopOwnerID);
			$shopName = $::venderLists{$shopOwnerIDBin}{'title'};
			$shopName =~ s/\\/\\\\/g;
			$shopName =~ s/'/\\'/g;
			my $insertQuery = "INSERT INTO shopcont SET
			shopOwnerID = '$shopOwnerID', 
			shopOwner = '" . $shopOwner . "', 
			shopName = '" . $shopName . "', 
			itemID = '" . $iid . "', 
			name = '" . $itemName . "', 
			amount = " . $::venderItemList[$::number]{'amount'} . ", 
			typus = '" . $::itemTypes_lut{$::venderItemList[$::number]{'type'}} . "', 
			identifiziert = '" . $::venderItemList[$::number]{'identified'} . "', \n"; 
			
			my $slots = 0;
			$slots = $itemSlotCount_lut{$iid};
			$insertQuery .= " slots = '$slots', \n";
			
			$insertQuery .= $insertQuery2 . $insertTemp;
			$insertQuery .= " price = " . $::venderItemList[$::number]{'price'} . ", \n";
			$insertQuery .= " posx = '" . $::players{pack("L1",$shopOwnerID)}{'pos_to'}{'x'} . "', \n";
			$insertQuery .= " posy = '" . $::players{pack("L1",$shopOwnerID)}{'pos_to'}{'y'} . "', \n";
			$insertQuery .= " time = " . time . ", \n";
			$insertQuery .= " datum = '" . $datum ."', \n";
			($map) = $::map_name =~ /([\s\S]*)\.gat/;
			$insertQuery .= " map = '" . $map . "', ";
			$insertQuery .= " server = '$servername'";
			$insertQuery .= ";";
#			print $insertQuery . "\n";

			my $sth2 = $dbh->prepare($insertQuery);
			$sth2->execute or die $dbh->errstr;
			
			undef $insertQuery;
			
		} else {
		
			#
			# update existing entries
			#
			
			my $updateItem = 0;
			my $updateQuery = "";
			my @existingItem = $sth->fetchrow_array;
#			print "name: " . @existingItem[2] . " : " . $shopOwner . "\n";
			# shopOwner name has changed
			if (($shopOwner ne "Unknown") && (@existingItem[2] ne $shopOwner)){
				$updateItem = -1;
				$updateQuery .= "shopOwner = '$shopOwner'";
				if ($updateItem){
					my $updateQuery2 = "UPDATE shopcont SET " . $updateQuery;
					$updateQuery2 .= ", datum = '" . $datum ."'";
					$updateQuery2 .= ", time = " . time;
					$updateQuery2 .= " WHERE shopOwnerID=" . @existingItem[1] . " AND server='$servername'";
#					print $updateQuery2 . "\n";
					
					my $sth = $dbh->prepare($updateQuery2);
					$sth->execute or die $dbh->errstr;
				}
			}
			
			# price has changed
			if (@existingItem[19] != $::venderItemList[$::number]{'price'}){
				if ($updateItem) {
					$updateQuery .= ", ";
				}
				$updateItem = -1;
				$updateQuery .= "price = '" . $::venderItemList[$::number]{'price'} . "'";
			}
			
			# amount has changed
                        if (@existingItem[6] != $::venderItemList[$::number]{'amount'}){
                                if ($updateItem) {
                                        $updateQuery .= ", ";
                                }
                                $updateItem = -1;
                                $updateQuery .= "amount = '" . $::venderItemList[$::number]{'amount'} . "'";
                        }

			# pos_x has changed
			if (@existingItem[21] != $::players{pack("L1",$shopOwnerID)}{'pos_to'}{'x'}){
                                if ($updateItem) {
                                        $updateQuery .= ", ";
                                }
                                $updateItem = -1;
                                $updateQuery .= "posx = '" .  $::players{pack("L1",$shopOwnerID)}{'pos_to'}{'x'} . "'";
                        }

			# pos_y has changed
			if (@existingItem[22] != $::players{pack("L1",$shopOwnerID)}{'pos_to'}{'y'}){
                                if ($updateItem) {
                                        $updateQuery .= ", ";
                                }
                                $updateItem = -1;
                                $updateQuery .= "posy = '" .  $::players{pack("L1",$shopOwnerID)}{'pos_to'}{'y'} . "'";
                        }

			if ($updateItem){
				$updateQuery = "UPDATE shopcont SET " . $updateQuery;
				$updateQuery .= ", datum = '" . $datum ."'";
				$updateQuery .= ", time = " . time;
				$updateQuery .= " WHERE id=" . @existingItem[0] . " AND server='$servername'";
#				print $updateQuery . "\n";
				
				my $sth = $dbh->prepare($updateQuery);
				$sth->execute or die $dbh->errstr;
			}	
			
			undef $updateQuery;
		}
		
		undef $shopOwnerID;
		undef $shopOwner;
	}
	$dbh->disconnect;
	return $result;
}

### 
### charNameUpdate()
###
### the name of another player has changed. the database gets updated
###
###
	
sub charNameUpdate{

	$servername = $::servers[$::config{'server'}]{'name'};
	$servername =~ s/\s+$//;
	
	$dbh = DBI->connect($dsn, $dbUser, $dbPassword) or die $dbh->errstr;
	my $datum	= time2str("%d.%m.%Y %T", time);
	
	my $shopOwnerID = unpack("L1",$::ID);
	my $shopOwner = $::players{$::ID}{'name'};
	$shopOwner =~ s/\\/\\\\/g;
	$shopOwner =~ s/'/\\'/g;
	
	if (($shopOwner ne "Unknown") && ($shopOwner ne "")){
		my $updateQuery2 = "UPDATE shopcont SET shopOwner='$shopOwner'";
		$updateQuery2 .= ", datum = '" . $datum ."'";
		$updateQuery2 .= ", time = " . time;
		$updateQuery2 .= " WHERE shopOwnerID=$shopOwnerID AND server = '$servername'";
#		print $updateQuery2 . "\n";
		my $sth = $dbh->prepare($updateQuery2);
		$sth->execute or die $dbh->errstr;
	}
	undef $shopOwnerID;
	undef $shopOwner;
	$dbh->disconnect;
	return 1;
}


return 1;
