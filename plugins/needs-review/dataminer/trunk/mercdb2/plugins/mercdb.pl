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
my ($venderHook, $venderStoreHook2, $hkAiPost, $hkNetCon);

# seconds till next shopvisit - should not be to low if your tour has loops
my $visitTimeout = 120; 

		$venderHook = Plugins::addHook('packet_vender', \&Called);
		$venderStoreHook2 = Plugins::addHook('packet_vender_store2', \&mercDbFill);
		$hkAiPost = Plugins::addHook('AI_post', \&updateCurPos);
		$hkNetCon = Plugins::addHook('Network::connectTo', \&connect);

sub init {
	# i know, i do initialization wrong, but this doesnt work and i dont know why now!
	return;
	if ($Globals::config{'merchantDB'}) { 
		$venderHook = Plugins::addHook('packet_vender', \&Called);
		$venderStoreHook2 = Plugins::addHook('packet_vender_store2', \&mercDbFill);
		$hkAiPost = Plugins::addHook('AI_post', \&updateCurPos);
		$hkNetCon = Plugins::addHook('Network::connectTo', \&connect);
	}
}

my $result 	= 0;
# the database depending variables could be added to config.txt
my $dbUser	= "mercdb";	# the name of the mysql user that has read/write access to database $database
my $dbPassword	= "znrCCQqahCuqXYuy";	# his password
my $database	= "mercdb";	# the used database
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
		Plugins::delHook('AI_post', $hkAiPost);
		Plugins::delHook('Network::connectTo', $hkNetCon);
	}
	$dbh->disconnect;
}

# writing "Connecting" to botpos, so the "please wait while connecting" is written in the webinterface
sub connect{
	my $updBotPos = "UPDATE botpos SET bpposx=0, bpposy=0, bpmap='Connecting'";
	my $sth2 = $dbh->prepare($updBotPos);
	$sth2->execute or die $dbh->errstr . "\n" . $updBotPos;
}

# writing data to botpos, so position is traceable via webinterface - has a 1sec timeout to decrease database load
my $posTimeout=time;
sub updateCurPos{
	return if $posTimeout + 0.25 >= time;
	my $x=$char->position()->{x};
	my $y=$char->position()->{y};
	my $map=$field{name};
	my $updBotPos = "UPDATE botpos SET bpposx=$x, bpposy=$y, bpmap='$map'";
	my $sth2 = $dbh->prepare($updBotPos);
	$sth2->execute or die $dbh->errstr . "\n" . $updBotPos;
	$posTimeout=time;	
}

# this function checks, wheter to open a shop, or if its too early! this didnt change much from merchdb1
sub Called{
	my $visitQuery;
	my $insertQuery;
	$servername = $::servers[$::config{'server'}]{'name'};
	$servername =~ s/\s+$//;
	
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
			# print $selectQuery . "\n";
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

	return $result;
}

# this actually inserts the data into the db - has drastically changed from mercdb1! now, we have a copy of what items are right now on the market
# you need merchstart.sh to get all running
sub mercDbFill{
	my $itemName;
	my $datum = strftime("%Y-%m-%d %T", localtime(time));
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

	my (undef, $myItemList) = @_;
	my $myItem;
	my @myItem;
	my @myItemList;
	
	my $shopOwnerID = unpack("L1",$myItemList->{venderID});
	my $playerA = Actor::get($myItemList->{venderID});
	my $shopOwner = $playerA->name;
	$shopOwner =~ s/\\/\\\\/g;
	$shopOwner =~ s/'/\\'/g;
	my $shopName = quotemeta $::venderLists{$myItemList->{venderID}}{'title'};
#	$shopName =~ s/\\/\\\\/g;
#	$shopName =~ s/'/\\'/g;
	my $shopPosX = $::players{$myItemList->{venderID}}{'pos_to'}{'x'};
	my $shopPosY = $::players{$myItemList->{venderID}}{'pos_to'}{'y'};
	
	if ( $shopPosX == "" || $shopPosY == ""){
		return $result;
	}
	
	for (my $idx = 0; $idx <= $#{ $myItemList->{itemList} }; $idx++){
		# print "item-name: " . $myItemList->{itemList}[$idx]{name} . "\n";
		if (!($myItemList->{itemList}[$idx]{name} eq "")) {
			# print "item-name: " . $myItemList->{itemList}[$idx]{name} . "\n";
			
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

			$card1ID=0;
			$card2ID=0;
			$card3ID=0;
			$card4ID=0;
			$elementName="";
			$starCrumb="";

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
			# i deleted the old hot deal check, since it was buggy and strange
			# if you wanna have a hot deal check, code it yourself!
			# you could send an irc message, if you see something hot

			# INSERT HOT DEAL HANDLING HERE !!!
			
			my $sth;
			my $test;
			my $insertQuery2 = "";
			
			# care about cards for insert
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
			
			
			#$itemName = $::venderItemList[$::number]{'name'};
			#$itemName = main::itemNameSimple($iid);
			$itemName = $myItemList->{itemList}[$idx]{name};
			$itemName =~ s/\\/\\\\/g;
			$itemName =~ s/'/\\'/g;
			my $slots = 0;
			$slots = $itemSlotCount_lut{$iid};
			
			# decide for update or insert - have we seen this item already ?
			
			my $qrIsAlrdyIn = "SELECT id FROM shopcont" .
					" WHERE shopOwnerId = '$shopOwnerID' AND itemID = $iid AND custom = '$custom' AND shopname = '$shopName'".
					" AND server = '$servername' AND posX = $shopPosX AND posY = $shopPosY" .
					" AND card1ID = '$card1ID' AND card2ID = '$card2ID' AND card3ID = '$card3ID' AND card4ID = '$card4ID'".
					" AND element = '$elementName' AND star_crumb = '$starCrumb' AND custom = '$custom'". 
					" AND price = '" . $myItemList->{itemList}[$idx]{'price'} . "'";
			$sth = $dbh->prepare($qrIsAlrdyIn);
			$sth->execute or die "\n" . $qrIsAlrdyIn . "\n" . $dbh->errstr;
			my $rvin = $sth->rows;
			
			if(!($rvin==0 || $rvin==1) ){
				print "Error! $rvin rows found in update-check\nQuery:\n$qrIsAlrdyIn\n";
			}

			if($rvin == 1){
				my $qrIsInUpd = "UPDATE shopcont" .
					" SET isstillin = 'Yes', timstamp = '$datum', amount = " . $myItemList->{itemList}[$idx]{'amount'} .
					" WHERE shopOwnerId = '$shopOwnerID' AND itemID = $iid AND custom = '$custom' AND shopname = '$shopName'".
					" AND server = '$servername' AND posX = $shopPosX AND posY = $shopPosY" .
					" AND card1ID = '$card1ID' AND card2ID = '$card2ID' AND card3ID = '$card3ID' AND card4ID = '$card4ID'".
					" AND element = '$elementName' AND star_crumb = '$starCrumb' AND custom = '$custom'". 
					" AND price = '" . $myItemList->{itemList}[$idx]{'price'} . "'";

				my $sth = $dbh->prepare($qrIsInUpd);
				$sth->execute or die "\n" . $qrIsInUpd . "\n" . $dbh->errstr;
			}
			if($rvin == 0){
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
				timstamp 					= '$datum', 
				isstillin					= 'Yes',
				map 						= '$map', 
				server 					= '$servername'";
				$insertQuery .= ";";
				# print $insertQuery . "\n";
	
				my $sth = $dbh->prepare($insertQuery);
				$sth->execute or die $dbh->errstr;
			}
		 }		
	} # END for	
	return $result;
}

# this functin calls a unix fork to execute sql statements in the background - not propperly tested yet!
sub mercDbFillFork{
	my $self;

	require POSIX;
	import POSIX;
	require Fcntl;
	my ($pid, $pipe, $r, $w);

	# Setup a pipe. This is so we can check whether the
	# child process's exec() failed.
	local($|);
	$| = 0;
	if (pipe($r, $w) == -1) {
		$self->{error} = $!;
		$self->{errno} = int($!);
		$self->{launched} = 0;
		return 0;
	}

	# Fork and execute the child process.
	$pid = fork();

	if ($pid == -1) {
		# Fork failed
		$self->{launched} = 0;
		$self->{error} = $!;
		$self->{errno} = int($!);
		close($r);
		close($w);
		return 0;

	} elsif ($pid == 0) {
		# Child process
		my ($error, $errno);

		close $r;
		$^F = 2;

		# This prevents some lockups.
		# open(STDOUT, "> /dev/null");
		# open(STDERR, "> /dev/null");
		POSIX::setsid();

#		exec(@{$self->{args}});
		mercDbFill2();
		# Exec failed
		$error = $!;
		$errno = int($!);
		syswrite($w, "$error\n$errno\n");

		POSIX::_exit(1);

	} else {
		# Parent process
		my ($error, $errno);

		close $w;
		$error = <$r>;
		$error =~ s/[\r\n]//g;
		$errno = <$r> if ($error ne '');
		$errno =~ s/[\r\n]//g;

		if ($error eq '') {
			# Success
			$self->{pid} = $pid;
			$self->{launched} = 1;
			return 1;
		} else {
			# Failed
			$self->{launched} = 0;
			$self->{error} = $error;
			$self->{errno} = $errno;
			return 0;
		}
	}

}

return 1;
