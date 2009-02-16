use strict;
use warnings;

package Test::Deep::Any;

use Test::Deep::Cmp;

use overload
	'&' => \&add,
	fallback => 1,
;

sub init
{
	my $self = shift;

	my @list = map {Test::Deep::wrap($_)} @_;

	$self->{val} = \@list;
}

sub descend
{
	my $self = shift;
	my $got = shift;

	foreach my $cmp (@{$self->{val}})
	{
		return 1 if Test::Deep::eq_deeply_cache($got, $cmp);
	}

	return 0;
}

sub diagnostics
{
	my $self = shift;
	my ($where, $last) = @_;

	my $expect = $self->{val};

	my $got = $self->renderGot($last->{got});
	my $things = join(", ", map {$_->renderExp} @$expect);

	my $diag = <<EOM;
Comparing $where with Any
got      : $got
expected : Any of ( $things )
EOM

	$diag =~ s/\n+$/\n/;
	return $diag;
}

sub add
{
	my $self = shift;
	my $expect = shift;

	push(@{$self->{val}}, Test::Deep::wrap($expect));

	return $self;
}

1;
