package OpenKoreTestStubs;

use strict;
use warnings;

# Misc.pm normally loads XSTools.  The ownership checks do not need the
# native extension, so keep every Perl dependency real and replace only the
# unavailable extension and its translation wrapper.
sub import {
	no strict 'refs';
	if (!$INC{'XSTools.pm'}) {
		$INC{'XSTools.pm'} = __FILE__;
		*{'XSTools::bootModule'} = sub { return 1; };
	}

	if (!$INC{'Translation.pm'}) {
		$INC{'Translation.pm'} = __FILE__;
		*{'Translation::T'} = sub { return $_[0]; };
		*{'Translation::TF'} = sub {
			my ($format, @args) = @_;
			return sprintf($format, @args);
		};
		*{'Translation::import'} = sub {
			my $caller = caller;
			*{"${caller}::T"} = \&Translation::T;
			*{"${caller}::TF"} = \&Translation::TF;
			return 1;
		};
	}
}

1;
