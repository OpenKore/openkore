package teleToDest;

use strict;
use warnings;
use Settings;
use Plugins;
use Misc;
use Globals qw($char %config $net %timeout %maps_lut $field);
use Log qw(message error debug);
use Utils;
use AI;

Plugins::register("teleToDest", "teleToDest", \&on_unload, \&on_unload);

my $base_hooks = Plugins::addHooks(
	['postloadfiles', \&checkConfig],
    ['configModify',  \&on_configModify]
   );

use constant {
	INACTIVE => 0,
	ACTIVE => 1,
	TELEPORTING => 2
};

my $status = INACTIVE;
my $coordinate_x;
my $coordinate_y;
my $mapchange_hook;
my $teleporting_hook;
my $timeout = { time => 0, timeout => 1 };

#Config
#teleToDestOn 1/0
#teleToDestMap 
#teleToDestXY 
#teleToDestDistance 
#teleToDestMethod steps/radius

sub on_unload {
   Plugins::delHook($base_hooks);
   changeStatus(INACTIVE);
   message "[teleToDest] Plugin unloading or reloading.\n", 'success';
}

sub checkConfig {
	return changeStatus(ACTIVE) if (validate_config() && $config{teleToDestOn});
	return changeStatus(INACTIVE);
}

sub on_configModify {
	my (undef, $args) = @_;
	return unless ($args->{key} eq 'teleToDestOn' || $args->{key} eq 'teleToDestMap' || $args->{key} eq 'teleToDestXY' || $args->{key} eq 'teleToDestDistance' || $args->{key} eq 'teleToDestMethod');
	return changeStatus(ACTIVE) if (validate_config($args->{key}, $args->{val}) && ($args->{key} eq 'teleToDestOn' ? $args->{val} : $config{teleToDestOn}));
	return changeStatus(INACTIVE);
}

sub validate_config {
	my ($key, $val) = @_;

	if ((!defined $config{teleToDestOn} || !defined $config{teleToDestMap} || !defined $config{teleToDestXY} || !defined $config{teleToDestDistance} || !defined $config{teleToDestMethod}) || (defined $key && !defined $val)) {
		message "[teleToDest] There are config keys not defined, plugin won't be activated.\n","system";
		return 0;
	}
	
	return 0 unless ( validate_teleToDestOn( defined $key && $key eq 'teleToDestOn' ? $val : $config{teleToDestOn} ) );
	
	return 0 unless ( validate_teleToDestMap( defined $key && $key eq 'teleToDestMap' ? $val : $config{teleToDestMap} ) );
	
	return 0 unless ( validate_teleToDestXY( defined $key && $key eq 'teleToDestXY' ? $val : $config{teleToDestXY} ) );
	
	return 0 unless ( validate_teleToDestDistance( defined $key && $key eq 'teleToDestDistance' ? $val : $config{teleToDestDistance} ) );
	
	return 0 unless ( validate_teleToDestMethod( defined $key && $key eq 'teleToDestMethod' ? $val : $config{teleToDestMethod} ) );
	
	return 1;
}

sub validate_teleToDestOn {
	my ($val) = @_;
	if ($val !~ /[01]/) {
		message "[teleToDest] Value of key 'teleToDestOn' must be 0 or 1, plugin won't be activated.\n","system";
		return 0;
	}
	return 1;
}

sub validate_teleToDestMap {
	my ($val) = @_;
	my $map_name = $val;
	$map_name =~ s/^(\w{3})?(\d@.*)/$2/;
	my $file = $map_name.'.fld';
	$file = File::Spec->catfile($Settings::fields_folder, $file) if ($Settings::fields_folder);
	$file .= ".gz" if (! -f $file); # compressed file
	unless ($maps_lut{"${map_name}.rsw"} || -f $file) {
		message "[teleToDest] Map '".$val."' does not exist, plugin won't be activated.\n","system";
		return 0;
	}
	return 1;
}

sub validate_teleToDestXY {
	my ($val) = @_;
	if ($val =~ /(\d+)\s+(\d+)/) {
		$coordinate_x = $1;
		$coordinate_y = $2;
	} else {
		message "[teleToDest] Value of key 'teleToDestXY' is not a valid coordinate ('".$val."'), plugin won't be activated.\n","system";
		return 0;
	}
	return 1;
}

sub validate_teleToDestDistance {
	my ($val) = @_;
	if ($val !~ /\d+/) {
		message "[teleToDest] Value of key 'teleToDestDistance' is not a valid number ('".$val."'), plugin won't be activated.\n","system";
		return 0;
	}
	return 1;
}

sub validate_teleToDestMethod {
	my ($val) = @_;
	if ($val !~ /(radius|steps)/) {
		message "[teleToDest] Value of key 'teleToDestMethod' is not a valid method ('".$val."'), plugin won't be activated.\n","system";
		return 0;
	}
	return 1;
}

sub changeStatus {
	my $new_status = shift;
	my $old_status = $status;
	if ($new_status == INACTIVE) {
		Plugins::delHook($mapchange_hook) if ($status == ACTIVE || $status == TELEPORTING);
		Plugins::delHook($teleporting_hook) if ($status == TELEPORTING);
		undef $coordinate_x;
		undef $coordinate_y;
		debug "[teleToDest] Plugin stage changed to 'INACTIVE'\n";
	} elsif ($new_status == ACTIVE) {
		Plugins::delHook($teleporting_hook) if ($status == TELEPORTING);
		$mapchange_hook = Plugins::addHooks(
			['packet/sendMapLoaded', \&on_map_loaded]
		);
		debug "[teleToDest] Plugin stage changed to 'ACTIVE'\n";
	} elsif ($new_status == TELEPORTING) {
		$teleporting_hook = Plugins::addHooks(
			['AI_pre',            \&on_ai_pre]
		);
		debug "[teleToDest] Plugin stage changed to 'TELEPORTING'\n";
	}
	
	$status = $new_status;
	
	if ($new_status == ACTIVE && $old_status == INACTIVE && $char && $net->getState == Network::IN_GAME && ($config{'teleToDestMap'} eq $field->baseName || $config{'teleToDestMap'} eq $field->name)) {
		if ($field->width < $coordinate_x) {
			message "[teleToDest] Value of key 'teleToDestXY' is not a valid coordinate, teleToDest disabled.\n","system";
			configModify('teleToDestOn', 0);
		} elsif ($field->height < $coordinate_y) {
			message "[teleToDest] Value of key 'teleToDestXY' is not a valid coordinate, teleToDest disabled.\n","system";
			configModify('teleToDestOn', 0);
		} else {
			changeStatus(TELEPORTING);
		}
	}
}

sub on_map_loaded {
	if ($status == TELEPORTING) {
		if (($config{'teleToDestMap'} eq $field->baseName || $config{'teleToDestMap'} eq $field->name)) {
			debug "[teleToDest] Character is still inside goal map.\n";
		} else {
			debug "[teleToDest] Character for some reason left the goal map, changing plugin stage.\n";
			changeStatus(ACTIVE);
		}
	} else {
		if (($config{'teleToDestMap'} eq $field->baseName || $config{'teleToDestMap'} eq $field->name)) {
			if ($field->width < $coordinate_x) {
				message "[teleToDest] Value of key 'teleToDestXY' is not a valid coordinate, teleToDest disabled.\n","system";
				configModify('teleToDestOn', 0);
			} elsif ($field->height < $coordinate_y) {
				message "[teleToDest] Value of key 'teleToDestXY' is not a valid coordinate, teleToDest disabled.\n","system";
				configModify('teleToDestOn', 0);
			} else {
				debug "[teleToDest] Character got to goal map, changing plugin stage.\n";
				changeStatus(TELEPORTING);
			}
		} else {
			debug "[teleToDest] Character is still not inside goal map.\n";
		}
	}
}



sub on_ai_pre {
	return if !$char;
	return if $net->getState != Network::IN_GAME;
	return if !timeOut( $timeout );
	$timeout->{time} = time;
	if (check_distance()) {
		message "[teleToDest] Using teleport.\n", "info";
		if (canUseTeleport(1)) {
			ai_useTeleport(1);
			message "[teleToDest] Teleport sent.\n", "info";
		} else {
			message "[teleToDest] Cannot use teleport; teleToDest disabled.\n", "info";
			configModify('teleToDestOn', 0);
		}
	} else {
		message "[teleToDest] Destination reached; teleToDest disabled.\n", "info";
		configModify('teleToDestOn', 0);
	}
}

sub check_distance {
	my $dist;
	if ($config{'teleToDestMethod'} eq 'radius') {
		$dist = round(distance($char->{pos_to}, { x => $coordinate_x, y => $coordinate_y }));
	} elsif ($config{'teleToDestMethod'} eq 'steps') {
		my $pathfinding = new PathFinding;
		my $myPos = $char->{pos_to};
		my $myDest = { x => $coordinate_x, y => $coordinate_y };
		$pathfinding->reset(
			start => $myPos,
			dest  => $myDest,
			field => $field
		);
		$dist = $pathfinding->runcount;
	}
	return 1 if ($dist > $config{teleToDestDistance});
	return 0;
}

return 1;