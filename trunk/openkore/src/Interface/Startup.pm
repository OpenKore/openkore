#########################################################################
#  OpenKore - Startup Interface
#
#  Copyright (c) 2004 OpenKore development team 
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#
#  $Revision$
#  $Id$
#
#########################################################################
##
# MODULE DESCRIPTION: Startup Interface
#
# Loaded before command line options and configuration files have been loaded,
# this allowed basic output prior to the main interface being known.

package Interface::Startup;

use strict;
use warnings;

use base qw/Interface/;

my $output_limit = 50; #should be more than enough for any start up.

sub new {
	my $class = shift;
	return bless { output_history => [] }, $class;
}

sub writeOutput {
	my $self = shift;
	my $type = shift;
	my $message = shift;
	my $domain = shift;

	print $message;
	$self->addOutHist($type, $message, $domain);
	STDOUT->flush;
}

sub addOutHist {
	my $self = shift;
	my $oh = $self->{output_history};
	push @$oh, [@_];
	splice(@$oh, 0, @$oh - $output_limit) if @$oh > $output_limit;
}

sub getOutHist {
	my $self = shift;
	return @{ $self->{output_history} };
}

sub getInHist {
	return ();
}

sub getInQue {
	return ();
}
1 #end of module
