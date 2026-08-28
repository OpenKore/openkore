# Regression tests for Task::Route move selection.
package TaskRouteTest;

use strict;
use Test::More;
use FindBin qw($RealBin);
use lib "$RealBin/lib";
use OpenKoreTestStubs;
use Globals qw(%config);
use Task::Route;

sub start {
	print "### Starting TaskRouteTest\n";
	testMoveSelectionResetDoesNotReenter();
	testRouteStepOverrideIsUsedAfterReset();
	testMoveSelectionResetIsBounded();
	testResetRouteCanPreserveMoveSelectionState();
}

sub testMoveSelectionResetDoesNotReenter {
	my $route = _newStubRoute();
	my $move_step_index = 10;

	for (1..4) {
		Task::Route::_trimMoveStepOrReset($route, 10, \$move_step_index, "test route drift");
	}

	is($move_step_index, 6, "route step is trimmed before recalculation");
	is($route->{reset_count}, 1, "route is recalculated after four trim attempts");
	is($route->{iterate_count}, 0, "move selection reset does not recursively re-enter iterate");
	is($route->{route_step_override}, 6, "trimmed route step is retained for the next route calculation");
	is($route->{move_selection_reset_count}, 1, "move selection reset count is tracked");
}

sub testRouteStepOverrideIsUsedAfterReset {
	my $route = _newStubRoute();
	$config{'test_route_step'} = 10;
	$route->{actor}{configPrefix} = 'test_';
	$route->{route_step_override} = 6;

	is(Task::Route::_getInitialStepIndex($route), 6, "retained route step overrides config after recalculation");

	delete $route->{route_step_override};
	is(Task::Route::_getInitialStepIndex($route), 10, "config route step is used when no override exists");
	delete $config{'test_route_step'};
}

sub testMoveSelectionResetIsBounded {
	my $route = _newStubRoute();
	my $max_resets = defined(&Task::Route::ROUTE_MAX_MOVE_SELECTION_RESETS)
		? Task::Route::ROUTE_MAX_MOVE_SELECTION_RESETS()
		: 5;

	for (1..($max_resets + 1)) {
		Task::Route::_resetRouteForMoveSelection($route, "test repeated route reset");
	}

	is($route->{reset_count}, $max_resets, "route recalculation stops at the consecutive reset limit");
	is($route->{iterate_count}, 0, "bounded reset handling never recursively calls iterate");
	is($route->{error}{code}, Task::Route::STUCK, "route reports STUCK after repeated invalid move selection");
}

sub testResetRouteCanPreserveMoveSelectionState {
	my $route = bless {
		solution => [{x => 1, y => 1}],
		stage => Task::Route::WALK_ROUTE_SOLUTION,
		route_step_override => 6,
		move_selection_reset_count => 2,
	}, 'Task::Route';

	Task::Route::resetRoute($route, preserveMoveSelectionState => 1);
	is($route->{stage}, Task::Route::CALCULATE_ROUTE, "resetRoute returns to route calculation");
	is($route->{route_step_override}, 6, "explicit preserve option keeps the trimmed route step");
	is($route->{move_selection_reset_count}, 2, "explicit preserve option keeps the reset counter");

	Task::Route::resetRoute($route);
	ok(!exists $route->{route_step_override}, "ordinary route reset clears the trimmed route step");
	is($route->{move_selection_reset_count}, 0, "ordinary route reset clears the reset counter");
}

sub _newStubRoute {
	return bless {
		actor => {configPrefix => 'test_'},
		move_selection_reset_count => 0,
		reset_count => 0,
		iterate_count => 0,
	}, 'TaskRouteTest::StubRoute';
}

package TaskRouteTest::StubRoute;

use strict;

sub resetRoute {
	my ($self, %args) = @_;
	$self->{reset_count}++;
}

sub iterate {
	$_[0]->{iterate_count}++;
}

sub setError {
	my ($self, $code, $message) = @_;
	$self->{error} = {code => $code, message => $message};
}

1;
