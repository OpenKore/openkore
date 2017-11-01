###########################################################
# Poseidon server
#
# This program is free software; you can redistribute it and/or 
# modify it under the terms of the GNU General Public License 
# as published by the Free Software Foundation; either version 2 
# of the License, or (at your option) any later version.
#
# Copyright (c) 2005-2006 OpenKore Development Team
#
# Credits:
# isieo - schematic of XKore 2 and other interesting ideas
# anonymous person - beta-testing
# kaliwanagan - original author
# illusionist - bRO support
###########################################################

package Poseidon::Config;

use strict;
require Exporter;  

our @ISA = qw(Exporter);  
our @EXPORT=qw(%config);

our %config = ();
 
# Function to Parse the Environment Variables
sub parse_config_file {
    my $File = shift;
	my ($Key, $Value);
	
	# Return early to avoid loading poseidon.txt (which might not exist at this point)
	if ($config{ragnarokserver_ip} ne "" && $config{ragnarokserver_port} ne "" && $config{queryserver_ip} ne "" && $config{debug} ne ""
		&& $config{queryserver_port} ne "" && $config{queryserver_ip} ne "" && $config{server_type} ne "") {
		print "\t[debug] Skipping config file\n" if $config{debug};
		return;
	}
	
    open (CONFIG, "<", "../../control/".$File) or open (CONFIG, "<", "./control/".$File) or open (CONFIG, "<", $File) or die "ERROR: Config file not found : ".$File;
	
    while (my $line = <CONFIG>) {
        chomp ($line);																		# Remove trailling \n
        $line =~ s/^\s*//;																	# Remove spaces at the start of the line
        $line =~ s/\s*$//;     																# Remove spaces at the end of the line
        if ($line !~ /^#/ && $line ne "") {  												# Ignore lines starting with # and blank lines
            ($Key, $Value) = split (/=/, $line);											# Split each line into name value pairs
			if ($config{$Key} ne "") {														# Skip key if we already know it from command line arguments
				print "\t[debug] Skipping ".$Key." key in config file\n" if $config{debug};	# Will only work with command line --debug=1 argument, unless debug key is moved to the top of poseidon.txt
				next;
			}
            $config{$Key} = $Value;															# Create a hash of the name value pairs
        }
    }
	
    close(CONFIG);
}

sub parseArguments {
	use Getopt::Long;
	GetOptions(
		'file=s',					\$config{file},
		'ragnarokserver_ip=s',		\$config{ragnarokserver_ip},
		'ragnarokserver_port=s',	\$config{ragnarokserver_port},
		'queryserver_ip=s',			\$config{queryserver_ip},
		'queryserver_port=s',		\$config{queryserver_port},
		'server_type=s',			\$config{server_type},
		'debug=s',					\$config{debug},
	);
	
	$config{file} = "poseidon.txt" if ($config{file} eq "");
}

1;