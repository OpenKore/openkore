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
sub parse_config_file 
{
    my ($config_line, $Name, $Value, $Config);
    my ($File, $Config) = @_;
    open (CONFIG, "$File") or die "ERROR: Config file not found : $File";
    while (<CONFIG>) {
        $config_line=$_;
        chop ($config_line);											# Remove trailling \n
        $config_line =~ s/^\s*//;										# Remove spaces at the start of the line
        $config_line =~ s/\s*$//;     									# Remove spaces at the end of the line
        if ( ($config_line !~ /^#/) && ($config_line ne "") ){  		# Ignore lines starting with # and blank lines
            ($Name, $Value) = split (/=/, $config_line);        		# Split each line into name value pairs
            $$Config{$Name} = $Value;                           		# Create a hash of the name value pairs
        }
    }
    close(CONFIG);
}

1;