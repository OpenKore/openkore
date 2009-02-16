use strict;
use warnings;

package Test::Deep::HashKeysOnly;

use Test::Deep::Ref;

sub init
{
	my $self = shift;

	my %keys;
	@keys{@_} = ();
	$self->{val} = \%keys;
	$self->{keys} = [sort @_];
}

sub descend
{
	my $self = shift;
	my $hash = shift;

	my $data = $self->data;
	my $exp = $self->{val};
	my %got;
	@got{keys %$hash} = ();

	my @missing;
	my @extra;

	while (my ($key, $value) = each %$exp)
	{
		if (exists $got{$key})
		{
			delete $got{$key};
		}
		else
		{
			push(@missing, $key);
		}
	}

	my @diags;
	if (@missing and (not $self->ignoreMissing))
	{
		push(@diags, "Missing: ".nice_list(\@missing));
	}

	if (%got and (not $self->ignoreExtra))
	{
		push(@diags, "Extra: ".nice_list([keys %got]));
	}

	if (@diags)
	{
		$data->{diag} = join("\n", @diags);
		return 0;
	}

	return 1;
}

sub diagnostics
{
	my $self = shift;
	my ($where, $last) = @_;

	my $type = $self->{IgnoreDupes} ? "Set" : "Bag";

	my $error = $last->{diag};
	my $diag = <<EOM;
Comparing hash keys of $where
$error
EOM

	return $diag;
}

sub nice_list
{
	my $list = shift;

	return join(", ",
		(map {"'$_'"} sort @$list),
	);
}

sub ignoreMissing
{
	return 0;
}

sub ignoreExtra
{
	return 0;
}

package Test::Deep::SuperHashKeysOnly;

use base 'Test::Deep::HashKeysOnly';

sub ignoreMissing
{
	return 0;
}

sub ignoreExtra
{
	return 1;
}

package Test::Deep::SubHashKeysOnly;

use base 'Test::Deep::HashKeysOnly';

sub ignoreMissing
{
	return 1;
}

sub ignoreExtra
{
	return 0;
}

1;
