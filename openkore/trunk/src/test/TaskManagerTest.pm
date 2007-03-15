# A unit test for TaskManager.
package TaskManagerTest;

use strict;
use Test::More;
use Task;
use Task::Testing;
use TaskManager;

sub start {
	print "### Starting TaskManagerTest\n";
	testStaticMutexes();
	testDynamicMutexes();
	testImmediateStop();
	testDeferredStop();
	testMisc();
}

# Test a case in which task mutexes are static (do not change during the task's life time).
sub testStaticMutexes {
	my $tm = new TaskManager();
	my ($taskA, $taskB, $taskC);
	print "Testing case with static mutexes...\n";

	$tm->add($taskA = createTask(name => "A"));
	$tm->add($taskB = createTask(name => "B"));
	$tm->add($taskC = createTask(name => "C"));
	$tm->reschedule();
	assertActiveTasks($tm, "A,B,C", "Active tasks: A,B,C");
	assertInactiveTasks($tm, "", "Inactive tasks: none");
	$taskA->markDone();
	$taskB->markDone();
	$taskC->markDone();
	$tm->iterate();
	assertActiveTasks($tm, "", "Active tasks: none");
	assertInactiveTasks($tm, "", "Inactive tasks: none");
	is($tm->countTasksByName('A'), 0);
	is($tm->countTasksByName('B'), 0);
	is($tm->countTasksByName('C'), 0);

	$tm = new TaskManager();
	$tm->add($taskA = createTask(name => "A", mutexes => ["1", "2"]));
	$tm->add($taskB = createTask(name => "B"));
	$tm->add($taskC = createTask(name => "C"));
	$tm->reschedule();
	assertActiveTasks($tm, "A,B,C", "Active tasks: A,B,C");
	assertInactiveTasks($tm, "", "Inactive tasks: none");
	is($tm->countTasksByName('A'), 1);
	is($tm->countTasksByName('B'), 1);
	is($tm->countTasksByName('C'), 1);

	$tm = new TaskManager();
	$tm->add($taskA = createTask(name => "A", mutexes => ["1", "2"]));
	$tm->add($taskB = createTask(name => "B"));
	$tm->add($taskC = createTask(name => "C", mutexes => ["2"]));
	$tm->reschedule();
	assertActiveTasks($tm, "A,B", "Active tasks: A,B");
	assertInactiveTasks($tm, "C", "Inactive tasks: C");

	$tm = new TaskManager();
	$tm->add($taskA = createTask(name => "A", mutexes => ["1", "2"]));
	$tm->add($taskB = createTask(name => "B", mutexes => ["1"]));
	$tm->add($taskC = createTask(name => "C", mutexes => ["2"], priority => Task::HIGH_PRIORITY));
	$tm->reschedule();
	assertActiveTasks($tm, "C", "Active tasks: C");
	assertInactiveTasks($tm, "A,B", "Inactive tasks: A,B");
	is($tm->countTasksByName('A'), 1);
	is($tm->countTasksByName('B'), 1);
	is($tm->countTasksByName('C'), 1);
	is($tm->countTasksByName('D'), 0);

	$taskC->markDone();
	$tm->iterate();
	$tm->reschedule();
	assertActiveTasks($tm, "B", "Active tasks: B");
	assertInactiveTasks($tm, "A", "Inactive tasks: A");
	is($tm->countTasksByName('A'), 1);
	is($tm->countTasksByName('B'), 1);
	is($tm->countTasksByName('C'), 0);
	is($tm->countTasksByName('D'), 0);

	$tm->add(createTask(name => "D", mutexes => ["3"]));
	$tm->iterate();
	assertActiveTasks($tm, "B,D", "Active tasks after setting non-conflicting mutexes: B,D");
	assertInactiveTasks($tm, "A", "Inactive tasks: A");
	is($tm->countTasksByName('A'), 1);
	is($tm->countTasksByName('B'), 1);
	is($tm->countTasksByName('C'), 0);
	is($tm->countTasksByName('D'), 1);
}

# Test a case in which task mutexes are dynamic (do change during the task's life time).
sub testDynamicMutexes {
	print "Testing case with dynamic mutexes...\n";
	my $tm = new TaskManager();
	my $taskA = createTask(name => "A");
	my $taskB = createTask(name => "B");
	my $taskC = createTask(name => "C");

	$tm->add($taskA);
	$tm->add($taskB);
	$tm->add($taskC);
	$tm->iterate();
	assertActiveTasks($tm, "A,B,C", "Active tasks: A,B,C");
	assertInactiveTasks($tm, "", "Inactive tasks: none");

	$taskA->setMutexes("1", "2");
	$tm->iterate();
	assertActiveTasks($tm, "A,B,C", "Active tasks after setting mutexes {1,2} for A: A,B,C");
	assertInactiveTasks($tm, "", "Inactive tasks: none");

	$taskC->setMutexes("2");
	$tm->iterate();
	assertActiveTasks($tm, "A,B", "Active tasks after setting mutex {2} for C: A,B");
	assertInactiveTasks($tm, "C", "Inactive tasks: C");

	$taskC->setMutexes();
	$tm->iterate();
	assertActiveTasks($tm, "A,B,C", "Active tasks after removing mutex from C: A,B,C");
	assertInactiveTasks($tm, "", "Inactive tasks: none");

	$taskB->setMutexes("3", "4");
	$tm->iterate();
	assertActiveTasks($tm, "A,B,C", "Active tasks after setting non-conflicting mutexes: A,B,C");
	assertInactiveTasks($tm, "", "Inactive tasks: none");

	$tm->add(createTask(name => "D", mutexes => ["1", "2", "3"], priority => Task::HIGH_PRIORITY));
	$tm->iterate();
	assertActiveTasks($tm, "C,D");
	assertInactiveTasks($tm, "A,B");

	$taskC->setMutexes('3');
	$taskC->setMutexes();
	$tm->iterate();
	assertActiveTasks($tm, "C,D");
	assertInactiveTasks($tm, "A,B");
}

# Test stopping of tasks that can stop immediately.
sub testImmediateStop {
	print "Testing immediate stopping of tasks...\n";
	my $tm = new TaskManager();
	my $taskA = createTask(name => "A");
	my $taskB = createTask(name => "B");
	my $taskC = createTask(name => "C");
	$tm->add($taskA);
	$tm->add($taskB);
	$tm->add($taskC);
	$tm->iterate();

	$taskB->stop();
	$tm->iterate();
	assertActiveTasks($tm, "A,C", "Stopping task B works.");
	assertInactiveTasks($tm, "");

	$taskA->stop();
	$taskC->stop();
	$tm->iterate();
	assertActiveTasks($tm, "", "Stopping task A and C works.");
	assertInactiveTasks($tm, "");


	$taskA = createTask(name => "A", mutexes => ['1', '2']);
	$taskB = createTask(name => "B", mutexes => ['2']);
	$tm->add($taskA);
	$tm->add($taskB);
	$tm->iterate();
	assertActiveTasks($tm, "A", "A is active.");
	assertInactiveTasks($tm, "B", "B is inactive.");

	$tm->stopAll();
	$tm->iterate();
	assertActiveTasks($tm, "", "Stopping active A and inactive B works.");
	assertInactiveTasks($tm, "");
}

# Test stopping of tasks that do not immediately stop.
sub testDeferredStop {
	print "Testing deferred stopping of tasks...\n";
	my $tm = new TaskManager();
	my $taskA = createTask(name => "A", mutexes => ['1', '2']);
	my $taskB = createTask(name => "B", mutexes => ['1'], autostop => 0);
	$tm->add($taskA);
	$tm->add($taskB);
	$tm->iterate();

	$tm->stopAll();
	$tm->iterate();
	assertActiveTasks($tm, "", "A is stopped.");
	assertInactiveTasks($tm, "B", "B is still inactive.");
	is($taskB->getStatus(), Task::INACTIVE, "B's status is INACTIVE.");

	$taskB->setStopped();
	$tm->iterate();
	assertActiveTasks($tm, "", "A and B are stopped.");
	assertInactiveTasks($tm, "");
	is($taskB->getStatus(), Task::STOPPED);
}

sub testMisc {
	my $tm = new TaskManager();
	my $taskA = createTask(name => "A");
	$tm->add($taskA);
	$tm->iterate();
	is($tm->activeMutexesString(), "", "No mutexes are active.");
	$taskA->setMutexes("movement");
	$tm->iterate();
	is($tm->activeMutexesString(), "movement (<- A)", "The 'movement' mutex is active.");
	$taskA->setMutexes();
	$tm->iterate();
	is($tm->activeMutexesString(), "", "No mutexes are active.");
	$tm->stopAll();
	$tm->iterate();
	is($tm->activeMutexesString(), "", "No mutexes are active.");

	$taskA = createTask(name => "A");
	my $taskB = createTask(name => "B");
}

##########################

sub createTask {
	return new Task::Testing(@_);
}

sub assertActiveTasks {
	my ($taskManager, $tasksString, $diagnostics) = @_;
	my @names;
	foreach my $task (@{$taskManager->{activeTasks}}) {
		push @names, $task->getName();
	}
	@names = sort @names;
	is(join(',', @names), $tasksString, $diagnostics);
}

sub assertInactiveTasks {
	my ($taskManager, $tasksString, $diagnostics) = @_;
	my @names;
	foreach my $task (@{$taskManager->{inactiveTasks}}) {
		push @names, $task->getName();
	}
	@names = sort @names;
	is(join(',', @names), $tasksString, $diagnostics);
}

1;