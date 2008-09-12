#########################################################################
#  OpenKore - Deal object
#  Copyright (c) 2005 OpenKore Team
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#
#  $Revision$
#  $Id$
#
#########################################################################
##
# MODULE DESCRIPTION: Deal object
#
# The complete Deal API is implemented here but the logic is in the AI function
#
#
# States:
# request
# incomingDeal
# ready
# finalized
# completed

package Deal;

use strict;
use Globals;
use Utils;
use Log qw(message error warning debug);
use Time::HiRes qw(time);
use Network::Send ();


sub new {
	my $class = shift;
	my %self;
	bless \%self, $class;
	return \%self;
}

###################
### Class Methods
###################

sub dealPlayer {
	my ($other) = @_;
	my $self = new Deal;
	$self->{other} = $other;
	$messageSender->sendDeal($other->{ID});
	$self->{state} = 'request';
	$ai_v{temp}{deal} = $self;
}

sub incomingDeal {
	my ($other) = @_;
	my $self = new Deal;
	$self->{other} = $other;
	$ai_v{temp}{deal} = $self;
	$self->{state} = 'incomingDeal';
	if ($config{dealAuto}) {
		$self->accept();
		$self->{state} = 'accepted';
	}
}

###################
### Public Methods
###################

sub AI {
	# Maybe add the deal logic in here
	# and only call AI if $ai_v{temp}{deal}
	# is set
}

sub add {
	my ($self,$item,$ammount) = @_;
	$messageSender->sendDealAddItem($item->{index},$ammount);
}

sub accept {
	my ($self,$args) = @_;
	$messageSender->sendDealAccept();
}

sub cancel {
	my ($self,$args) = @_;	
	$messageSender->sendDealCancel();
}

sub finalize {
	my ($self,$args) = @_;
	$self->{state} = 'engaged';
	return 0;
}

sub trade {
	my ($self,$args) = @_;
}

sub zeny {
	my ($self,$args) = @_;
}

sub list {
	my ($self,$args) = @_;
}
