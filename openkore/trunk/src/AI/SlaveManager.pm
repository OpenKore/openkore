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
	$actor->{slave_AI} = 2;

	if ($actor->{actorType} eq 'Homunculus') {
		$actor->{slave_configPrefix} = 'homunculus_';
		bless $actor, 'AI::Slave::Homunculus';
		
	} elsif ($actor->{actorType} eq 'Mercenary') {
		$actor->{slave_configPrefix} = 'mercenary_';
		bless $actor, 'AI::Slave::Mercenary';
		
	} else {
		$actor->{slave_configPrefix} = 'slave_';
		bless $actor, 'AI::Slave';
	}

	$char->{slaves}{$actor->{ID}} = $actor;
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
			return 0 unless $slave->isIdle;
		}
	}
	return 1;
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
