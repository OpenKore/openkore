#########################################################################
#  OpenKore - Interface::Console::Other
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
# MODULE DESCRIPTION: 
#
# Support for asyncronous input on non MS Windows computers

package Interface::Console::Other;

use strict;
use warnings;

use IO::Select;

use Settings;

our $select;
our $enabled;

our %fgcolors;
our %bgcolors;

sub start {
	return undef if ($enabled);
	$select = IO::Select->new(\*STDIN);
	$enabled = 1;
}

sub stop {
	color('reset');
	undef $select;
	undef $enabled;
}

sub getInput {
	my $class = shift;
	my $timeout = shift;
	my $msg;
	if ($timeout < 0) {
		$msg = <STDIN> until defined($msg) && $msg ne "\n";
	} elsif ($timeout > 0) {
		
	} else {
		if ($select->can_read(0.00)) {
			$msg = <STDIN>;
		}
	}
	$msg =~ y/\r\n//d if defined $msg;
	undef $msg if (defined $msg && $msg eq "");
	return $msg;
}

sub writeOutput {
	my $class = shift;
	my $type = shift;
	my $message = shift;
	my $domain = shift;
	
	setColor($type, $domain);

	print $message;

	color('reset');
	STDOUT->flush;
}

sub setColor {
	return if (!$consoleColors{''}{'useColors'});
	my ($type, $domain) = @_;
	my $color = $consoleColors{$type}{$domain};
	$color = $consoleColors{$type}{'default'} if (!defined $color);
	color($color) if (defined $color);
}

sub color {
	return if ($config{'XKore'}); # Don't print colors in X-Kore mode; this is a temporary hack!
	my $color = shift;

	$color =~ s/\/(.*)//;
	my $bgcolor = $1 || "default";

	print $fgcolors{$color} if defined($fgcolors{$color});
	print $bgcolors{$bgcolor} if defined($bgcolors{$bgcolor});
}

END {
	color('reset');
}


$fgcolors{"reset"} = "\e[0m";
$fgcolors{"default"} = "\e[0m";

$fgcolors{"black"} = "\e[1;30m";

$fgcolors{"red"} = "\e[1;31m";
$fgcolors{"lightred"} = "\e[1;31m";

$fgcolors{"brown"} = "\e[0;31m";
$fgcolors{"darkred"} = "\e[0;31m";

$fgcolors{"green"} = "\e[1;32m";
$fgcolors{"lightgreen"} = "\e[1;32m";

$fgcolors{"darkgreen"} = "\e[0;32m";

$fgcolors{"yellow"} = "\e[1;33m";

$fgcolors{"blue"} = "\e[0;34m";

$fgcolors{"lightblue"} = "\e[1;34m";

$fgcolors{"magenta"} = "\e[0;35m";

$fgcolors{"lightmagenta"} = "\e[1;35m";

$fgcolors{"cyan"} = "\e[1;36m";
$fgcolors{"lightcyan"} = "\e[1;36m";

$fgcolors{"darkcyan"} = "\e[0;36m";

$fgcolors{"white"} = "\e[1;37m";

$fgcolors{"gray"} = "\e[0;37m";
$fgcolors{"grey"} = "\e[0;37m";


$bgcolors{"black"} = "\e[40m";
$bgcolors{""} = "\e[40m";
$bgcolors{"default"} = "\e[40m";

$bgcolors{"red"} = "\e[41m";
$bgcolors{"lightred"} = "\e[41m";
$bgcolors{"brown"} = "\e[41m";
$bgcolors{"darkred"} = "\e[41m";

$bgcolors{"green"} = "\e[42m";
$bgcolors{"lightgreen"} = "\e[42m";
$bgcolors{"darkgreen"} = "\e[42m";

$bgcolors{"yellow"} = "\e[43m";

$bgcolors{"blue"} = "\e[44m";
$bgcolors{"lightblue"} = "\e[44m";

$bgcolors{"magenta"} = "\e[45m";
$bgcolors{"lightmagenta"} = "\e[45m";

$bgcolors{"cyan"} = "\e[46m";
$bgcolors{"lightcyan"} = "\e[46m";
$bgcolors{"darkcyan"} = "\e[46m";

$bgcolors{"white"} = "\e[47m";
$bgcolors{"gray"} = "\e[47m";
$bgcolors{"grey"} = "\e[47m";

1 #end of module
