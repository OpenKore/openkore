use strict;
use warnings;

package Test::Deep::Cache::Simple;
use Carp qw( confess );

use Scalar::Util qw( refaddr );

BEGIN
{
  if (grep /^weaken$/, @Scalar::Util::EXPORT_FAIL)
  {
    # we're running on a version of perl that has no weak refs, so we
    # just install a no-op sub for weaken instead of importing it
    *weaken = sub {};
  }
  else
  {
    Scalar::Util->import('weaken');
  }
}

sub new
{
	my $pkg = shift;

	my $self = bless {}, $pkg;

	return $self;
}

sub add
{
	my $self = shift;

	my ($d1, $d2) = @_;
	{
		local $SIG{__DIE__};

		# cannot weaken read only refs, no harm if we can't as they never
		# disappear
		eval{weaken($d1)};
		eval{weaken($d2)};
	}

	$self->{fn_get_key(@_)} = [$d1, $d2];
}

sub cmp
{
	my $self = shift;

	my $key = fn_get_key(@_);
	my $pair = $self->{$key};

	# are both weakened refs still valid, if not delete this entry
	if (ref($pair->[0]) and ref($pair->[1]))
	{
		return 1;
	}
	else
	{
		delete $self->{$key};
		return 0;
	}
}

sub absorb
{
	my $self = shift;

	my $other = shift;

	@{$self}{keys %$other} = values %$other;
}

sub fn_get_key
{
	return join(",", sort (map {refaddr($_)} @_));
}
1;
