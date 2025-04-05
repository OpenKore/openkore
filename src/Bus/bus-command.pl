#!/usr/bin/env perl

use strict;
use warnings;

use FindBin qw($RealBin);
use lib "$RealBin/..";
use lib "$RealBin/../..";
use lib "$RealBin/../deps";

use Bus::Client;
use Getopt::Long;
use Time::HiRes qw( &sleep &time );

my $opt = get_options(
	{
		timeout => 10,
	}, {
		'group|g=s' => 'only the given GROUP will accept the command',
		'party|p=s' => 'only the given PARTY will accept the command',
		'timeout=s' => 'wait at most TIMEOUT seconds for the commands to be sent',
	}
);

my @commands = @ARGV;
usage() if $opt->{help} || !@commands;

my $bus = Bus::Client->new( userAgent => 'bus-command' );
$bus->iterate;

foreach my $command ( @commands ) {
	$bus->send( RUN_COMMAND => { command => $command, group => $opt->{group}, party => $opt->{party} } );
	$bus->iterate;
}

# Wait up to $opt->{timeout} seconds to send the command(s).
my $timeout = { time => time, timeout => $opt->{timeout} };
while ( !Utils::timeOut( $timeout ) ) {
	$bus->iterate;
	exit if !@{ $bus->{sendQueue} };
	sleep 0.01;
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
