##
# Helper functions for managing @ai_seq.
#
# Eventually, @ai_seq should never be referenced directly, and then it can be
# moved into this package.

package AI;

use strict;
use Globals;


sub action {
	my $i = (defined $_[0] ? $_[0] : 0);
	return $ai_seq[$i];
}

sub args {
	my $i = (defined $_[0] ? $_[0] : 0);
	return $ai_seq_args[$i];
}

sub dequeue {
	shift @ai_seq;
	shift @ai_seq_args;
}

sub queue {
	unshift @ai_seq, shift;
	unshift @ai_seq_args, shift;
}

sub clear {
	undef @ai_seq;
	undef @ai_seq_args;
}


return 1;
