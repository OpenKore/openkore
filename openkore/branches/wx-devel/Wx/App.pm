#########################################################################
#  OpenKore - WxWidgets Interface
#  You need:
#  * WxPerl (the Perl bindings for WxWidgets) - http://wxperl.sourceforge.net/
#
#  More information about WxWidgets here: http://www.wxwidgets.org/
#
#  Copyright (c) 2004,2005,2006,2007 OpenKore development team
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
#  $Revision$
#  $Id$
#
#########################################################################
package Interface::Wx::App;
use strict;
use base qw(Wx::App);

use Wx ':everything';
use Wx::Event ':everything';

use Interface::Wx::MainFrame;

sub OnInit {
	my $self = shift;
	
	Wx::Image::AddHandler (new $_) for qw(
		Wx::XPMHandler Wx::BMPHandler Wx::PNGHandler Wx::GIFHandler Wx::JPEGHandler Wx::ICOHandler
	);
	
	($self->{mainFrame} = new Interface::Wx::MainFrame)->Show;
	
	return 1;
}

1;
