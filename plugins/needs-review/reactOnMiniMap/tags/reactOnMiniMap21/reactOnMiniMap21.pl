###########################
# React on Mini Map Indicator plugin by Mucilon
# BotKiller #1 - Method 3: MiniMap number
# Based on reactOnNPC by hakore and reactOnASCIInumber by windows98SE@thaikore 
# Version 0.1
# 11.09.2008
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
				['packet/npc_talk_number', \&onAction, undef],
				['packet/npc_talk_text', \&onAction, undef],
				['packet/npc_talk_continue', \&onContinue, undef],
				['packet/npc_talk_close', \&onContinue, undef]);
				
				
my $run;
my @posx;
my @posy;
my $num = 0;
my $prefix = "reactOnMiniMap v0.1";

sub onUnload {
    Plugins::delHooks($hooks);
	undef @posx;
	undef @posy;
};

sub onMiniMap {
    my ($self, $args) = @_;
	my $auxX = 0;
	my $auxY = 0;
	my $x;
	my $y;
#	message "[reactOnMiniMap] New position: x = $args->{x} ; y = $args->{y}.\n", "success";

	if (($args->{green} == 255) && ($args->{type} == 1)) {
		$x = $args->{x}/10;
		$y = $args->{y}/10;
		
		if (($x - int($x)) > 0) { $auxX = 1 }
		if (($y - int($y)) > 0) { $auxY = 1 }

		$posx[$num] = int($x) + $auxX;
	    $posy[$num] = int($y) + $auxY;
		message "[$prefix] Registering position: x = $posx[$num] ; y = $posy[$num].\n", "success";
		$num++;
		$run = 1;
	}
}

sub onContinue {
    my (undef, $args) = @_;
	$num = 0;
	@posx = ();
	@posy = ();
	message "[$prefix] Reseting variables.\n", "success";
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
	my $i = 0;
	my $j = 0;
	my @num_0 = ();
	
	$num = 0;
	# @msgline = ();
	message "[$prefix] Starting to translate the number.\n", "success";
    if ($run == 1) {
		for ($y = $maxHeigth;$y >= 0;$y--) {
			for ($x = 0;$x <= 20;$x++) {
				foreach my $point (@posx) {
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
	  
		foreach (keys %digit) {
			LOOP: for ($k = 0;$k <= $line_msgNum;$k++) {
				if ($_ eq $num_0[$k] ) {
					$ans = $digit{$_};
					last LOOP;
				}
			}
		}
		$cmd = "talk num ".$ans;
		
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

    }
    $run = 0;
	undef @num_0;
	undef @msgline;
	undef %Timecount;

}

return 1;