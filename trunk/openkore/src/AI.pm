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
	$ai_seq_args[$i]{mapChanged} = time if $i < @ai_seq_args;;
}

sub findAction {
	return undef if !defined $_[0];
	return binFind(\@ai_seq, $_[0]);
}

sub inQueue {
	my $action = shift;
	my $found = 0;

	foreach (split(/,/, $action)) {
		$found++ if defined binFind(\@ai_seq, $_);
	}
	return $found;
}

sub isIdle {
	return $ai_seq[0] eq "";
}

return 1;
