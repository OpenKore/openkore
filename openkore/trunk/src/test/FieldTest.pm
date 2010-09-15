# Unit test for Field
package FieldTest;

use Test::More;
use Field;
use FileParsers;
use Globals;

sub start {
	print "### Starting FieldTest\n";
	
	($Settings::fields_folder) = grep -d, qw(../../../../fieldpack/trunk/fields ../../fields);
	
	parseROLUT('resnametable.txt', \%mapAlias_lut, 1, ".gat");
	parseROLUT('maps.txt', \%maps_lut);
	parseROLUT('cities.txt', \%cities_lut);
	
	my $normal = new Field(name => 'prontera');
	is($normal->name, 'prontera', 'name of normal map');
	is($normal->baseName, 'prontera', 'baseName of normal map');
	ok($normal->isCity, 'isCity of normal map');
	
	my $aliased = new Field(name => 'prt_copy');
	is($aliased->name, 'prt_copy', 'name of aliased map');
	is($aliased->baseName, 'prontera', 'baseName of aliased map');
	ok(!$aliased->isCity, 'isCity of aliased map');
}

1;
