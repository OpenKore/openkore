#########################################################################
#  OpenKore - Generic utility functions
#
#  Copyright (c) 2006 OpenKore Development Team
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#########################################################################
##
# MODULE DESCRIPTION: Exception object.
#
# Exception objects are thrown when unusual conditions occured,
# that a reasonable application can handle.

package Exception;

use strict;
use Scalar::Util;


### CATEGORY: Class Exception


use overload '""' => sub {
	return "Exception " . Scalar::Util::blessed($_[0]) . " thrown:\n" .
		"   Message: " . $_[0]->getMessage() . "\n" .
		"   Code   : " . $_[0]->getErrorCode() . "\n";
};


##
# Exception Exception->new(String message = undef, int errorCode = 0)
# message: The error message for this exception.
# errorCode: The error code for this exception.
#
# Create a new Exception object.
sub new {
	my ($class, $message, $errorCode) = @_;
	my %self;
	$self{message} = $message;
	$self{errorCode} = defined($errorCode) ? $errorCode : 0;
	return bless \%self, $class;
}

##
# String $Exception->getMessage()
#
# Get the error message for this exception.
sub getMessage {
	return $_[0]->{message};
}

##
# int $Exception->errorCode()
#
# Get the error code for this exception.
sub getErrorCode {
	return $_[0]->{errorCode};
}


1;
