package VendingLog::HookManager;

use strict;

use Plugins;
use Log qw(debug);

use lib $Plugins::current_plugin_folder;
use VendingLog::Translation qw(TF);

use constant {
	PACKAGE_PREFIX => "[VL_HookManager]",
};

sub new {
	my $class = shift;
	my $self = {
		hookString => shift,
		callback => shift,
	};
	
	bless $self, $class;
	return $self;
}

sub hook {
	my ($self) = @_;
	
	if (not exists $self->{hook}) {
		$self->{hook} = Plugins::addHook($self->{hookString}, $self->{callback});
		debug TF("%s Hooked onto %s!\n", PACKAGE_PREFIX, $self->{hookString});
	}
}

sub unhook {
	my ($self) = @_;
	
	if (exists $self->{hook}) {
		Plugins::delHook($self->{hookString}, $self->{hook});
		delete $self->{hook};
		debug TF("%s Unhooked from %s!\n", PACKAGE_PREFIX, $self->{hookString});
	}
}

1;