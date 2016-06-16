package Utils::TextReaderTest;

use strict;
use warnings;

use Test::More;
use Utils::TextReader;

sub start {
	subtest '!include support' => sub {
		my $reader = Utils::TextReader->new( 'data/parent.txt' );

		is( $reader->readLine, "parent A\n" );
		is( $reader->readLine, "child\n" );
		is( $reader->readLine, "parent B\n" );
		is( $reader->readLine, "a\n" );
		is( $reader->readLine, "child\n" );
		is( $reader->readLine, "parent C\n" );
		is( $reader->readLine, undef );

		is( $reader->eof, 1 );
	};

	subtest 'hide_includes=0' => sub {
		my $reader = Utils::TextReader->new( 'data/parent.txt', { hide_includes => 0 } );

		is( $reader->readLine, "parent A\n" );
		is( $reader->readLine, "!include child.txt\n" );
		is( $reader->readLine, "child\n" );
		is( $reader->readLine, "parent B\n" );
		is( $reader->readLine, "!include child/a.txt\n" );
		is( $reader->readLine, "a\n" );
		is( $reader->readLine, "!include ../child.txt\n" );
		is( $reader->readLine, "child\n" );
		is( $reader->readLine, "parent C\n" );
		is( $reader->readLine, undef );

		is( $reader->eof, 1 );
	};

	subtest 'process_includes=0' => sub {
		my $reader = Utils::TextReader->new( 'data/parent.txt', { process_includes => 0 } );

		is( $reader->readLine, "parent A\n" );
		is( $reader->readLine, "!include child.txt\n" );
		is( $reader->readLine, "parent B\n" );
		is( $reader->readLine, "!include child/a.txt\n" );
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
