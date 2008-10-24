###########################
# React on Mini Map Indicator plugin by Mucilon
# BotKiller #1 - Method 3: MiniMap number
# Based on reactOnNPC by hakore and reactOnASCIInumber by windows98SE@thaikore 
# Version 0.2
# 24.09.2008
# Thanks for testers: frodosza, Janovas
###########################

package reactOnMiniMap;

use strict;
use Plugins;
use Utils;
use Globals;
use Misc;
use Log qw(message warning error);

Plugins::register('reactOnMiniMap', 'React on Mini Map Indicator plugin', \&onUnload);

my $hooks = Plugins::addHooks(	['packet/minimap_indicator', \&onMiniMap, undef],
				['packet/npc_talk_number', \&onNumber, undef],
				['packet/npc_talk_text', \&onText, undef],
				['packet/npc_talk_continue', \&onContinue, undef],
				['packet/npc_talk_close', \&onContinue, undef]);
				
				
my $run;
my @posx;
my @posy;
my %realpos;
my $num = 0;
my $point = 0;
my $prefix = "reactOnMiniMap v0.3";
my $answerType = '';

sub onUnload {
    Plugins::delHooks($hooks);
	undef @posx;
	undef @posy;
	undef %realpos;
};

sub onMiniMap {
    my ($self, $args) = @_;
	if ($args->{type} == 1) {
		#store all the points received at the minimap
		$realpos{$point}{x} = $args->{x};
		$realpos{$point}{y} = $args->{y};
		$realpos{$point}{red} = $args->{red};
		$realpos{$point}{green} = $args->{green};
		$realpos{$point}{type} = $args->{type};
#	message "[$prefix] Position[$point]: x = $realpos{$point}{x} ; y = $realpos{$point}{y}; red:$realpos{$point}{red}; green:$realpos{$point}{green}; type:$realpos{$point}{type}.\n", "success";
		
		$point++;
		$run = 1;
	}
}

sub onContinue {
    my (undef, $args) = @_;
	$num = 0;
	@posx = ();
	@posy = ();
	%realpos = ();
	message "[$prefix] Reseting variables.\n", "success";
}

sub onNumber {
    my (undef, $args) = @_;
	#Answer as a number if the server asks a number
	#if the plugin receive points at the minimap
	if ($run == 1) {
		$answerType = 'num';
		message "[$prefix] Answer type: $answerType.\n", "success";
		&onAction;
	}
}

sub onText {
    my (undef, $args) = @_;
	#Answer as a text if the server asks a text
	#if the plugin receive points at the minimap
	if ($run == 1) {
		$answerType = 'text';
		message "[$prefix] Answer type: $answerType.\n", "success";
		&onAction;
	}
}


sub onAction {
    my (undef, $args) = @_;
	my %Timecount;
	my $maxHeigth = 20;
	my $x = 0;
	my $y = 0;
	my $pointRead = 0;
	my @msgline = ();
	my $lengthCharNumber = 11;
	my $heigthCharNumber = 14;
	my $line_msgNum = 0;
	my $p = 0;
	my $i = 0;
	my $j = 0;
	my @num_0 = ();
	my $auxX;
	my $auxY;
	my $index;
	my $register;
	my $text;
	
	#Register all the correct points
	for ($p = 0;$p <= $point;$p++) {
		#if the condition is true, register the point as part of the number
		if ((($realpos{$p}{green} == 255) || ($realpos{$p}{green} == 15)) && ($realpos{$p}{type} == 1)) {
			$auxX = 0;
			$auxY = 0;
			$x = $realpos{$p}{x}/10;
			$y = $realpos{$p}{y}/10;
			#way to round up the number, the ceil function didn't work
			if (($x - int($x)) > 0) { $auxX = 1 }
			if (($y - int($y)) > 0) { $auxY = 1 }
			
			$register = 1;
			$text = '';
			#every point to be registrered will be checked if there is any point at the same place
			if ($num >= 1) {
				for ($index = 0; $index < @posx; $index++) {
					$text .= ' '.$index;
					if (($posx[$index] == (int($x) + $auxX)) && ($posy[$index] == (int($y) + $auxY))) {
						$register = 0;
						$text .= '0';
						last;
					}
				}
			}
#			message "[$prefix] [$num]:$text.\n", "success";
			
			#if there are no other point at the same place, register it
			if ($register) {
				$posx[$num] = int($x) + $auxX;
				$posy[$num] = int($y) + $auxY;
				message "[$prefix] Registering position: x = $posx[$num] ; y = $posy[$num].\n", "success";
				$num++;
			}
		}
	}
	message "[$prefix] Total points: $point, Registered positions: $num.\n", "success";
	#Unregister all the registered point at the same place of blank points
	for ($p = 0;$p <= $point;$p++) {
		if (($realpos{$p}{red} == 0) && ($realpos{$p}{green} == 0) && ($realpos{$p}{type} == 1)) {
			$auxX = 0;
			$auxY = 0;
			$x = $realpos{$p}{x}/10;
			$y = $realpos{$p}{y}/10;
			#way to round up the number, the ceil function didn't work
			if (($x - int($x)) > 0) { $auxX = 1 }
			if (($y - int($y)) > 0) { $auxY = 1 }

			#chech the registered and blank points at the same points
			for ($index = 0; $index < @posx; $index++) {
				if (($posx[$index] == (int($x) + $auxX)) && ($posy[$index] == (int($y) + $auxY))) {
					message "[$prefix] Unregistering position: x = $posx[$index] ; y = $posy[$index].\n", "success";
					delete $posx[$index];
					delete $posy[$index];
				}
			}
		}
	}
	$point = 0;
#####################################
#Translating the registered points
	$num = 0;
	message "[$prefix] Starting to translate the number.\n", "success";
	#check all the points at the map and create the number or letter
	for ($y = $maxHeigth;$y >= 0;$y--) {
		for ($x = 0;$x <= 20;$x++) {
			foreach my $pp (@posx) {
				if (($posx[$num] == $x) && ($posy[$num] == $y)){
					$msgline[$y] .= "#";
					$pointRead = 1;
				}
					$num++;
			}
			if  (!$pointRead) {
				$msgline[$y] .= ".";
			}
			$pointRead = 0;
				$num = 0;
		}
		message "[$prefix] Line [$y]: $msgline[$y].\n", "success";
	}
	@posx = ();
	@posy = ();
	
	#get num & position
	for ($j = $maxHeigth;$j >= 0;$j--) {
		for ($i = 0;$i <= length($msgline[1]);$i++) {
			if (((length($msgline[1]) - $i) >= $lengthCharNumber) && (($j + 1) >= $heigthCharNumber)) {
				$num_0[$line_msgNum]  = substr($msgline[$j], $i, $lengthCharNumber);
				$num_0[$line_msgNum] .= substr($msgline[$j-1], $i, $lengthCharNumber);
				$num_0[$line_msgNum] .= substr($msgline[$j-2], $i, $lengthCharNumber);
				$num_0[$line_msgNum] .= substr($msgline[$j-3], $i, $lengthCharNumber);
				$num_0[$line_msgNum] .= substr($msgline[$j-4], $i, $lengthCharNumber);
				$num_0[$line_msgNum] .= substr($msgline[$j-5], $i, $lengthCharNumber);
				$num_0[$line_msgNum] .= substr($msgline[$j-6], $i, $lengthCharNumber);
				$num_0[$line_msgNum] .= substr($msgline[$j-7], $i, $lengthCharNumber);
				$num_0[$line_msgNum] .= substr($msgline[$j-8], $i, $lengthCharNumber);
				$num_0[$line_msgNum] .= substr($msgline[$j-9], $i, $lengthCharNumber);
				$num_0[$line_msgNum] .= substr($msgline[$j-10], $i, $lengthCharNumber);
				$num_0[$line_msgNum] .= substr($msgline[$j-11], $i, $lengthCharNumber);
				$num_0[$line_msgNum] .= substr($msgline[$j-12], $i, $lengthCharNumber);
				$num_0[$line_msgNum] .= substr($msgline[$j-13], $i, $lengthCharNumber);
				  
				$line_msgNum += 1;
			}
		}
	}
	
	my %digit =  (
	'...##.##......##.##..............##....##...##....##....................##.........##....................##.........##..............##.##.##.####.##.##.##' => 1,
	'##.##.##.####.##.##.##....................##.........##...........##.##.##.####.##.##.##....................##.........##...........##.##.##.####.##.##.##' => 3,
	'##.......####.......##...........##.......####.......##...........##.##.##.####.##.##.##....................##.........##....................##.........##' => 4,
	'##.##.##.####.##.##.##...........##.........##....................##.##.##.####.##.##.##...........##.......####.......##...........##.##.##.####.##.##.##' => 6,
	'##.##.##.####.##.##.##....................##.........##.................##.........##.................##.........##.................##.........##.........' => 7,
	'##.##.##.####.##.##.##...........##.......####.......##...........##.##.##.####.##.##.##...........##.......####.......##...........##.##.##.####.##.##.##' => 8,
	'##.##.##.####.##.##.##...........##.......####.......##...........##.##.##.####.##.##.##....................##.........##...........##.##.##.####.##.##.##' => 9
	);
	
	my $k = 0;
	my $ans = '';
	my $cmd;
	
	#compare the translated number or letter with the created number or letter at the %digit
	foreach (keys %digit) {
		LOOP: for ($k = 0;$k <= $line_msgNum;$k++) {
			if ($_ eq $num_0[$k] ) {
				$ans = $digit{$_};
				last LOOP;
			}
		}
	}
	$cmd = "talk $answerType ".$ans;
	
	#timeout code to answer
	$Timecount{start} = time;
	$Timecount{current} = $Timecount{start};
	$Timecount{toreset} = 1 + rand(5);
	$Timecount{after} = $Timecount{start} + $Timecount{toreset};
	message "[$prefix] Waiting delay of $Timecount{toreset} secs to answer.\n", "success";
	while (1) {
		$Timecount{current} = time;
		last if ($Timecount{current} >= $Timecount{after});
	}
	
	message "[$prefix] Executing command \"$cmd\".\n", "success";
	Commands::run($cmd);			

    $run = 0;
	undef @num_0;
	undef @msgline;
	undef %Timecount;

}

return 1;