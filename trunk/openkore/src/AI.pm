# Helper functions for managing @ai_seq.
#
# Eventually, @ai_seq should never be referenced directly, and then it can be
# moved into this package.
#
# TODO:
# Move ai_setMapChanged() and ai_setSuspend() to this module.

package AI;

use strict;
use Globals;
use Utils;

sub action {
	my $i = (defined $_[0] ? $_[0] : 0);
	return $ai_seq[$i];
}

sub args {
	my $i = (defined $_[0] ? $_[0] : 0);
	return \%{$ai_seq_args[$i]};
}

sub v {
	return \%ai_v;
}

sub dequeue {
	shift @ai_seq;
	shift @ai_seq_args;
}

sub queue {
	unshift @ai_seq, shift;
	my $args = shift;
	unshift @ai_seq_args, ((defined $args) ? $args : {});
}

sub clear {
	undef @ai_seq;
	undef @ai_seq_args;
}

# TODO: This should be integrated with AI::clear()
sub remove {
	return if !defined $_[0];
	my @arr = split /,/, $_[0];
	foreach (@arr) {
		s/\s+//g;
		while (1) {
			my $index = binFind(\@ai_seq, $_);
			last if !defined $index;
			
			if ($ai_seq_args[$index]{destroyFunction}) {
				&{$ai_seq_args[$index]{destroyFunction}}(\%{$ai_seq_args[$index]});
			}
			binRemoveAndShiftByIndex(\@ai_seq, $index);
			binRemoveAndShiftByIndex(\@ai_seq_args, $index);
		}
	}
}

sub suspend {
	my $i = (defined $_[0] ? $_[0] : 0);
	$ai_seq_args[$i]{suspended} = time if $i < @ai_seq_args;
}

sub mapChanged {
	my $i = (defined $_[0] ? $_[0] : 0);
	$ai_seq_args[$i]{mapChanged} = time if $i < @ai_seq_args;
}

sub findAction {
	return undef if !defined $_[0];
	return binFind(\@ai_seq, $_[0]);
}

sub inQueue {
	my $sequences = join("|", @_);
	my $actions = join("/", @ai_seq);
	return 1 if $actions =~ /$sequences/;
	return 0;
}

sub isIdle {
	return $ai_seq[0] eq "";
}

# TODO: move references of ai_skillUse in functions.pl here
sub skillUse {
	my ($ID, $lv, $maxCastTime, $minCastTime, $target, $y) = @_;
	my %args;
	$args{ai_skill_use_giveup}{time} = time;
	$args{ai_skill_use_giveup}{timeout} = $timeout{ai_skill_use_giveup}{timeout};
	$args{skill_use_id} = $ID;
	$args{skill_use_lv} = $lv;
	$args{skill_use_maxCastTime}{time} = time;
	$args{skill_use_maxCastTime}{timeout} = $maxCastTime;
	$args{skill_use_minCastTime}{time} = time;
	$args{skill_use_minCastTime}{timeout} = $minCastTime;
	if ($y eq "") {
		$args{skill_use_target} = $target;
	} else {
		$args{skill_use_target_x} = $target;
		$args{skill_use_target_y} = $y;
	}
	queue("skill_use",\%args);
}

return 1;
