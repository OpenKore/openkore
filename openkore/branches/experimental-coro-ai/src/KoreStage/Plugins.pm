package KoreStage::Plugins;

use strict;

# Coro Support
use Coro;

use Globals qw($interface);
use Settings qw(%sys);
use Log qw(message warning error debug);
use Translation qw(T TF);
use Plugins;
use Utils::Exceptions;
use KoreStage;
use base qw(KoreStage);

use Modules 'register';


sub new {
	my $class = shift;
	my %args = @_;
	my $self = {};
	bless $self, $class;
	$self->{priority} = 1;

	return $self;
}

sub DESTROY {
	my ($self) = @_;
	$self->SUPER::DESTROY();
}

sub load {
	my ($self) = @_;
	eval {
		Plugins::loadAll();
	};
	my $e;
	if ($e = caught('Plugin::LoadException')) {
		$interface->errorDialog(TF("This plugin cannot be loaded because of a problem in the plugin. " .
			"Please notify the plugin's author about this problem, " .
			"or remove the plugin so %s can start.\n\n" .
			"The error message is:\n" .
			"%s",
			$Settings::NAME, $e->message));
		exit 1;
	} elsif ($e = caught('Plugin::DeniedException')) {
		$interface->errorDialog($e->message);
		exit 1;
	} elsif ($@) {
		die $@;
	}

	Log::message("\n");
	Plugins::callHook('start');
}

1;
