package Tie::BlessedRef;
use strict;

use Tie::Scalar;
use base 'Tie::StdScalar';

sub STORE {
	my ($ref, $value) = @_;
	
	die "Attempt to STORE non blessed reference (or not a reference)\n"
	. "Value:\n"
	. Data::Dumper::Dumper($value) . "\n"
	unless Scalar::Util::blessed($value);
	
	$ref->SUPER::STORE($value);
}

1;
