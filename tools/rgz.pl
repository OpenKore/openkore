#!/usr/bin/env perl

use strict;
use warnings;

use Getopt::Long;
use IO::Handle;

my $opt = get_options(
	{},
	{
		'extract|x' => 'extract file(s)',
		'list|l'    => 'list the contents of the archive',
		'verbose|v' => 'be more verbose',
	}
);

my ( $archive, $file, $target ) = @ARGV;

usage() if !$archive;

my $dir = list( $archive );

if ( $opt->{list} ) {
	foreach ( map { $dir->{$_} } sort keys %$dir ) {
		printf "%s %9d %s\n", $_->{type}, $_->{size}, $_->{name};
	}
	exit;
}

if ( $opt->{extract} ) {
	if ( $file ) {
		die "File [$file] is not in archive [$archive].\n" if !$dir->{$file};
		$dir->{$file}->{target} = $target if $target;
		extract( $archive, [ $dir->{$file} ] );
	} else {
		extract( $archive, [ values %$dir ] );
	}
}

sub extract {
	my ( $archive, $files ) = @_;

	my $dirs = [ grep { $_->{type} eq 'd' } @$files ];
	foreach ( @$dirs ) {
		print "Creating directory [$_->{name}].\n" if $opt->{verbose};
		mkdir $_->{name};
	}

	@$files = grep { $_->{type} eq 'f' } @$files;
	@$files = sort { $a->{start} <=> $b->{start} } @$files;

	my $fp = openpipe( 'gzip', '-dc', $archive );
	die "Unable to open file [$archive]: $!\n" if !$fp;

	my $off = 0;
	my $buf = '';
	while ( !$fp->eof && @$files ) {
		my $file = shift @$files;
		for ( my $bytes = $file->{start} ; $bytes > 0 ; ) { $bytes -= read $fp, $buf = '', $bytes > 8192 ? 8192 : $bytes; }
		if ( open FP, '>', $file->{target} ) {
			print "Extracting $file->{name} into $file->{target}..." if $opt->{verbose};
			for ( my $bytes = $file->{size} ; $bytes > 0 ; ) { $bytes -= read $fp, $buf = '', $bytes > 8192 ? 8192 : $bytes;print FP $buf; }
			close FP;
			print " done.\n" if $opt->{verbose};
		} else {
			warn "Unable to write to target file [$file->{target}]: $!. Skipping.\n";
			for ( my $bytes = $file->{size} ; $bytes > 0 ; ) { $bytes -= read $fp, $buf = '', $bytes > 8192 ? 8192 : $bytes; }
		}
		$off = $file->{start} + $file->{size};
	}

	close $fp;
}

sub list {
	my ( $archive ) = @_;
	my $dir = {};
	my $fp = openpipe( 'gzip', '-dc', $archive );
	die "Unable to open file [$archive]: $!\n" if !$fp;

	my $off = 0;
	my $buf = '';
	while ( !$fp->eof ) {
		$off += read $fp, $buf, 2;
		my ( $type, $name_len ) = unpack 'AC', $buf;
		$off += read $fp, $buf = '', $name_len;
		my $name = lc unpack 'Z*', $buf;
		$dir->{$name} = { type => $type, name => $name, size => 0 };
		if ( $type eq 'f' ) {
			$off += read $fp, $buf = '', 4;
			$dir->{$name}->{start} = $off;
			$dir->{$name}->{size} = unpack 'V', $buf;
			for ( my $bytes = $dir->{$name}->{size} ; $bytes > 0 ; $bytes -= 8192 ) {
				$off += read $fp, $buf = '', $bytes >= 8192 ? 8192 : $bytes;
			}
		}
	}
	close $fp;

	delete $dir->{$_} foreach grep { $dir->{$_}->{type} eq 'e' } keys %$dir;

	foreach ( values %$dir ) {
		$_->{target} = $_->{name};
		$_->{target} =~ s/\\/\//gos;
		$_->{target} =~ s/\.\.//gos;
	}

	$dir;
}

sub openpipe {
	my ( @cmd ) = @_;

	my $pid = open( my $fp, '-|' );

	if ( !$pid ) {
		( $>, $) ) = ( $<, $( );
		exec( @cmd ) || die "Unable to exec program @cmd: $!\n";
	}

	binmode $fp;
	$fp;
}

sub get_options {
	my ( $opt_def, $opt_str ) = @_;

	# Add some default options.
	$opt_str = {
		'help|h' => 'this help',
		%$opt_str,
	};

	# Auto-convert underscored long names to dashed long names.
	foreach ( keys %$opt_str ) {
		my ( $name, $type ) = split '=';
		my @opts = split /\|/, $name;
		my ( $underscored ) = grep {/_/} @opts;
		my ( $dashed )      = grep {/-/} @opts;
		if ( $underscored && !$dashed ) {
			$dashed = $underscored;
			$dashed =~ s/_/-/g;
			splice @opts, ( length( $opts[-1] ) == 1 ? $#opts : @opts ), 0, $dashed;
			my $key = join '|', @opts;
			$key .= "=$type" if $type;
			$opt_str->{$key} = $opt_str->{$_};
			delete $opt_str->{$_};
		}
	}

	my $opt = {%$opt_def};
	my $success = GetOptions( $opt, keys %$opt_str );
	usage( $opt_def, $opt_str ) if $opt->{help} || !$success;

	$opt;
}

sub usage {
	my ( $opt_def, $opt_str ) = @_;
	my $maxlen = 0;
	my $opt    = {};
	foreach ( keys %$opt_str ) {
		my ( $name, $type ) = split '=';
		my ( $var ) = split /\|/, $name;
		my ( $long ) = reverse grep { length $_ != 1 } split /\|/, $name;
		my ( $short ) = grep { length $_ == 1 } split /\|/, $name;
		$maxlen = length $long if $long && $maxlen < length $long;
		$opt->{ $long || $short || '' } = {
			short   => $short,
			long    => $long,
			desc    => $opt_str->{$_},
			default => $opt_def->{$var}
		};
	}
	print "Usage: $0 [options]\n";
	foreach ( map { $opt->{$_} } sort keys %$opt ) {
		printf "  %2s %-*s  %s%s\n",    #
			$_->{short} ? "-$_->{short}" : '', $maxlen + 2, $_->{long} ? "--$_->{long}" : '', $_->{desc}, $_->{default} ? " (default: $_->{default})" : "";
	}
	exit;
}
