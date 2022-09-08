package fixKafraTeleport;
 
use strict;
use Plugins;
use Settings;
use Globals;
use Utils;
use Misc;
use Log qw(message error warning);
use Translation;
use Network;
 
#########
# startup
Plugins::register('fixKafraTeleport', '', \&Unload, \&Unload);

my $hooks = Plugins::addHooks(
	['npc_teleport_missing',   \&onmiss,    undef]
);

# onUnload
sub Unload {
	Plugins::delHooks($hooks);
}

sub onmiss {
	my ($self, $args) = @_;
	
	return if ($args->{plugin_retry} > 0);
	
	my ($from,$to) = split(/=/, $args->{portal});
	
	return unless ($portals_lut{$from}{dest}{$to}{allow_ticket});
	
	
	my $closest_portal_binID;
	my $closest_portal_dist;
	my $closest;
	my $closest_x;
	my $closest_y;
	
	foreach my $actor (@{$npcsList->getItems()}) {
		my $pos = ($actor->isa('Actor::NPC')) ? $actor->{pos} : $actor->{pos_to};
		next if ($actor->{statuses}->{EFFECTSTATE_BURROW});
		next if ($config{avoidHiddenActors} && ($actor->{type} == 111 || $actor->{type} == 139 || $actor->{type} == 2337)); # HIDDEN_ACTOR TYPES
		next unless (defined $actor->{name});
		next unless ($actor->{name} =~ /^Kafra Employee$/);
		my $dist = blockDistance($char->{pos_to}, $pos);
		next if (defined $closest_portal_dist && $closest_portal_dist < $dist);
		$closest_portal_binID = $actor->{binID};
		$closest_portal_dist = $dist;
		$closest = $actor;
		$closest_x = $pos->{x};
		$closest_y = $pos->{y};
	}
	
	if (defined $closest_portal_binID) {
		warning TF("[fixKafraTeleport] Guessing our desired kafra to be %s (%s,%s).\n", $closest, $closest_x, $closest_y), "system";
		$args->{x} = $closest_x;
		$args->{y} = $closest_y;
		$args->{return} = 1;
	}
	
	return;
}

return 1;
