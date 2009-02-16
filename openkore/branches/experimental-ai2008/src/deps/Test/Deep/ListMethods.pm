use strict;
use warnings;

package Test::Deep::ListMethods;

use base 'Test::Deep::Methods';

sub call_method
{
	my $self = shift;

	return [$self->SUPER::call_method(@_)];
}

sub render_stack
{
	my $self = shift;

	my $var = $self->SUPER::render_stack(@_);

	return "[$var]";
}

1;
