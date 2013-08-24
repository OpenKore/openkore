###########################
# Name of Plugin: ASCIInumberKiller.pl
# Version: 2.2.1 (fix) (7/06/2008)
# Version of Openkore Required: OpenKore SVN (test in SVN)
# if OpenKore SVN comment line "use Commands qw(run register unregister);" (~ line 98)
# 
# Description: for response BotKiller #1 - Method 4: ASCII number. (http://www.eathena.ws/board/index.php?showtopic=120522)
#
# ***************************************************************
# *	For read my note : Editplus > tools > preferences.. fonts "Tahoma" size 9	*
# ***************************************************************
# *		 NOTE 01 : This plugin meant to be use with hakore's reactOnNPC			*
# ***************************************************************
#
# Ex. ../control/config.txt
# reactOnNPC ASCIInumberKiller num {
#	  type number
# }
# reactOnNPC ASCIInumberKiller text {
#	  type text
# }
# ASCIInumberKiller {
#	  lengthCharNumber 8
#	  BgColor ^[D-Fd-f][A-Fa-f0-9][D-Fd-f][A-Fa-f0-9]{3}
#}
#
# ************** or [for advance] **********
#
# reactOnNPC ASCIInumberKiller num {
#	  type number
#	  msg_0 /BotKiller blabla/
#	  msg_1 /blabla/
#	  .
#	  .
#	  msg_n /blabla/
# }
# reactOnNPC ASCIInumberKiller text {
#	  type text
#	  msg_0 /BotKiller blabla/
#	  msg_1 /blabla/
#	  .
#	  .
#	  msg_n /blabla/
# }
# ASCIInumberKiller {
#	  lengthCharNumber 8
#	  BgColor ^[D-Fd-f][A-Fa-f0-9][D-Fd-f][A-Fa-f0-9]{3}|FFFFFF|FFFFFA|code hexcolor you server|.. |brabra
#}
#
# ***************************************************************
# *		 NOTE 02 : This plugin meant to be modify to your server by youselft			*
# ***************************************************************
#
# A. How to get number and lenght of number
# - set ../control/config.txt : debug 2, logConsole 1
# - use plugins reactOnNPC.pl ,responseOnASCIInumber.pl
# - look at you ../logs/console.txt
# or
# use plugins LogNpcMsg.pl (find in my (windows98SE) site --> http://www.stephack.com/) [easy log npc msg for me ;P]
#
# B. How to Change lenght of number (defult = 8) [ex. Creamsoda-RO = 25, Rookie-RO = 8]
# Use this block:
# ASCIInumber {
#  lengthCharNumber 8		# length of characters at each line of each number
#  BgColor	FFFFFF|FFFFFA		# regexp color(HEXcode) Background you npc msg *Find it by youself
# }
#
# C. How to add another number [ suport A-Z, if you can :) ]
# - look at line(160) my %digit =  ('##########====####====####====##########' => 0,
#
# ex. number 0				= 	  ##########====####====####====##########
# 1 number = 8 character=	######## ##====## ##====## ##====## ########
#									=			1					2				  3					 4					5
#												V					|				  |					  |					|
#  1 ########	<- -	-	########		    V				  |					  |					|
#  2 ##====##	<- -	-	-	-	-	-	-  ##====##		  V				  |					|
#  3 ##====##	<- -	-	-	-	-	-	-	-	-	-	-	-	##====##		  V				|
#  4 ##====##	<- -	-	-	-	-	-	-	-	-	-	-	-	-	-	-	-	##====##			V
#  5 ########	<-	-	-	-	-	-	-	-	-	-	-	-	-	-	-	-	-	-	-	-	-	-	########
#
#	***************************************************************
#	:::: Thank For ::::: 
#	LogConsole : krrado,Shyshio,zeruelx [Forums, PM]
# Tester : Shyshio [VanRO]
# Codeing&document : Mucilon [forums opk inter]
#

package ASCIInumberKiller;

use strict;
use Plugins;
use Utils;
use Globals;
use Misc;
#use Commands qw(run register unregister); #svn comment this line
use Log qw(message debug);
use I18N qw(bytesToString);

my $prefix = "ASCIInumberKiller";
my $line_msg;
my $startLine;	
my $line_msgNum;
my $lengthCharNumber;
my @num_0;
my @num_1;
my @num_2;
my @num_3;
my %reactOnNPC;

Plugins::register('ASCIInumberKiller', 'response On ASCII number', \&onUnload);
my $cmd = Commands::register(['ASCIInumberKiller', 'talk response On ASCII number', \&onASCIICmd]);
my $hooks = Plugins::addHooks(
  ['packet/npc_talk', \&onNPCTalk],
  ['packet/npc_talk_close', \&onUndef]
);

sub onUnload {
  Plugins::delHooks($hooks);
  Commands::unregister($cmd);
  undef %reactOnNPC;
  undef @num_0;
  undef @num_1;
  undef @num_2;
  undef @num_3;
}

sub onUndef {
  undef %reactOnNPC;
}

sub onNPCTalk {
  my (undef, $args) = @_;
  my $msg = I18N::bytesToString(unpack("Z*", substr($args->{RAW_MSG}, 8)));
  my @npcMsg = '';
  @npcMsg = split(/\^/,$msg);
  $msg ='';
  my $code;
  if (!exists $config{$prefix."_0_BgColor"}) {
	$code = '^[D-Fd-f][A-Fa-f0-9][D-Fd-f][A-Fa-f0-9]{3}';
	message "[ASCIInumber v2.2.1(fix)] There is no BgColor option at your config.txt file, assuming BgColor to '$code'.\n", "success";	
  }else{
	$code = $config{$prefix."_0_BgColor"};
	#message "[ASCIInumber v2.2.1(fix)] There is no BgColor option at your config.txt file, assuming BgColor to '$code'.\n", "success";	
  }
  foreach my $line (@npcMsg) {
	# Convert ASCII Background to =
	if($line =~ s/$code//){
	  $line =~ s/./=/g;
	} else {
	  # Convert ASCII Number to #
	  $line =~ s/^[A-Fa-f0-9]{6}//;
	  $line =~ s/./#/g;
	}
	$msg .= $line;
  }  
  debug "[Convert NPC message] to : $msg\n", "success";
  if(!defined %reactOnNPC || $reactOnNPC{action}) {
	undef %reactOnNPC if defined %reactOnNPC;
	$reactOnNPC{index} = 1;
	$reactOnNPC{msg}[$reactOnNPC{index}] = $msg;
  } else {
	$reactOnNPC{index}++;
	$reactOnNPC{msg}[$reactOnNPC{index}] = $msg;
  }
}

sub onCheckASCII {
  my (undef, $args) = @_;
  # For Disply ASCII number [set "debug 2" to see detail]
  @num_0 ='';
  @num_1 ='';
  @num_2 ='';
  @num_3 ='';
  $line_msg =0;
  $line_msgNum =0;
  my $i =0;
  my $j =0;
  if (!exists $config{$prefix."_0_lengthCharNumber"}) {
	message "[ASCIInumber v2.2.1(fix)] There is no lengthCharNumber option at your config.txt file, assuming lengthCharNumber 8.\n", "success";
	$lengthCharNumber = 8;
  } else {
	$lengthCharNumber = $config{$prefix."_0_lengthCharNumber"};
  }
  for ($i=1;$i < $reactOnNPC{index}+1 ;$i++) {
	message "[$i] : $reactOnNPC{msg}[$i]\n", "success";
	$line_msg += 1;
  }
  
  #get num & position
  for ($i = 0;$i <= length($reactOnNPC{msg}[$line_msg-1]);$i++) {
	for ($j=0;$j <= length($reactOnNPC{msg}[$line_msg-1]) - $lengthCharNumber;$j++) {
	  $num_0[$i]  = substr($reactOnNPC{msg}[$line_msg-4], $i, $lengthCharNumber);
	  $num_0[$i] .= substr($reactOnNPC{msg}[$line_msg-3], $i, $lengthCharNumber);
	  $num_0[$i] .= substr($reactOnNPC{msg}[$line_msg-2], $i, $lengthCharNumber);
	  $num_0[$i] .= substr($reactOnNPC{msg}[$line_msg-1], $i, $lengthCharNumber);
	  $num_0[$i] .= substr($reactOnNPC{msg}[$line_msg], $i, $lengthCharNumber);
	  
	  $num_1[$i]  = substr($reactOnNPC{msg}[$line_msg-5], $i, $lengthCharNumber);
	  $num_1[$i] .= substr($reactOnNPC{msg}[$line_msg-4], $i, $lengthCharNumber);
	  $num_1[$i] .= substr($reactOnNPC{msg}[$line_msg-3], $i, $lengthCharNumber);
	  $num_1[$i] .= substr($reactOnNPC{msg}[$line_msg-2], $i, $lengthCharNumber);
	  $num_1[$i] .= substr($reactOnNPC{msg}[$line_msg-1], $i, $lengthCharNumber);

	  $num_2[$i]  = substr($reactOnNPC{msg}[$line_msg-6], $i, $lengthCharNumber);
	  $num_2[$i] .= substr($reactOnNPC{msg}[$line_msg-5], $i, $lengthCharNumber);				
	  $num_2[$i] .= substr($reactOnNPC{msg}[$line_msg-4], $i, $lengthCharNumber);
	  $num_2[$i] .= substr($reactOnNPC{msg}[$line_msg-3], $i, $lengthCharNumber);
	  $num_2[$i] .= substr($reactOnNPC{msg}[$line_msg-2], $i, $lengthCharNumber);

	  $num_3[$i]  = substr($reactOnNPC{msg}[$line_msg-7], $i, $lengthCharNumber);
	  $num_3[$i] .= substr($reactOnNPC{msg}[$line_msg-6], $i, $lengthCharNumber);
	  $num_3[$i] .= substr($reactOnNPC{msg}[$line_msg-5], $i, $lengthCharNumber);
	  $num_3[$i] .= substr($reactOnNPC{msg}[$line_msg-4], $i, $lengthCharNumber);
	  $num_3[$i] .= substr($reactOnNPC{msg}[$line_msg-3], $i, $lengthCharNumber);
	}
	$line_msgNum += 1;
  }
  undef %reactOnNPC if defined %reactOnNPC;
}

sub onASCIICmd {
  my (undef, $args) = @_;
  &onCheckASCII;
  my %digit =  (
	'######===##===##===######' => 0,
	'==####==##==######====######==##==####==' => 0,
	'==####==##====####====####====##==####==' => 0,
	'##########====####====####====##########' => 0,
	'==#===##====#====#==#####' => 1,
	'==#====#====#====#====#==' => 1,
	'==##====#====#====#====#=' => 1,
	'==####======##======##======##==########' => 1,
	'==####==##==##======##======##==########' => 1,
	'#####====#######====#####' => 2,
	'==####==##====##====##====##====########' => 2,
	'######========##==########======########' => 2,
	'########======############======########' => 2,
	'#####====######====######' => 3,
	'########======##########======##########' => 3,
	'######========##==####========########==' => 3,
	'#===##===######====#====#' => 4,
	'===#===##==#=#=#####===#=' => 4,
	'====####==##==####====##########======##' => 4,
	'======##====####==##==##########======##' => 4,
	'##====####====##########======##======##' => 4,
	'######====#####====######' => 5,
	'##########======########======##########' => 5,
	'==########======######========########==' => 5,
	'##########========######======##########' => 5,
	'#====#====######===######' => 6,
	'######====######===######' => 6,
	'====##====##====##########====##==####==' => 6,
	'##########======##########====##########' => 6,
	'==####==##======##########====##==####==' => 6,
	'#####====#====#====#====#' => 7,		
	'#####===#===#===#====#===' => 7,
	'##########====##==######====##==####====' => 7,
	'########======##====##====##====##======' => 7,
	'########======##==######====##====##====' => 7,
	'########======##======##======##======##' => 7,
	'######===#######===######' => 8,
	'##########====##==####==##====##########' => 8,
	'##########====############====##########' => 8,
	'==####==##====##==####==##====##==####==' => 8,
	'######===######====######' => 9,
	'##########====##########======##########' => 9,
	'==####==##====##==######====##====##====' => 9,
	'##############################===============##########===============##########===============##############################' => '0',
	'==========##########====================#####====================#####====================#####====================#####=====' => '1',
	'==========##########==========#####==========#####===============#####===============#####===============####################' => '2',
	'####################=========================#####=====###############=========================#########################=====' => '3',
	'===============#####===============##########==========#####=====#####=====#########################===============#####=====' => '4',
	'##############################====================####################=========================#########################=====' => '5',
	'##############################====================##############################===============##############################' => '6',
	'=====###############=====#####====================####################=====#####===============#####=====###############=====' => '6',
	'#########################===============#####===============#####===============#####====================#####===============' => '7',
	'##############################===============###################################===============##############################' => '8',
	'=====###############=====#####===============#####=====###############=====#####===============#####=====###############=====' => '8',
	'##############################===============##############################====================##############################' => '9',
	'=====###############=====#####===============#####=====####################=====####################=====###############=====' => '9',
	'==========#####===============#####=====#####=====#####===============###################################===============#####' => 'A',
	'=====###############=====#####====================#####====================#####=========================###############=====' => 'C',
	'##############################====================####################=====#####====================#########################' => 'E',
	'##############################====================####################=====#####====================#####====================' => 'F',
	'#####===============##########===============###################################===============##########===============#####' => 'H',
	'===============#####====================#####====================#####=====#####==========#####==========##########==========' => 'J',
	'=====#####==========#####=====#####=====#####==========##########===============#####=====#####==========#####==========#####' => 'K',
	'#####====================#####====================#####====================#####====================#########################' => 'L',
	'#####===============###############=====###############=====#####=====##########===============##########===============#####' => 'M',
	'#####===============###############==========##########=====#####=====##########==========###############===============#####' => 'N',
	'###############==========#####==========#####=====###############==========#####====================#####====================' => 'P',
	'###############==========#####==========#####=====###############==========#####==========#####=====#####===============#####' => 'R',
	'#########################==========#####====================#####====================#####====================#####==========' => 'T',
	'#####===============##########===============##########===============##########===============#####=====###############=====' => 'U',
	'#####===============##########===============##########===============#####=====#####=====#####===============#####==========' => 'V',
	'#####===============##########===============##########=====#####=====###############=====###############===============#####' => 'W',
	'#####===============#####=====#####=====#####===============#####===============#####=====#####=====#####===============#####' => 'X',
	'#####===============#####=====#####=====#####===============#####====================#####====================#####==========' => 'Y',
	'#########################===============#####===============#####===============#####===============#########################' => 'Z'
  );

  my @result_ = '';
  my $k =0;
  my $ans = '';
	
  foreach (keys %digit) {
	for ($k =0;$k <= $line_msgNum;$k++) {
	  if ($_ eq $num_0[$k] ) {
		$result_[$k] = $digit{$_};
	  }
	  if ($_ eq $num_1[$k] ) {
		$result_[$k] = $digit{$_};
	  }
	  if ($_ eq $num_2[$k] ) {
		$result_[$k] = $digit{$_};
	  }
	  if ($_ eq $num_3[$k] ) {
		$result_[$k] = $digit{$_};
	  }
	}
  }
  for ($k=0;$k <=@result_ ;$k++) {
	$ans .= $result_[$k]
  }
  $cmd = "talk $args ".$ans;
  message "[ASCIInumber v2.2.1(fix)] Executing command \"$cmd\".\n", "success";
  #add Delay 1-3 sec before $cmd 
  message "[ASCIInumber v2.2.1(fix)] *** Delay 1-3 sec. before $cmd ***.\n", "success";
  my $startTime = time;
  while (1) {
	last if (timeOut($startTime,3));
  }
  Commands::run($cmd);			
  undef @result_;
  undef @num_0;
  undef @num_1;
  undef @num_2;
  undef @num_3;
}
return 1;