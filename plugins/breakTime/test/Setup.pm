package Setup;

use strict;
use warnings;

use Time::Local;

# Allow us to mock localtime, which breakTime uses.
our $mock_localtime;

BEGIN {
	*CORE::GLOBAL::localtime = sub {
		wantarray
			? ( @_ ? ( CORE::localtime( @_ ) ) : ( CORE::localtime( $mock_localtime || CORE::time ) ) )
			: ( @_ ? CORE::localtime( @_ ) : CORE::localtime( $mock_localtime || CORE::time ) );
	};
	*CORE::GLOBAL::time = sub () {
		$mock_localtime || CORE::time
	};
}

# Load the plugin code after initial setup.
require 'breakTime.pl';

sub start {}

1;
