#########################################################################
#  OpenKore - Networking subsystem
#  This module contains functions for sending packets to the server.
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#########################################################################
package Network::Server;


# Make all References Strict
use strict;

# MultiThreading Support
use threads qw(yield);
use threads::shared;
use Thread::Queue::Any;

# Others (Perl Related)
use warnings;
no warnings 'redefine';
use FindBin qw($RealBin);
use Time::HiRes qw(time);
use Scalar::Util qw(reftype refaddr blessed); 

# Others (Kore related)
use Modules 'register';
use Globals qw($quit);
# use Utils::Set;
# use Utils::CallbackList;

####################################
### CATEGORY: Constructor
###################################


##
# Network::Server->new()
#
# Create a new Network main object.
#
sub new {
	my $class = shift;
	my %args = @_;
	my $self = {};
	bless $self, $class;

	$self->{send_queue} = Thread::Queue->new();
	$self->{is_co

	# Warning!!!!
	# Do not use Internal Varuables in other packages!

	return $self;
}

####################################
### CATEGORY: Destructor
###################################

sub DESTROY {
	my ($self) = @_;
	$self->SUPER::DESTROY if $self->can("SUPER::DESTROY");
}

####################################
### CATEGORY: Public
####################################


##
# void $Network__Server->mainLoop()
#
# Enter the Network Server main loop.
sub mainLoop {
	my $self = shift;
	while (!$quit) {
		{ # Just make Unlock quicker.
			lock ($self) if (is_shared($self));
			
		}
		yield();
	}
}


 
