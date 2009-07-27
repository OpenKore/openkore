package KoreStage::PortalsDatabase;

use strict;

# Coro Support
use Coro;

use Globals qw($interface);
use Settings qw(%sys);
use Log qw(message warning error debug);
use Translation qw(T TF);
use Plugins;
use Misc::Portals;
use Utils::Exceptions;
use KoreStage;
use base qw(KoreStage);

use Modules 'register';


sub new {
	my $class = shift;
	my %args = @_;
	my $self = {};
	bless $self, $class;
	$self->{priority} = 3;

	return $self;
}

sub DESTROY {
	my ($self) = @_;
	$self->SUPER::DESTROY();
}

sub load {
	my ($self) = @_;
	Log::message(T("Checking for new portals... "));
	if (Misc::Portals::compilePortals_check()) {
		Log::message(T("found new portals!\n"));
		my $choice = $interface->showMenu(
			T("New portals have been added to the portals database. " .
			"The portals database must be compiled before the new portals can be used. " .
			"Would you like to compile portals now?\n"),
			[T("Yes, compile now."), T("No, don't compile it.")],
			title => T("Compile portals?"));
		if ($choice == 0) {
			Log::message(T("compiling portals") . "\n\n");
			Misc::Portals::compilePortals();
		} else {
			Log::message(T("skipping compile") . "\n\n");
		}
	} else {
		Log::message(T("none found\n\n"));
	}
}

1;
