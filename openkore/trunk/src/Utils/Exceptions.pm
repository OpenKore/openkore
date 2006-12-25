#########################################################################
#  OpenKore - Exception utility functions and common exception objects
#
#  Copryight (c) 2006 OpenKore Development Team
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#########################################################################
##
# MODULE DESCRIPTION: Exception utility functions and common exception objects.
#
# This module provides some exception utility functions, to be used in combination
# with <a href="http://cpan.uwinnipeg.ca/htdocs/Exception-Class/Exception/Class.html">Exeption::Class</a>.
#
# It also defines the following commonly-used exception objects:
# `l
# - IOException - Input/output exception occured.
# - FileNotFoundException - A file is not found.
# - UTF8MalformedException - Invalid UTF-8 data encountered.
# `l`
package Utils::Exceptions;

use strict;
use Exporter;
use base qw(Exporter);
use Scalar::Util;

use Exception::Class (
	'IOException',
	'ArgumentException',
	'FileNotFoundException'  => { isa => 'IOException' },
	'UTF8MalformedException' => { fields => 'line' }
);

our @EXPORT = qw(caught);

##
# Object caught(class1, [class2, class3, ...])
# classN: The class name of an exception object.
#
# Checks whether the currently caught exception ($@) is one of the types
# specified in the parameters. Returns $@ if it is, undef otherwise. This
# function is allows you to write in try-catch-style syntax.
#
# This symbol is exported by default.
#
# Example:
# eval {
#     SomeException->throw(error => "foo");
# };
# if (my $e = caught("SomeException")) {
#     print "SomeException caught: " . $e->error . "\n";
# } elsif (my $e = caught("OtherException")) {
#     print "OtherException caught: " . $e->error . "\n";
# } elsif (my $e = caught("YetAnotherException1", "YetAnotherException2")) {
#     print "Caught YetAnotherException1 or YetAnotherException1.\n";
# } elsif ($@) {
#     # Rethrow exception.
#     die $@;
# }
sub caught {
	my $e = $@;
	foreach my $class (@_) {
		if (UNIVERSAL::isa($e, $class)) {
			return $e;
		}
	}
	return undef;
}

1;
