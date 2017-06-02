# Unit test for Task::WaitForAnyHook
package TaskWaitForAnyHookTest;
use strict;
use Time::HiRes qw(usleep);

use Test::More;
use Task::WaitForAnyHook;

use constant {
	TIMEOUT => 0.01,
	HOOK_1 => __PACKAGE__ . '_TESTHOOK_1',
	HOOK_2 => __PACKAGE__ . '_TESTHOOK_2',
	HOOK_3 => __PACKAGE__ . '_TESTHOOK_3',
};

sub testOneHook {
	diag "Testing usage with one hook";

	my $task = Task::WaitForAnyHook->new(timeout => TIMEOUT, hooks => [HOOK_1]);
	ok(!Plugins::hasHook(HOOK_1), "Hook is not registered before activation");
	$task->activate;
	is($task->getStatus, Task::RUNNING, "Task is running after activation");
	ok(Plugins::hasHook(HOOK_1), "Hook is registered after activation");
	$task->iterate;
	is($task->getStatus, Task::RUNNING, "Task is running after initial iteration");
	Plugins::callHook(HOOK_1);
	is($task->getStatus, Task::RUNNING, "Task is running after the hook was called");
	$task->iterate;
	is($task->getStatus, Task::DONE, "Task is done after an iteration when the hook was called");
	ok(!Plugins::hasHook(HOOK_1), "Hook is not registered after the task is done");
}

sub testSeveralHooks {
	diag "Testing usage with several hooks";

	my $task = Task::WaitForAnyHook->new(timeout => TIMEOUT, hooks => [HOOK_1, HOOK_2, HOOK_3]);
	ok(!Plugins::hasHook(HOOK_1), "Hooks are not registered before activation");
	ok(!Plugins::hasHook(HOOK_2), "Hooks are not registered before activation");
	ok(!Plugins::hasHook(HOOK_3), "Hooks are not registered before activation");
	$task->activate;
	is($task->getStatus, Task::RUNNING, "Task is running after activation");
	ok(Plugins::hasHook(HOOK_1), "Hooks are registered after activation");
	ok(Plugins::hasHook(HOOK_2), "Hooks are registered after activation");
	ok(Plugins::hasHook(HOOK_3), "Hooks are registered after activation");
	$task->iterate;
	is($task->getStatus, Task::RUNNING, "Task is running after initial iteration");
	Plugins::callHook(HOOK_2);
	is($task->getStatus, Task::RUNNING, "Task is running after the hook was called");
	$task->iterate;
	is($task->getStatus, Task::DONE, "Task is done after an iteration when the hook was called");
	ok(!Plugins::hasHook(HOOK_1), "Hooks are not registered after the task is done");
	ok(!Plugins::hasHook(HOOK_2), "Hooks are not registered after the task is done");
	ok(!Plugins::hasHook(HOOK_3), "Hooks are not registered after the task is done");
}

sub testNoHooks {
	diag "Testing usage with no hooks";

	my $task = Task::WaitForAnyHook->new(timeout => TIMEOUT, hooks => []);
	$task->activate;
	is($task->getStatus, Task::RUNNING, "Task is running after activation");
	$task->iterate;
	is($task->getStatus, Task::RUNNING, "Task is running after initial iteration");
	Plugins::callHook(HOOK_1);
	Plugins::callHook(HOOK_2);
	Plugins::callHook(HOOK_3);
	$task->iterate;
	is($task->getStatus, Task::RUNNING, "Task is running after some hooks were called");
	usleep 2 * TIMEOUT * 1e6;
	$task->iterate;
	is($task->getStatus, Task::DONE, "Task is done after the timeout has passed");
	ok(defined $task->getError, "Task failed after the timeout has passed");
}

sub testTimeout {
	diag "Testing failing by timeout";

	my $task = Task::WaitForAnyHook->new(timeout => TIMEOUT, hooks => [HOOK_1]);
	usleep 2 * TIMEOUT * 1e6;
	$task->activate;
	ok(Plugins::hasHook(HOOK_1), "Hook is registered after activation");
	$task->iterate;
	is($task->getStatus, Task::RUNNING, "Task is running after a delay between creation and activation");
	usleep 0.5 * TIMEOUT * 1e6;
	$task->iterate;
	is($task->getStatus, Task::RUNNING, "Task is running after a half of specified timeout has passed");
	usleep 1.5 * TIMEOUT * 1e6;
	$task->iterate;
	is($task->getStatus, Task::DONE, "Task is done after the timeout has passed");
	ok(defined $task->getError, "Task failed after the timeout has passed");
	ok(!Plugins::hasHook(HOOK_1), "Hook is not registered after the task failed");
}
sub start {
	diag "### Starting " . __PACKAGE__;

	testOneHook;
	testSeveralHooks;
	testNoHooks;
	testTimeout;
}

1;