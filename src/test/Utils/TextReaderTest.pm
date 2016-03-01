package Utils::TextReaderTest;

use strict;
use warnings;

use Test::More;
use Utils::TextReader;

sub start {
    my $reader = Utils::TextReader->new( 'data/parent.txt' );
    subtest '!include support' => sub {
		is($reader->readLine, "parent A\n");
		is($reader->readLine, "child\n");
		is($reader->readLine, "parent B\n");
		is($reader->readLine, "a\n");
		is($reader->readLine, "child\n");
		is($reader->readLine, "parent C\n");
		is($reader->readLine, undef);
		is($reader->eof, 1);
    };
}

1;
