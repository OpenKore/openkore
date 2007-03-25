############################################################
#
# merchantdb
# version 0.1.3.8
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
############################################################

package merchantdb;

use Globals;
use strict;
use Plugins;
use Settings;
use Log qw(message warning error debug);
use DBI;
use POSIX qw(strftime);

Plugins::register('merchantdb', 'little shopping helper.', \&Unload);
my $startHook = Plugins::addHook('start3', \&init);
my ($venderHook, $venderStoreHook2, $charNameUpdateHook);

# seconds till next shopvisit
my $visitTimeout = 600; 

sub init {
	if ($Globals::config{'merchantDB'}) { 
		$venderHook = Plugins::addHook('packet_vender', \&Called);
		$venderStoreHook2 = Plugins::addHook('packet_vender_store2', \&mercDbFill);
		$charNameUpdateHook = Plugins::addHook('charNameUpdate', \&charNameUpdate);
	}
}

my $result 	= 0;
# the database depending variables could be added to config.txt
my $dbUser	= "dataBase_user";	# the name of the mysql user that has read/write access to database $database
my $dbPassword	= "dataBase_password";	# his password
my $database	= "dataBase_name";	# the used database
my $dbHostname	= "localhost";	# mysql server 
my $dbPort	= "3306";	# mysql server port
my $dsn		= "DBI:mysql:database=$database;host=$dbHostname;port=$dbPort"; 
my $dbh;

my $elementName;
my $starCrumb;
my $insertTemp;
my $servername;

$dbh = DBI->connect($dsn, $dbUser, $dbPassword) or die $dbh->errstr;

sub Unload {
	Plugins::delHook('start3', $startHook);
	if (defined $venderHook) {
		Plugins::delHook('packet_vender', $venderHook);
		Plugins::delHook('packet_vender_store2', $venderStoreHook2);
		Plugins::delHook('charNameUpdate', $charNameUpdateHook);
	}
	$dbh->disconnect;
}

sub Called{
	my $visitQuery;
	my $insertQuery;
	$servername = $::servers[$::config{'server'}]{'name'};
	$servername =~ s/\s+$//;
	
	# connecting to the database
#	$dbh = DBI->connect($dsn, $dbUser, $dbPassword) or die $dbh->errstr;

	# we check all available merchants
	for (my $i = 0; $i < @::venderListsID; $i++) {
		next if ($::venderListsID[$i] eq "");
		my $shopOwnerID = unpack("L1",$::venderListsID[$i]);

		# we query the database for the last time we visited the merchant $shopOwnerID
		my $lastVisitQuery = "SELECT * FROM shopvisit WHERE shopOwnerID = '$shopOwnerID' AND server='$servername'";
#		print $lastVisitQuery;
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
			$Globals::messageSender->sendEnteringVender($::venderListsID[$i]);
			
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
#	$dbh->disconnect;
	return $result;
}

### 
### mercDbFill()
###
### writes shop informations into database
###
###
	
sub mercDbFill{

	my $itemName;
	my $datum = strftime("%d.%m.%Y %T", localtime(time));
	my $map = $::field{name};
	my $card1ID = 0;
	my $card2ID = 0;
	my $card3ID = 0;
	my $card4ID = 0;
	my $avg_price = 0;
	my $std_price = 0;
	my $elementName = "";
	my $starCrumb = "";
	
	$servername = $::servers[$::config{'server'}]{'name'};
	$servername =~ s/\s+$//;

	#look for cheaper items ie: hotdeal-range * 90%
	my $myHotDeal = $Globals::config{'merchantDB_myHotDeal'}; 
	$myHotDeal = 1 	if !$myHotDeal;
	
	# connecting to the database
	$dbh = DBI->connect($dsn, $dbUser, $dbPassword) or die $dbh->errstr;
	
	my (undef, $myItemList) = @_;
	my $myItem;
	my @myItem;
	my @myItemList;
	
	my $shopOwnerID = unpack("L1",$myItemList->{venderID});
	my $playerA = Actor::get($myItemList->{venderID});
	my $shopOwner = $playerA->name;
	$shopOwner =~ s/\\/\\\\/g;
	$shopOwner =~ s/'/\\'/g;
	my $shopName = $::venderLists{$myItemList->{venderID}}{'title'};
	$shopName =~ s/\\/\\\\/g;
	$shopName =~ s/'/\\'/g;
	my $shopPosX = $::players{$myItemList->{venderID}}{'pos_to'}{'x'};
	my $shopPosY = $::players{$myItemList->{venderID}}{'pos_to'}{'y'};
#	print "Shop-Owner: $shopOwner($shopOwnerID)// Shop: $shopName @ $shopPosX, $shopPosY\n";				
#	print "Number of Items: " . $#{$myItemList->{itemList}} . "\n";
	
	for (my $idx = 0; $idx <= $#{ $myItemList->{itemList} }; $idx++){
#		print "item-name: " . $myItemList->{itemList}[$idx]{name} . "\n";
		if (!($myItemList->{itemList}[$idx]{name} eq "")) {
			#
			# check if the offered items are already in the database
			#
#			print "item-name: " . $myItemList->{itemList}[$idx]{name} . "\n";
			
			my $iid = $myItemList->{itemList}[$idx]{'nameID'};
			my $custom = $myItemList->{itemList}[$idx]{'upgrade'};
			my $broken = $myItemList->{itemList}[$idx]{'broken'};
			my $cardDB = $myItemList->{itemList}[$idx]{'cards'};
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
				$starCrumb = ($cards[1] >> 8) / 5;	
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
			$avg_std_query .= " AND broken = '$broken'";
			$avg_std_query .= " AND server = '$servername'";
			$avg_std_query .= " AND card1ID = '$card1ID'";
			$avg_std_query .= " AND card2ID = '$card2ID'";
			$avg_std_query .= " AND card3ID = '$card3ID'";
			$avg_std_query .= " AND card4ID = '$card4ID'";
			$avg_std_query .= " AND element = '$elementName'";
			$avg_std_query .= " AND star_crumb = '$starCrumb'";
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
			
			my $barrier_price = ($avg_price - $std_price) * $myHotDeal;
			if ($myItemList->{itemList}[$idx]{'price'} < $barrier_price){
				#
				# HOT DEAL !!!!!!!!!!!!
				#
				Log::message("HOT DEAL !!!!!!!!!");	
	#			print $avg_price . " - " . $std_price . " * " . $myHotDeal . " = " . $barrier_price . " // price: " . $::venderItemList[$::number]{'price'} ."\n";
	#			print $avg_std_query . "\n";
				
				my @shoppinglist = split(/,/, $Settings::config{"merchantDB_shoppinglist"});
				my $buyitem;
				my $buyresult = 0;
				my $onlist = 0;
				my $itemNameLong;
				my $buyShopNumber;
				$itemNameLong = $myItemList->{itemList}[$idx]{name};
				foreach $buyitem(@shoppinglist){
					$buyitem =~ s/^ +//;
					$buyitem =~ s/ +$//;
	#				print "bi: " . $buyitem . " / in: " . $itemNameLong . "\n";
					if (($buyitem eq "all") || ($buyitem eq $itemNameLong)){					
						# ok, its in our list ...
						$onlist = -1;
						if ($chars[$config{'char'}]{'zenny'} >= $myItemList->{itemList}[$idx]{'price'}){
							# ... and we have the money to buy it, let's go shopping
							# buy it
							::sendBuyVender(\$::remote_socket, $myItemList->{venderID}, $idx, 1);
							Log::message(" ... buy it!\n");
							$buyresult = -1;
						} else {
							Log::message(" ... but no money!\n");
							$buyresult = -1;
						}
					}
					if (!$buyresult && !$onlist){
						Log::message(" ... not on my list!\n");
						$buyresult = -1;
					}
				}	
			}
			
			# hot deal check END
			#
			
			my $selectQuery = "SELECT * FROM shopcont WHERE";
			$selectQuery .= " shopOwnerID = '$shopOwnerID'";
			$selectQuery .= " AND itemID = '$iid'";
			$selectQuery .= " AND custom = '$custom'";
			$selectQuery .= " AND broken = '$broken'";
			$selectQuery .= " AND server = '$servername'";
			$selectQuery .= " AND card1ID = '$card1ID'";
			$selectQuery .= " AND card2ID = '$card2ID'";
			$selectQuery .= " AND card3ID = '$card3ID'";
			$selectQuery .= " AND card4ID = '$card4ID'";
			$selectQuery .= " AND element = '$elementName' \n";
			$selectQuery .= " AND star_crumb = '$starCrumb' \n";
			
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
				$starCrumb = ($cards[1] >> 8) / 5;
				$suffix .= ('V'x$starCrumb)."S " if $starCrumb;
				$suffix .= $elementName;
				
				$insertTemp .= " element = '$elementName', \n";
				$insertTemp .= " star_crumb = '$starCrumb', \n";
				
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
				
				#$itemName = $::venderItemList[$::number]{'name'};
				#$itemName = main::itemNameSimple($iid);
				$itemName = $myItemList->{itemList}[$idx]{name};
				$itemName =~ s/\\/\\\\/g;
				$itemName =~ s/'/\\'/g;
				my $slots = 0;
				$slots = $itemSlotCount_lut{$iid};
				
				my $insertQuery = "INSERT INTO shopcont SET
				shopOwnerID 		= '$shopOwnerID', 
				shopOwner 			= '$shopOwner', 
				shopName 				= '$shopName', 
				itemID 					= '$iid', 
				name 						= '$itemName', 
				broken 					= '$broken', 
				amount 					= '" . $myItemList->{itemList}[$idx]{'amount'} . "', 
				typus 					= '" . $::itemTypes_lut{$myItemList->{itemList}[$idx]{'type'}} . "', 
				identified 			= '" . $myItemList->{itemList}[$idx]{'identified'} . "', 
				slots 					= '$slots', \n";
				
				$insertQuery .= $insertQuery2 . $insertTemp;
				$insertQuery .= " price = '" . $myItemList->{itemList}[$idx]{'price'} . "', 
				posx 						= '$shopPosX', 
				posy 						= '$shopPosY', 
				time 						= " . time . ", 
				datum 					= '$datum', 
				map 						= '$map', 
				server 					= '$servername'";
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
				if (@existingItem[19] != $myItemList->{itemList}[$idx]{'price'}){
					if ($updateItem) {
						$updateQuery .= ", ";
					}
					$updateItem = -1;
					$updateQuery .= "price = '" . $myItemList->{itemList}[$idx]{'price'} . "'";
				}
				
				# amount has changed
	                        if (@existingItem[6] != $myItemList->{itemList}[$idx]{'amount'}){
	                                if ($updateItem) {
	                                        $updateQuery .= ", ";
	                                }
	                                $updateItem = -1;
	                                $updateQuery .= "amount = '" . $myItemList->{itemList}[$idx]{'amount'} . "'";
	                        }
	
				# pos_x has changed
				if (@existingItem[21] != $shopPosX){
	                                if ($updateItem) {
	                                        $updateQuery .= ", ";
	                                }
	                                $updateItem = -1;
	                                $updateQuery .= "posx = '" .  $shopPosX . "'";
	                        }
	
				# pos_y has changed
				if (@existingItem[22] != $shopPosY){
	                                if ($updateItem) {
	                                        $updateQuery .= ", ";
	                                }
	                                $updateItem = -1;
	                                $updateQuery .= "posy = '" .  $shopPosY . "'";
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
		}
	} # END for	
#	$dbh->disconnect;
	return $result;
}

### 
### charNameUpdate()
###
### the name of another player has changed. the database gets updated
###
###
	
sub charNameUpdate{
	my (undef, $player) = @_;

	$servername = $::servers[$::config{'server'}]{'name'};
	$servername =~ s/\s+$//;

#	$dbh = DBI->connect($dsn, $dbUser, $dbPassword) or die $dbh->errstr;
	my $datum	= strftime("%d.%m.%Y %T", localtime(time));

	my $shopOwnerID = unpack("L1",$player->{ID});
	my $shopOwner = $player->{name};
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
#	$dbh->disconnect;
	return 1;
}


return 1;
