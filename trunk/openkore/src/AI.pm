##
# Helper functions for managing @ai_seq.
#
# Eventually, @ai_seq should never be referenced directly, and then it can be
# moved into this package.

package AI;

use strict;
use Globals;

sub action {
	return $ai_seq[0];
}

sub args {
	return $ai_seq_args[0];
}

sub dequeue {
	shift @ai_seq;
	shift @ai_seq_args;
}

sub enqueue {
	push(@ai_seq, shift);
	push(@ai_seq_args, shift);
}

return 1;
