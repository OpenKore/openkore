######################################################
# This plugin is licensed under the GNU GPL          #
# Copyright 2005 by isieo                            #
# contact : - isieo <AT> *NOSPAM* G*MAIL <DOT> COM   #
# -------------------------------------------------- #
# -------------------------------------------------- #
# playerrecorder.pl                                  #
# Records Player's name together with AIDs           #
# Usefull for players to findout other players' other#
# characters...                                      #
#                                                    #
######################################################

package playerRecord;
use strict;
use Plugins;
use Log qw(message);
use Globals;
use Settings;
use DBI;

# hook to AI_post and do domething like this:
# foreach $player (@players) { foreach $key (%{$player}) { print "$key => $player{$key}" } }
#Mr_Incredible so, on AI_post with an timeout, i call sendGetPlayerInfo with shifting through the @players array ... whats in @players ? packed ids ?
#Mr_Incredible Crypticode, thats difficult, since many waypoints have a long distance between each other - thas why i meant to stop on every new screen (= every X steps) and make a pause there
#kalischool foreach $player (@players) { foreach $key (%{$player}) { print "$key => $player{$key}" } }
#kalischool or something like that (i'm not sure)
#kalischool you don't need to pause
#Mr_Incredible ic - i will try that!
#kalischool just go around, collecting player ids
#kalischool you push the player ids into an array
#Crypticode oh nice, i just saw : $player->{gotName} = 1;
#kalischool then later, you shift the @encounteredplayers array
#kalischool @players is an array of hashes
#kalischool it contains all the players currently on screen
#Crypticode odd, i always thought kore automatically sends getPlayerName whenever a unknown player occours on screen
#kalischool it does

#kalischool i'll repeat:
#kalischool hook into actor_exists
#kalischool push all encountered player ids into @encounteredplayers
#kalischool hook into ai_post
#kalischool if (timeout(x,y)) sendgetplayerinfo(shift @encounteredplayers));
#kalischool something like that
#kalischool @encounteredplayers would contain *all* of the player ids you have encountered
#Crypticode so probably it would be enough if he lowers the kore's timeout about getplayerinfo ?
#Mr_Incredible i missed the actor_exists part. but now i know how to try to code it. actor_exists is called everytime a new player apears ?
#kalischool since the server already sends that
#kalischool yes
#kalischool because the server sends it
#kalischool and openkore calls the hook (because of the packet parser)

# set timeout in secons how often to do the whole check on a char ... values < 10minutes (600)  might increase database load
my $checkTimeout=60*10;
# maptimeout - only insert vars, if seen on this map! only insert seen if seen is older than 3 hours on THIS map!
my $mapTimeout=60*60*3;

Plugins::register("prec", "playerRecordSQL", \&on_unload, \&on_reload);
my $hooks = Plugins::addHooks(
        ['charNameUpdate', \&write_player],
);
my $datadir = $Plugins::current_plugin_folder;

my $result 	= 0;
# the database depending variables could be added to config.txt
my $dbUser	= "chardb";	# the name of the mysql user that has read/write access to database $database
my $dbPassword	= "setthis";	# his password
my $database	= "chardb";	# the used database
my $dbHostname	= "leetbox.de";	# mysql server 

my $dbPort	= "3306";	# mysql server port
my $dsn		= "DBI:mysql:database=$database;host=$dbHostname;port=$dbPort"; 
my $dbh;

$dbh = DBI->connect($dsn, $dbUser, $dbPassword) or die $dbh->errstr;

sub on_unload {
        # This plugin is about to be unloaded; remove hooks
        Plugins::delHook("charNameUpdate", $hooks);
}

sub on_reload {
}

sub write_player {
        my $hookname = shift;
        my $args = shift;
		my $myId = unpack("V1",$char->{ID});
        my $targetId = unpack("V1",$args->{ID});
        my $targetName = quotemeta $args->{name};
		my $targetParty = quotemeta $args->{party}{name};
		my $targetGuild = quotemeta $args->{guild}{name};
		my $targetGuildPos = quotemeta $args->{guild}{title};
		my $targetPosX = $args->position()->{x};
		my $targetPosY = $args->position()->{y};
		my $targetMap = $field{name};
		my $targetLevel = $args->{lv};
		my $targetSex =$sex_lut{$args->{sex}};
		my $targetClass =$jobs_lut{$args->{jobID}};
		
		my $acacid = checkAccount ($targetId);
		return if(isTooEarly($acacid, $targetName, $targetMap));

		print "[PlayerRecordSQL] " . $targetId . " - |" . $targetClass . "| " . $targetName . " (" . $targetParty . 
			") [" . $targetGuild . " | " . $targetGuildPos . "] " . $targetPosX . "/" . $targetPosY . " - " . $targetMap . "\n";

#		print "PLAYERRECORDSQL: " . $targetId . " Level: " . $targetLevel . "Name: " . $targetName . " PartyName: " . $targetParty . 
#			" Guild: " . $targetGuild . " Position: " . $targetGuildPos . " Pos: " . $targetPosX . "/" . $targetPosY . " Map: " . $targetMap . 
#			" Sex: " . $targetSex . " Class: " .$targetClass . " MyID: " . $myId . "\n";
		
		my $chchid = checkChar ($acacid, $targetName, $targetLevel, $targetSex, $targetClass);
		my $papaid = checkParty ($chchid, $targetParty);
		my $gigiid = checkGuild ($chchid, $targetGuild);
		checkGuildPos($chchid, $gigiid, $targetGuildPos);
		insSeen($chchid, $gigiid, $papaid, $targetLevel, $targetMap, $targetPosX, $targetPosY, $myId);
}

sub isTooEarly{
	my($acacid, $targetName, $targetMap)=@_;
	
	my $qrSelect="select chchid from chars where chacid = $acacid and chname = '$targetName' and unix_timestamp(now()) < unix_timestamp(chtimestamp)+$checkTimeout";
	my $sth = $dbh->prepare($qrSelect);
	$sth->execute or die "\n" . $qrSelect . "\n" . $dbh->errstr . "\n";
	my $rv = $sth->rows;
	return 1 if($rv);

	my $qrChid="select chchid from chars where chacid = $acacid and chname = '$targetName'";
	$sth = $dbh->prepare($qrChid);
	$sth->execute or die "\n" . $qrChid . "\n" . $dbh->errstr . "\n";
	$rv = $sth->rows;
	
	return 0 if(!$rv);
	
	my @row = $sth->fetchrow_array;
	my $chchid=@row[0];
	
	return 0 if($chchid=="");
	
	my $qrLastMap="select seseid from seen where sechid = $chchid and semap = '$targetMap' and unix_timestamp(now()) < unix_timestamp(setimestamp)+$mapTimeout";
	$sth = $dbh->prepare($qrLastMap);
	$sth->execute or die "\n" . $qrLastMap . "\n" . $dbh->errstr . "\n";
	$rv = $sth->rows;
	
	return 1 if($rv);
	return 0;
}

sub checkAccount {
	my $targetId=shift;
	my $ret="-1";
	my @row;
	return $ret unless $targetId;

	my $qrSelect="select acacid from account where acroacid = $targetId";
	my $sth = $dbh->prepare($qrSelect);
	$sth->execute or die "\n" . $qrSelect . "\n" . $dbh->errstr . "\n";
	my $rv = $sth->rows;
	
	if ($rv){
		@row = $sth->fetchrow_array; 
		$ret=@row[0];
	}else{
		my $qrInsert="insert into account(acroacid) values ($targetId)";
		my $sth = $dbh->prepare($qrInsert);
		$sth->execute or die "\n" . $qrInsert . "\n" . $dbh->errstr . "\n";	

		$qrSelect="select acacid from account where acroacid = $targetId";
		$sth = $dbh->prepare($qrSelect);
		$sth->execute or die "\n" . $qrSelect . "\n" . $dbh->errstr . "\n";
		@row = $sth->fetchrow_array;
		$ret=@row[0];
	}
	
	return $ret;
}

sub checkChar {
	my ($acacid, $targetName, $targetLevel, $targetSex, $targetClass)=@_;
	my $ret="-1";
	my @row;
	return $ret unless $acacid;
	return $ret if $acacid=="-1";
	return $ret unless $targetName;
	return $ret unless $targetLevel;
	return $ret unless $targetSex;
	return $ret unless $targetClass;

	my $qrSelect="select chchid from chars where chname='$targetName' and chacid = $acacid";
	my $sth = $dbh->prepare($qrSelect);
	$sth->execute or die "\n" . $qrSelect . "\n" . $dbh->errstr . "\n";
	my $rv = $sth->rows;
	
	if ($rv){
		@row = $sth->fetchrow_array; 
		$ret=@row[0];
		my $qrUpdTimestamp="update chars set chtimestamp=NULL where chchid = $ret";
		$sth=$dbh->prepare($qrUpdTimestamp);
		$sth->execute or die "\n" . $qrUpdTimestamp . "\n" . $dbh->errstr . "\n";
	}else{
		my $qrInsert="insert into chars(chacid, chname, chlevel, chsex, chclass) values ($acacid, '$targetName', '$targetLevel', '$targetSex', '$targetClass')";
		my $sth = $dbh->prepare($qrInsert);
		$sth->execute or die "\n" . $qrInsert . "\n" . $dbh->errstr . "\n";	

		$sth = $dbh->prepare($qrSelect);
		$sth->execute or die "\n" . $qrSelect . "\n" . $dbh->errstr . "\n";
		@row = $sth->fetchrow_array;
		$ret=@row[0];
	}
	
	return $ret;
}
sub checkParty {
	my($chchid, $targetParty)=@_;
	my $ret="-1";
	my @row;
	return "" unless $targetParty;
	return $ret unless $chchid;
	return $ret if $chchid=="-1";

	my $qrSelect="select papaid from party where paname = '$targetParty' and pachid='$chchid'";
	my $sth = $dbh->prepare($qrSelect);
	$sth->execute or die "\n" . $qrSelect . "\n" . $dbh->errstr . "\n";
	my $rv = $sth->rows;
	
	if ($rv){
		@row = $sth->fetchrow_array;
		$ret=@row[0];
	}else{
		my $qrInsert="insert into party(pachid, paname) values ($chchid, '$targetParty')";
		my $sth = $dbh->prepare($qrInsert);
		$sth->execute or die "\n" . $qrInsert . "\n" . $dbh->errstr . "\n";	

		$sth = $dbh->prepare($qrSelect);
		$sth->execute or die "\n" . $qrSelect . "\n" . $dbh->errstr . "\n";
		@row = $sth->fetchrow_array;
		$ret=@row[0];
	}
	
	return $ret;
}

sub checkGuild {
	my ($chchid, $targetGuild)=@_;
	my $ret="-1";
	my @row;
	return "" unless $targetGuild;
	return $ret unless $chchid;
	return $ret if $chchid=="-1";

	my $qrSelect="select gigiid from guild where giname = '$targetGuild'";
	my $sth = $dbh->prepare($qrSelect);
	$sth->execute or die "\n" . $qrSelect . "\n" . $dbh->errstr . "\n";
	my $rv = $sth->rows;
	
	if ($rv){
		@row = $sth->fetchrow_array; 
		$ret=@row[0];
	}else{
		my $qrInsert="insert into guild(giname) values ('$targetGuild')";
		my $sth = $dbh->prepare($qrInsert);
		$sth->execute or die "\n" . $qrInsert . "\n" . $dbh->errstr . "\n";	

		$sth = $dbh->prepare($qrSelect);
		$sth->execute or die "\n" . $qrSelect . "\n" . $dbh->errstr . "\n";
		@row = $sth->fetchrow_array;
		$ret=@row[0];
	}
	
	my $qrSelect="select c2gchid from char2guild where c2gchid = $chchid and c2ggiid = $ret";
	my $sth = $dbh->prepare($qrSelect);
	$sth->execute or die "\n" . $qrSelect . "\n" . $dbh->errstr . "\n";
	my $rv = $sth->rows;
	
	if ($rv){
	}else{
		my $qrInsert="insert into char2guild(c2gchid, c2ggiid) values ($chchid, $ret)";
		my $sth = $dbh->prepare($qrInsert);
		$sth->execute or die "\n" . $qrInsert . "\n" . $dbh->errstr . "\n";	

		$sth = $dbh->prepare($qrSelect);
		$sth->execute or die "\n" . $qrSelect . "\n" . $dbh->errstr . "\n";
	}

	return $ret;
}

sub checkGuildPos{
	my($chchid, $gigiid, $targetGuildPos)=@_;
	my $ret="-1";
	my @row;
	return unless $chchid;
	return if $chchid=="-1";
	return unless $gigiid;
	return if $gigiid=="-1";

	my $qrSelect="select gpgpid from guildpos where gpposition = '$targetGuildPos' and gpchid=$chchid and gpgiid=$gigiid";
	my $sth = $dbh->prepare($qrSelect);
	$sth->execute or die "\n" . $qrSelect . "\n" . $dbh->errstr . "\n";
	my $rv = $sth->rows;
	
	if ($rv){
	}else{
		my $qrInsert="insert into guildpos(gpposition, gpchid, gpgiid) values ('$targetGuildPos', $chchid, $gigiid)";
		my $sth = $dbh->prepare($qrInsert);
		$sth->execute or die "\n" . $qrInsert . "\n" . $dbh->errstr . "\n";	
	}
}

sub insSeen{
	my($chchid, $gigiid, $papaid, $targetLevel, $targetMap, $targetPosX, $targetPosY, $myId)=@_;
	return unless $chchid;
	return if $chchid=="-1";
	return if $gigiid=="-1";
	$gigiid="-1" if($gigiid=="");
	return if $papaid=="-1";
	$papaid="-1" if($papaid=="");
	
	my $qrInsert="insert into seen(sechid, segiid, sepaid, semap, seposx, seposy, selevel, seseenbyacid) " .
		"values ($chchid, $gigiid, $papaid, '$targetMap', $targetPosX, $targetPosY, $targetLevel, $myId)";

	my $sth = $dbh->prepare($qrInsert);
	$sth->execute or die "\n" . $qrInsert . "\n" . $dbh->errstr . "\n";
	my $rv = $sth->rows;	
}
		
1;