use strict;
use warnings;

package Test::Deep::Code;

use Test::Deep::Cmp;

sub init
{
	my $self = shift;

	my $code = shift || die "No coderef supplied";

	$self->{code} = $code;
}

sub descend
{
	my $self = shift;
	my $got = shift;

	my ($ok, $diag) = &{$self->{code}}($got);

	$self->data->{diag} = $diag;

	return $ok;
}

sub diagnostics
{
	my $self = shift;
	my ($where, $last) = @_;

	my $error = $last->{diag};
	my $data = Test::Deep::render_val($last->{got});
	my $diag = <<EOM;
Ran coderef at $where on

$data
EOM
  if (defined($error))
  {
    $diag .= <<EOM;
and it said
$error
EOM
  }
  else
  {
    $diag .= <<EOM;
it failed but it didn't say why.
EOM
  }

	return $diag;
}

1;
