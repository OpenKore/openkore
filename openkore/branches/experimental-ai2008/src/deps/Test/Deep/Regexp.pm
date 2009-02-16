use strict;
use warnings;

package Test::Deep::Regexp;

use Test::Deep::Cmp;
use Test::Deep::RegexpMatches;

sub init
{
	my $self = shift;

	my $val = shift;

	$val = ref $val ? $val : qr/$val/;

	$self->{val} = $val;

	if (my $matches = shift)
	{
		$self->{matches} = Test::Deep::regexpmatches($matches, $val);
		
		$self->{flags} = shift || "";
	}
}

sub descend
{
	my $self = shift;
	my $got = shift;

	my $re = $self->{val};
	if (my $match_exp = $self->{matches})
	{
		my $flags = $self->{flags};
		my @match_got;
		if ($flags eq "g")
		{
			@match_got = $got =~ /$re/g;
		}
		else
		{
			@match_got = $got =~ /$re/;
		}

		if (@match_got)
		{
			return Test::Deep::descend(\@match_got, $match_exp);
		}
		else
		{
			return 0;
		}
	}
	else
	{
		return ($got =~ $re) ? 1 : 0;
	}
}

sub diag_message
{
	my $self = shift;

	my $where = shift;

	return "Using Regexp on $where";
}

sub render_stack1
{
	my $self = shift;

	my $stack = shift;
	return "($stack =~ $self->{regex})";
}

sub renderExp
{
	my $self = shift;

	return "$self->{val}";
}

1;
