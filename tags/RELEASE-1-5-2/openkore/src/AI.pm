# Helper functions for managing @ai_seq.
#
# Eventually, @ai_seq should never be referenced directly, and then it can be
# moved into this package.

package AI;

use strict;
use Globals qw(@ai_seq @ai_seq_args);
use Utils qw(binFind);

sub action {
	my $i = (defined $_[0] ? $_[0] : 0);
	return $ai_seq[$i];
}

sub args {
	my $i = (defined $_[0] ? $_[0] : 0);
	return \%{$ai_seq_args[$i]};
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
	if (@_) {
		my $changed;
		for (my $i = 0; $i < @ai_seq; $i++) {
			if (defined binFind(\@_, $ai_seq[$i])) {
				delete $ai_seq[$i];
				delete $ai_seq_args[$i];
				$changed = 1;
			}
		}

		if ($changed) {
			my (@new_seq, @new_args);
			for (my $i = 0; $i < @ai_seq; $i++) {
				if (defined $ai_seq[$i]) {
					push @new_seq, $ai_seq[$i];
					push @new_args, $ai_seq_args[$i];
				}
			}
			@ai_seq = @new_seq;
			@ai_seq_args = @new_args;
		}

	} else {
		undef @ai_seq;
		undef @ai_seq_args;
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
	return binFind(\@ai_seq, $_[0]);
}

sub inQueue {
	foreach (@_) {
		# Apparently using a loop is faster than calling
		# binFind() (which is optimized in C), because
		# of function call overhead.
		#return 1 if defined binFind(\@ai_seq, $_);
		foreach my $seq (@ai_seq) {
			return 1 if ($_ eq $seq);
		}
	}
	return 0;
}

sub isIdle {
	return $ai_seq[0] eq "";
}

sub is {
	foreach (@_) {
		return 1 if ($ai_seq[0] eq $_);
	}
	return 0;
}

return 1;
