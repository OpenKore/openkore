#!/usr/bin/perl -w

use utf8;
use strict;
use FindBin qw($RealBin);
use lib "$RealBin/..";
use Poseidon::Config;

Poseidon::Config::parse_config_file ("poseidon.txt", \%config);
	
my $ragna_ip = $config{ragnarokserver_ip};
my $first_ragna_port = $config{ragnarokserver_first_port};
my $number_of_clients = $config{number_of_clients};

open OUT, ">:utf8", "poseidon.xml" or die $!;

print OUT '<?xml version="1.0" encoding="euc-kr" ?>

<clientinfo>
	<servicetype>brazil</servicetype>
	<servertype>primary</servertype>
	<extendedslot></extendedslot>';

foreach my $server_index (0..($number_of_clients-1)) {
	my $current_ragna_port = ($first_ragna_port + $server_index);
	
	print OUT '
	<connection>
		<display>Poseidon ['.$current_ragna_port.']</display>
		<desc>None</desc>
		<address>'.$ragna_ip.'</address>
		<port>'.$current_ragna_port.'</port>
		<version>1</version>
	</connection>';
}

print OUT '
</clientinfo>';

close(OUT);

print "Finished !\n";

system("pause");