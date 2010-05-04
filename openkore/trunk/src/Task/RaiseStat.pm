#########################################################################
#  OpenKore - AutoRaise task
#  Copyright (c) 2009 OpenKore Team
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#########################################################################
##
# MODULE DESCRIPTION: AutoRaise task
#
# This task is specialized in:
# Auto Stat raise

package Task::RaiseStat;

use strict;

use base 'Task::Raise';

use Carp::Assert;
use Modules 'register';
use Globals qw(%config $net $char $messageSender);
use Log qw(message debug error);
use Translation qw(T TF);

sub new {
	my $class = shift;
	my %args = @_;
	my $self = $class->SUPER::new(@_);
	
	Scalar::Util::weaken(my $weak = $self);
	push @{$self->{hookHandles}}, Plugins::addHooks(
		['packet/stats_added', sub { $weak->check }],
		['packet/stats_info', sub { $weak->check }],
		['packet/stat_info', sub { $weak->check if $_[1]{type} == 9 }], # 9 is points_free
	);

	return $self;
}

sub initQueue {
	return unless $config{statsAddAuto};
	
	my @queue;
	
	for (split /\s*,+\s*/, lc $config{statsAddAuto_list}) {
		if (my ($value, $stat) = /^(\d+)\s+(str|vit|dex|int|luk|agi)$/) {
			push @queue, {stat => $stat, value => $value};
		} else {
			error TF("Unknown stat '%s'; disabling statsAddAuto\n", $_);
			$config{statsAddAuto} = 0;
			return;
		}
	}
	
	@queue
}

sub canRaise {
	my ($self, $item) = @_;
	
	$char && $char->{points_free} && $char->{points_free} >= $char->{"points_$item->{stat}"}
}

sub raise {
	my ($self, $item) = @_;
	
	my $amount = $char->{$item->{stat}};
	$amount += $char->{"$item->{stat}_bonus"} unless $config{statsAddAuto_dontUseBonus};
	
	return unless $amount < $item->{value} and $char->{$item->{stat}} < 99 || $config{statsAdd_over_99};
	
	my ($expectedValue, $expectedPoints, $expectedBase) = (
		$char->{$item->{stat}}+1,
		$char->{points_free} - $char->{"points_$item->{stat}"},
		$char->{lv},
	);
	
	message TF("Auto-adding stat %s to %s\n", $item->{stat}, $expectedValue);
	# TODO: move these IDs to Network
	$messageSender->sendAddStatusPoint({
		str => 0x0d,
		agi => 0x0e,
		vit => 0x0f,
		int => 0x10,
		dex => 0x11,
		luk => 0x12,
	}->{$item->{stat}});
	
	sub {
		$char
		and $char->{$item->{stat}} == $expectedValue
		and $char->{points_free} == $expectedPoints || $char->{lv} != $expectedBase
	}
}

1;
