# Unit test for Task::WaitFor
package TaskWaitForTest;
use strict;
use Time::HiRes qw(usleep);

use Test::More;
use Task::WaitFor;

use constant {
	TIMEOUT => 0.01,
};

sub testBasicUsage {
	diag "Testing basic usage";

	my $success;

	my $task = Task::WaitFor->new(timeout => TIMEOUT, function => sub { $success });
	$task->activate;
	is($task->getStatus, Task::RUNNING, "Task is running after activation");
	$task->iterate;
	is($task->getStatus, Task::RUNNING, "Task is running after initial iteration");
	$success = 1;
	is($task->getStatus, Task::RUNNING, "Task is running after the condition became true");
	$task->iterate;
	is($task->getStatus, Task::DONE, "Task is done after a single iteration while the condition was true");
}

sub testTimeout {
	diag "Testing failing by timeout";

	my $task = Task::WaitFor->new(timeout => TIMEOUT, function => sub { 0 });
	usleep 2 * TIMEOUT * 1e6;
	$task->activate;
	$task->iterate;
	is($task->getStatus, Task::RUNNING, "Task is running after a delay between creation and activation");
	usleep 0.5 * TIMEOUT * 1e6;
	$task->iterate;
	is($task->getStatus, Task::RUNNING, "Task is running after a half of specified timeout has passed");
	usleep 1.5 * TIMEOUT * 1e6;
	$task->iterate;
	is($task->getStatus, Task::DONE, "Task is done after the timeout has passed");
	ok(defined $task->getError, "Task failed after the timeout has passed");
}

sub start {
	diag "### Starting " . __PACKAGE__;

	testBasicUsage;
	testTimeout;
}

1;