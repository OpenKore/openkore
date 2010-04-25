package VariableTest;

use Test::More;

sub setVar { $Macro::Data::varStack{$_[0]} = $_[1] }
sub getVar { $Macro::Data::varStack{$_[0]} }

sub start {
	setVar('test', 'test-value');
	is(getVar('test'), 'test-value', "setVar/getVar");
	
	is(Macro::Parser::subvars('$test'), 'test-value', "get variable (subvars)");
	is(Macro::Parser::parseCmd('$test'), 'test-value', "get variable (parseCmd)");
	
	is(Macro::Parser::parseCmd('foo $test'), 'foo test-value', "interpolation");
	is(Macro::Parser::parseCmd('$test bar'), 'test-value bar', "interpolation");
	is(Macro::Parser::parseCmd('foo $test bar'), 'foo test-value bar', "interpolation");
	setVar('foo', 'foo-value');
	setVar('bar', 'bar-value');
	is(Macro::Parser::parseCmd('$foo $test $bar'), 'foo-value test-value bar-value', "interpolation");
	is(Macro::Parser::parseCmd('$foo$test$bar'), 'foo-valuetest-valuebar-value', "interpolation");
	
	delete $Macro::Data::varStack{test};
	is(Macro::Parser::parseCmd('foo $test bar'), 'foo  bar', "undefined variable interpolation");
	
	setVar('a', '$b');
	setVar('b', 'b-value');
	is(Macro::Parser::parseCmd('$a'), '$b', "absense of recursive interpolation");
	
	setVar('nested1', 'nested2');
	setVar('#nested2', 'nested-value');
	is(Macro::Parser::parseCmd('${$nested1}'), 'nested-value', "get nested variable");
	
	setVar('#nested2', '${nested3}');
	setVar('#nested3', 'some-value');
	is(Macro::Parser::parseCmd('${$nested1}'), '${nested3}', "absense of recursive interpolation of nested variables");
	
	Macro::Parser::parseCmd(''); # update special variables
	like(getVar('.time'), qr/^\d+$/, '$.time');
	like(getVar('.datetime'), qr/^.+$/, '$.datetime');
	like(getVar('.hour'), qr/^\d{1,2}$/, '$.hour');
	like(getVar('.minute'), qr/^\d{1,2}$/, '$.minute');
	like(getVar('.second'), qr/^\d{1,2}$/, '$.second');
	# other special variables are unavailable without network
}

1;
