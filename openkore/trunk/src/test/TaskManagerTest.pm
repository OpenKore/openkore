# A unit test for TaskManager.
package TaskManagerTest;

use strict;
use Test::More;
use Task;
use TaskManager;

sub start {
	print "### Starting TaskManagerTest\n";
	testStaticMutexes();
	testDynamicMutexes();
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

	$tm = new TaskManager();
	$tm->add($taskA = createTask(name => "A", mutexes => ["1", "2"]));
	$tm->add($taskB = createTask(name => "B"));
	$tm->add($taskC = createTask(name => "C"));
	$tm->reschedule();
	assertActiveTasks($tm, "A,B,C", "Active tasks: A,B,C");
	assertInactiveTasks($tm, "", "Inactive tasks: none");

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

	$taskC->markDone();
	$tm->iterate();
	$tm->reschedule();
	assertActiveTasks($tm, "B", "Active tasks: B");
	assertInactiveTasks($tm, "A", "Inactive tasks: A");

	$tm->add(createTask(name => "D", mutexes => ["3"]));
	$tm->iterate();
	assertActiveTasks($tm, "B,D", "Active tasks after setting non-conflicting mutexes: B,D");
	assertInactiveTasks($tm, "A", "Inactive tasks: A");
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
}

sub createTask {
	return new TaskManagerTest::Task(@_);
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


package TaskManagerTest::Task;

use base qw(Task);

sub new {
	my $class = shift;
	return $class->SUPER::new(@_);
}

sub iterate {
	if ($_[0]->{done}) {
		$_[0]->setDone();
	}
}

sub markDone {
	$_[0]->{done} = 1;
}

1;