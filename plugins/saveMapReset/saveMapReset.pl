package saveMapReset;

use strict;
use Globals;
use Settings;
use Misc;
use Plugins;
use Utils;
use Log qw(message debug error warning);

Plugins::register('saveMapReset', 'saveMapReset', \&onUnload);

my $hooks = Plugins::addHooks(
	# Setup
	['taskTeleport_mapChanged', \&on_taskTeleport_mapChanged, undef],
);

sub on_taskTeleport_mapChanged {
	my ($hook, $args) = @_;
	my $task = $args->{task};
	return unless ($task->isa("Task::Teleport::Respawn"));
	return unless ($field->baseName ne $config{'saveMap'});
	error ( "[saveMapReset] Tried to respawn to ".($config{'saveMap'}).", ended up on ".($field->baseName)."\n" );
	configModify ('saveMap', undef)
}

sub onUnload {
    Plugins::delHooks($hooks);
}

return 1;