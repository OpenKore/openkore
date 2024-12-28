package AI::SlaveManager;

use strict;
use Time::HiRes qw(time);

use Globals;
use Log qw/message warning error debug/;
use AI;
use Utils;
use Misc;
use Translation;

use AI::Slave;

sub addSlave {
	my $actor = shift;

	$actor->{slave_ai_seq} = [];
	$actor->{slave_ai_seq_args} = [];
	$actor->{slave_skillsID} = [];
	$actor->{skills} = {};
	$actor->{slave_AI} = AI::AUTO;

	if ($actor->isa("Actor::Slave::Homunculus")) {
		$actor->{configPrefix} = 'homunculus_';
		$actor->{ai_attack_timeout} = 'ai_homunculus_attack';
		$actor->{ai_attack_auto_timeout} = 'ai_homunculus_attack_auto';
		$actor->{ai_check_monster_auto} = 'ai_homunculus_check_monster_auto';
		$actor->{ai_route_adjust_timeout} = 'ai_homunculus_route_adjust';
		$actor->{ai_attack_main} = 'ai_homunculus_attack_main';
		$actor->{ai_standby_timeout} = 'ai_homunculus_standby';
		$actor->{ai_dance_attack_melee_timeout} = 'ai_homunculus_dance_attack_melee';
		$actor->{ai_attack_waitAfterKill_timeout} = 'ai_homunculus_attack_waitAfterKill';
		$actor->{ai_attack_failed_timeout} = 'homunculus_attack_failed';
		if (!exists $char->{homunculus_info}) {
			$char->{homunculus_info} = {};
		}
		$actor->{homunculus_info} = $char->{homunculus_info}; # A reference
		bless $actor, 'AI::Slave::Homunculus';
		
	} elsif ($actor->isa("Actor::Slave::Mercenary")) {
		$actor->{configPrefix} = 'mercenary_';
		$actor->{ai_attack_timeout} = 'ai_mercenary_attack';
		$actor->{ai_attack_auto_timeout} = 'ai_mercenary_attack_auto';
		$actor->{ai_check_monster_auto} = 'ai_mercenary_check_monster_auto';
		$actor->{ai_route_adjust_timeout} = 'ai_mercenary_route_adjust';
		$actor->{ai_attack_main} = 'ai_mercenary_attack_main';
		$actor->{ai_standby_timeout} = 'ai_mercenary_standby';
		$actor->{ai_dance_attack_melee_timeout} = 'ai_mercenary_dance_attack_melee';
		$actor->{ai_dance_attack_ranged_timeout} = 'ai_mercenary_dance_attack_ranged';
		$actor->{ai_attack_waitAfterKill_timeout} = 'ai_mercenary_attack_waitAfterKill';
		$actor->{ai_attack_failed_timeout} = 'mercenary_attack_failed';
		bless $actor, 'AI::Slave::Mercenary';
		
	} else {
		$actor->{configPrefix} = 'slave_';
		bless $actor, 'AI::Slave';
	}

	$char->{slaves}{$actor->{ID}} = $actor;
}

sub removeSlave {
	my $actor = shift;
	delete $char->{slaves}{$actor->{ID}};
}

sub clear {
	return unless defined $char;
	
	foreach my $slave (values %{$char->{slaves}}) {
		if ($slave && %{$slave} && $slave->isa ('AI::Slave')) {
			$slave->clear (@_);
		}
	}
}

sub iterate {
	return unless defined $char;
	return unless $char->{slaves};

	foreach my $slave (values %{$char->{slaves}}) {
		if ($slave && %{$slave} && $slave->isa ('AI::Slave')) {
			$slave->iterate;
		}
	}
}

sub isIdle {
	return 1 unless defined $char;
	
	foreach my $slave (values %{$char->{slaves}}) {
		if ($slave && %{$slave} && $slave->isa ('AI::Slave')) {
			next if ($slave->isIdle);
			next if ($slave->action eq 'route' && $slave->args($slave->findAction('route'))->{isIdleWalk});
			return 0;
		}
	}
	return 1;
}

sub mustRescue {
	return 0 unless defined $char;
	
	foreach my $slave (values %{$char->{slaves}}) {
		if ($slave && %{$slave} && $slave->isa ('AI::Slave')) {
			return $slave if ($slave->isLost && $slave->mustRescue);
		}
	}
	return undef;
}

sub mustStopForAttack {
	return 0 unless defined $char;
	
	foreach my $slave (values %{$char->{slaves}}) {
		if ($slave && %{$slave} && $slave->isa ('AI::Slave')) {
			return $slave if ($slave->action eq "attack" && $config{$slave->{configPrefix}.'route_randomWalk_stopDuringAttack'});
		}
	}
	return undef;
}

sub mustMoveNear {
	return 0 unless defined $char;
	
	foreach my $slave (values %{$char->{slaves}}) {
		if ($slave && %{$slave} && $slave->isa ('AI::Slave')) {
			my $dist = $slave->blockDistance_master;
			return $slave if ($config{$slave->{configPrefix}.'moveNearWhenIdle'} && !$slave->isIdle && $dist > ($config{$slave->{configPrefix}.'moveNearWhenIdle_maxDistance'} || 8));
		}
	}
	return undef;
}

sub mustWaitMinDistance {
	return 0 unless defined $char;
	
	foreach my $slave (values %{$char->{slaves}}) {
		if ($slave && %{$slave} && $slave->isa ('AI::Slave')) {
			my $dist = $slave->blockDistance_master;
			return $slave if ($config{$slave->{configPrefix}.'route_randomWalk_waitMinDistance'} && $dist > $config{$slave->{configPrefix}.'route_randomWalk_waitMinDistance'});
		}
	}
	return undef;
}

sub setMapChanged {
	return unless defined $char;
	
	delete $char->{slaves};
	
# 	foreach my $slave (values %{$char->{slaves}}) {
# 		if ($slave && %{$slave} && $slave->isa ('AI::Slave')) {
# 			for (my $i = 0; $i < @{$slave->{slave_ai_seq}}; $i++) {
# 				$slave->slave_setMapChanged ($i);
# 			}
# 		}
# 	}
}

1;
