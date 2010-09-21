package AutomacroTest;

use Test::More;

sub setVar { $Macro::Data::varStack{$_[0]} = $_[1] }
sub getVar { $Macro::Data::varStack{$_[0]} }

sub start {
	subtest "location" => sub {
		for (
			[
				qw(prontera 10 10),
				'prontera',
				'not alberta',
				'prontera 10 10',
				'not prontera 5 5',
				'not alberta 10 10',
				'prontera, alberta',
				'prontera 10 10, alberta',
				'not prontera 5 5, alberta',
				'not prontera, not alberta',
				'not prontera 5 5 15 15',
				'prontera 5 15 15 5',
				'not prontera 95 105 105 95',
				'not alberta 5 15 15 5',
			],
		) {
			$Globals::field = AutomacroTest::Field->new(shift @$_);
			$Globals::char = {pos_to => {x => shift @$_, y => shift @$_}};
			ok(Macro::Automacro::checkLoc($_), $_) for @$_
		}
		done_testing
	};
}

package AutomacroTest::Field;

sub new { bless \$_[1] }
sub name { ${$_[0]} }

1;
