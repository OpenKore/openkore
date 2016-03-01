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
use Globals;
use Log qw(message warning error);

Plugins::register('reactOnMiniMap', 'React on Mini Map Indicator plugin', \&onUnload);

my $hooks = Plugins::addHooks(	['packet/minimap_indicator', \&onMiniMap, undef],
				['packet/npc_talk_number', \&onAction, undef],
				['packet/npc_talk_text', \&onAction, undef],
				['packet/npc_talk_continue', \&onContinue, undef]);
my $run;
my @posx;
my @posy;
my $num = 0;

sub onUnload {
    Plugins::delHooks($hooks);
};

sub onMiniMap {
    my ($self, $args) = @_;
	my $auxX = 0;
	my $auxY = 0;
	my $x;
	my $y;
#	message "[reactOnMiniMap] New position: x = $args->{x} ; y = $args->{y}.\n", "success";

	if ($args->{green} == 255) {
		$x = $args->{x}/10;
		$y = $args->{y}/10;
		
		if (($x - int($x)) > 0) { $auxX = 1 }
		if (($y - int($y)) > 0) { $auxY = 1 }

		$posx[$num] = int($x) + $auxX;
	    $posy[$num] = int($y) + $auxY;
		message "[reactOnMiniMap] Registering position: x = $posx[$num] ; y = $posy[$num].\n", "success";
		$num++;
		$run = 1;
	}
}

sub onContinue {
    my (undef, $args) = @_;
	$num = 0;
	@posx = ();
	@posy = ();
	message "[reactOnMiniMap] Reseting variables.\n", "success";
}

sub onAction {
    my (undef, $args) = @_;
    # my $randtime;
	my $x = 0;
	my $y = 0;
	my $pointRead = 0;
	my @msgline;
	$num = 0;
	@msgline = ();
	message "[reactOnMiniMap] Starting to translate the number.\n", "success";
    if ($run == 1) {
		for ($y = 20;$y >= 0;$y--) {
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
			message "[reactOnMiniMap] Line [$y]: $msgline[$y].\n", "success";
		}
		@posx = ();
		@posy = ();
		
		# $randtime = 1 + rand(3);
		# message "[reactOnMiniMap] Exexuting command: talk num $answer, in $randtime secs.\n", "success";
		# sleep($randtime);
		# Commands::run("talk num $answer"); 
    }
    $run = 0;
}

return 1;