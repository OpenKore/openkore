# Unit test for Task::Chained
package TaskChainedTest;

use strict;
use Test::More;
use Task::Chained;
use Task::Testing;

sub start {
	print "### Starting TaskChainedTest\n";
	testBasicUsage();
	testMutexChanges();
}

sub testBasicUsage {
	print "Testing basic usage...\n";
	my $taskA = new Task::Testing(name => 'A', mutexes => ['1', '2']);
	my $taskB = new Task::Testing(name => 'B', mutexes => []);
	my $taskC = new Task::Testing(name => 'C', mutexes => ['2', '3']);

	my $chain = new Task::Chained(tasks => [$taskA, $taskB, $taskC]);
	$chain->activate();
	ok($chain->getSubtask() == $taskA, "Current subtask is A.");
	is_deeply($chain->getMutexes(), ['1', '2'], "Chain has same mutexes as task A.");
	ok($chain->getStatus == Task::RUNNING, "Chain is running.");
	$chain->iterate();

	ok($chain->getSubtask() == $taskA, "Current subtask is still A.");
	is_deeply($chain->getMutexes(), ['1', '2'], "Chain still has same mutexes as task A.");
	ok($chain->getStatus == Task::RUNNING, "Chain is running.");
	$taskA->markDone();
	$chain->iterate();

	ok($chain->getSubtask() == $taskB, "Current subtask is B.");
	is_deeply($chain->getMutexes(), [], "Chain has same mutexes as task B.");
	ok($chain->getStatus == Task::RUNNING, "Chain is running.");
	$taskB->markDone();
	$chain->iterate();

	ok($chain->getSubtask() == $taskC, "Current subtask is C.");
	is_deeply($chain->getMutexes(), ['2', '3'], "Chain has same mutexes as task C.");
	ok($chain->getStatus == Task::RUNNING, "Chain is running.");
	$chain->iterate();

	ok($chain->getSubtask() == $taskC, "Current subtask is still C.");
	is_deeply($chain->getMutexes(), ['2', '3'], "Chain still has same mutexes as task C.");
	ok($chain->getStatus == Task::RUNNING, "Chain is running.");
	$taskC->markDone();
	$chain->iterate();

	ok(!defined($chain->getSubtask()), "No subtask active.");
	ok($chain->getStatus() == Task::DONE, "Chain is done.");
}

sub testMutexChanges {
	print "Testing dynamic mutex changes...\n";
	my $taskA = new Task::Testing(name => 'A', mutexes => ['1', '2']);
	my $taskB = new Task::Testing(name => 'B', mutexes => []);
	my $taskC = new Task::Testing(name => 'C', mutexes => ['2', '3']);
	my $chain = new Task::Chained(tasks => [$taskA, $taskB, $taskC]);

	$chain->activate();
	$taskA->setMutexes('Foo', 'Bar');
	is_deeply($chain->getMutexes(), ['Foo', 'Bar']);
	$taskA->setMutexes();
	is_deeply($chain->getMutexes(), []);
	$taskA->setMutexes('Test');
	is_deeply($chain->getMutexes(), ['Test']);

	$taskB->setMutexes('hello');
	$taskA->markDone();
	$chain->iterate();
	ok($chain->getSubtask() == $taskB, "Current subtask is B.");
	is_deeply($chain->getMutexes(), ['hello']);

	$taskB->markDone();
	$chain->iterate();
	ok($chain->getSubtask() == $taskC, "Current subtask is C.");
	is_deeply($chain->getMutexes(), ['2', '3']);
	$taskC->setMutexes('2', '3', '4');
	is_deeply($chain->getMutexes(), ['2', '3', '4']);

	$taskC->markDone();
	$chain->iterate();
	ok(!defined($chain->getSubtask()), "No subtask active.");
}

1;