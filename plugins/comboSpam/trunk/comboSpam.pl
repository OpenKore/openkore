package comboSpam;

use strict;
use Plugins;
use Globals;
use Skills;
use Misc;
use Network;
use Network::Send;
use Utils;
use Time::HiRes qw(time usleep);


Plugins::register('comboSpam', 'spam combo packets', \&on_unload);
my $hook1 = Plugins::addHook('packet/actor_status_active', \&combo);
my $hook2 = Plugins::addHook('AI_pre', \&AI_pre);
my $combo = 0;
my $delay = .2;
my $time = time;

sub on_unload {
	# This plugin is about to be unloaded; remove hooks
	Plugins::delHook("packet/actor_status_active", $hook1);
	Plugins::delHook("AI_pre", $hook1);
}

sub combo {
	my ($packet, $args) = @_;
	my ($type, $ID, $flag) = @{$args}{qw(type ID flag)};
	
	if ($skillsStatus{$type} eq "Triple Attack Delay") {
		$combo = $flag;
	}
}

sub AI_pre {
	my ($self, $args) = @_;
	
	if ($combo && main::timeOut($time, $delay)) {
		sendSkillUse($net, 272, 5, $accountID); # Chain Combo
		if ($char->{spirits}) { # Make sure there is a spirit sphere
			sendSkillUse($net, 273, 5, $accountID); # Combo Finish
		}
		$time = time;
	}
}

1; 
