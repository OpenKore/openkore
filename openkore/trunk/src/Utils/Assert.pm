#########################################################################
#  OpenKore - Assertion functions
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
package Utils::Assert;

use strict;
use Carp::Assert;
use Exporter;
use UNIVERSAL qw(isa);
use Scalar::Util qw(blessed);
use base qw(Exporter);

our @EXPORT = qw(assertClass);

##
# assertClass(object, expectedClassName)
#
# Assert that an object is of the expected class.
sub assertClass {
	my ($object, $expectedClassName) = @_;
	my $objectName = defined($object) ? $object : "(undefined)";
	assert(isa($object, $expectedClassName), "'$objectName' must be of class '$expectedClassName'");
}

1;
