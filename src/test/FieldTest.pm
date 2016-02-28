# Unit test for Field
package FieldTest;
use strict;

use Test::More;
use List::MoreUtils qw(mesh);
use Field;
use FileParsers;
use Globals;
use Misc qw(compilePortals);
use Task::CalcMapRoute;

sub start {
	print "### Starting FieldTest\n";
	
	($Settings::fields_folder) = grep -d, qw(../../../../fieldpack/trunk/fields ../../fields);
	
	parseROLUT('resnametable.txt', \%mapAlias_lut, 1, ".gat");
	parseROLUT('maps.txt', \%maps_lut);
	parseROLUT('cities.txt', \%cities_lut);
	parsePortals('portals.txt', \%portals_lut);
	{ local *Misc::writePortalsLOS = sub {} and compilePortals }
	
	for (new Field(name => 'prontera')) {
		is($_->name, 'prontera', 'name of normal map');
		is($_->baseName, 'prontera', 'baseName of normal map');
		ok($_->isCity, 'isCity of normal map');
	}
	
	for (new Field(name => 'aretnorp')) {
		is($_->name, 'aretnorp', 'name of aliased map');
		is($_->baseName, 'aretnorp', 'baseName of aliased map');
		ok(!$_->isCity, 'isCity of aliased map');
	}
	
	ok(exists $portals_los{$_}, "There should be any Line of Sight from $_")
	for map { keys %{$_->{dest}} } values %portals_lut;
	
	my @routeKeys = qw(sourceMap sourceX sourceY map x y);
	
	for (
		'prontera 150 100 aretnorp 150 100',
		'aretnorp 150 100 prontera 150 100',
	) {
		my @route = split;
		ok(is_route_reachable(mesh @routeKeys, @route), "Route $_ should be reachable");
	}
	
	for (
		'prontera 150 100 unreachable 150 100',
		'unreachable 150 100 prontera 150 100',
	) {
		my @route = split;
		my $solution = is_route_reachable(mesh @routeKeys, @route);
		ok((!$solution or diag explain $solution), "Route $_ should be unreachable");
	}
}

sub is_route_reachable {
	for (new Task::CalcMapRoute(@_)) {
		$_->activate;
		$_->iterate until $_->getStatus == Task::DONE;
		return !$_->getError && $_->getRoute;
	}
};

1;
