use strict;
use warnings;

package Test::Deep::Boolean;

use Test::Deep::Cmp;

sub init
{
	my $self = shift;

	$self->{val} = shift() ? 1 : 0;
}

sub descend
{
	my $self = shift;
	my $got = shift;

	return !( $got xor $self->{val} );
}

sub diag_message
{
	my $self = shift;
	my $where = shift;
	return "Comparing $where as a boolean";
}

sub renderExp
{
	my $self = shift;

	$self->renderGot($self->{val});
}

sub renderGot
{
	my $self = shift;

	my $val = shift;

	return ($val ? "true" : "false")." (".Test::Deep::render_val($val).")";
}

1;
