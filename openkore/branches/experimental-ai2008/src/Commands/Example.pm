package Commands::Example;

use strict;
use threads;
use threads::shared;

use Globals qw($interface);
use Settings qw(%sys);
use Log qw(message warning error debug);
use Translation qw(T TF);
use Utils::Exceptions;
use Commands;
use base qw(Commands);

use Modules 'register';


sub new {
	my $class = shift;
	my $cmd = shift;
	my %args = @_;
	my $self = {};
	bless $self, $class;

	$cmd->register(["example", "Just an Example", \&cmdExample, $self]);
	message T("Command \"example\" registered!!!\n"), "cmd";

	$cmd->register(["example2", "Just an Example", \&cmdExample2, $self]);
	message T("Command \"example2\" registered!!!\n"), "cmd";

	# Try to register using erronus params
	$cmd->register("example", "Just an Example", \&cmdExample, $self);
	# If we are here... then all went good.

	return $self;
}

sub DESTROY {
	my ($self) = @_;
	$self->SUPER::DESTROY();
}

sub cmdExample {
	my $self = shift;
	my %args = @_;

	message T("Example command called!!!\n"), "cmd";

	return 1;
}

sub cmdExample2 {
	my $self = shift;
	my %args = @_;

	message T("Example2 command called!!!\n"), "cmd";

	return 1;
}

1;
