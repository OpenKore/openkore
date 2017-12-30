package VendingLog::HookManager;

use strict;

use Plugins;
use Log qw(debug);
use Settings qw(%sys);

use constant {
	PACKAGE_PREFIX => "[VL_HookManager]",
	PLUGIN_PODIR => "$Plugins::current_plugin_folder/po",
};

my $translator = new Translation(PLUGIN_PODIR, $sys{locale});

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
		debug $translator->translatef("%s Hooked onto %s!\n", PACKAGE_PREFIX, $self->{hookString});
	}
}

sub unhook {
	my ($self) = @_;
	
	if (exists $self->{hook}) {
		Plugins::delHook($self->{hookString}, $self->{hook});
		delete $self->{hook};
		debug $translator->translatef("%s Unhooked from %s!\n", PACKAGE_PREFIX, $self->{hookString});
	}
}

1;