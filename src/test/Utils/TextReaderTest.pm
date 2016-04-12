package Utils::TextReaderTest;

use strict;
use warnings;

use Test::More;
use Utils::TextReader;

sub start {
	my $reader = Utils::TextReader->new( 'data/parent.txt' );
	subtest '!include support' => sub {
		is( $reader->readLine, "parent A\n" );
		is( $reader->readLine, "child\n" );
		is( $reader->readLine, "parent B\n" );
		is( $reader->readLine, "a\n" );
		is( $reader->readLine, "child\n" );
		is( $reader->readLine, "parent C\n" );
		is( $reader->readLine, undef );

		is( $reader->eof, 1 );
	};

	subtest '!include_create_if_missing support' => sub {
		my $reader = Utils::TextReader->new( 'data/create_if_missing.txt' );

		# Make sure the referenced child doesn't exist.
		unlink 'data/create_if_missing_child.txt';
		ok( !-e 'data/create_if_missing_child.txt' );

		# Processing the file should create the referenced child.
		$reader->readLine while !$reader->eof;
		ok( -e 'data/create_if_missing_child.txt' );
	};
}

1;
