use strict;
use warnings;

package Test::Deep;
use Carp qw( confess );

use Test::Deep::Cache;
use Test::Deep::Stack;
require overload;
use Scalar::Util;

my $Test;
unless (defined $Test::Deep::NoTest::NoTest)
{
# for people who want eq_deeply but not Test::Builder
	require Test::Builder;
	$Test = Test::Builder->new;
}

use Data::Dumper qw(Dumper);

use vars qw(
	$VERSION @EXPORT @EXPORT_OK @ISA
	$Stack %Compared $CompareCache %WrapCache
	$Snobby $Expects $DNE $DNE_ADDR $Shallow
);

$VERSION = '0.103';

require Exporter;
@ISA = qw( Exporter );

@EXPORT = qw( eq_deeply cmp_deeply cmp_set cmp_bag cmp_methods
	useclass noclass set bag subbagof superbagof subsetof supersetof
	superhashof subhashof
);
	# plus all the ones generated from %constructors below

@EXPORT_OK = qw( descend render_stack deep_diag class_base );

$Snobby = 1; # should we compare classes?
$Expects = 0; # are we comparing got vs expect or expect vs expect

$DNE = \"";
$DNE_ADDR = Scalar::Util::refaddr($DNE);

# if no sub name is supplied then we use the package name in lower case
my %constructors = (
	Number => "num",
	Methods => "",
	ListMethods => "",
	String => "str",
	Boolean => "bool",
	ScalarRef => "scalref",
	ScalarRefOnly => "",
	Array => "",
	ArrayEach => "array_each",
	ArrayElementsOnly => "",
	Hash => "",
	HashEach => "hash_each",
	Regexp => "re",
	RegexpMatches => "",
	RegexpOnly => "",
	RegexpRef => "",
	Ignore => "",
	Shallow => "",
	Any => "",
	All => "",
	Isa => "Isa",
	RegexpRefOnly => "",
	RefType => "",
	Blessed => "",
	ArrayLength => "",
	ArrayLengthOnly => "",
	HashKeys => "",
	HashKeysOnly => "",
	Code => "",
);

while (my ($pkg, $name) = each %constructors)
{
	$name = lc($pkg) unless $name;
	my $full_pkg = "Test::Deep::$pkg";
	my $file = "$full_pkg.pm";
	$file =~ s#::#/#g;
	my $sub = sub {
		require $file;
		return $full_pkg->new(@_);
	};
	{
		no strict 'refs';
		*{$name} = $sub;
	}
	push(@EXPORT, $name);
}
my %count;
foreach my $e (@EXPORT)
{
	$count{$e}++;
}

# this is ugly, I should never have exported a sub called isa now I
# have to try figure out if the recipient wanted my isa or if a class
# imported us and UNIVERSAL::isa is being called on that class.
# Luckily our isa always expects 1 argument and U::isa always expects
# 2, so we can figure out (assuming the caller is no buggy).
sub isa
{
	if (@_ == 1)
	{
		goto &Isa;
	}
	else
	{
		goto &UNIVERSAL::isa;
	}
}

push(@EXPORT, "isa");

sub cmp_deeply
{
	my ($d1, $d2, $name) = @_;

	my ($ok, $stack) = cmp_details($d1, $d2);

	if (not $Test->ok($ok, $name))
	{
		my $diag = deep_diag($stack);
		$Test->diag($diag);
	}

	return $ok;
}

sub cmp_details
{
	my ($d1, $d2) = @_;

	local $Stack = Test::Deep::Stack->new;
	local $CompareCache = Test::Deep::Cache->new;
	local %WrapCache;

	my $ok = descend($d1, $d2);

	return ($ok, $Stack);
}

sub eq_deeply
{
	my ($d1, $d2) = @_;

	my ($ok) = cmp_details($d1, $d2);

	return $ok
}

sub eq_deeply_cache
{
	# this is like cross between eq_deeply and descend(). It doesn't start
	# with a new $CompareCache but if the comparison fails it will leave
	# $CompareCache as if nothing happened. However, if the comparison
	# succeeds then $CompareCache retains all the new information

	# this allows Set and Bag to handle circular refs

	my ($d1, $d2, $name) = @_;

	local $Stack = Test::Deep::Stack->new;
	$CompareCache->local;

	my $ok = descend($d1, $d2);

	$CompareCache->finish($ok);

	return $ok;
}

sub deep_diag
{
	my $stack = shift;
	# ick! incArrow and other things expect the stack has to be visible
	# in a well known place . TODO clean this up
	local $Stack = $stack;

	my $where = render_stack('$data', $stack);

	confess "No stack to diagnose" unless $stack;
	my $last = $stack->getLast;

	my $diag;
	my $message;
	my $got;
	my $expected;

	my $exp = $last->{exp};
	if (ref $exp)
	{
		if ($exp->can("diagnostics"))
		{
			$diag = $exp->diagnostics($where, $last);
			$diag =~ s/\n+$/\n/;
		}
		else
		{
			if ($exp->can("diag_message"))
			{
				$message = $exp->diag_message($where);
			}
		}
	}

	if (not defined $diag)
	{
		$got = $exp->renderGot($last->{got}) unless defined $got;
		$expected = $exp->renderExp unless defined $expected;
		$message = "Compared $where" unless defined $message;

		$diag = <<EOM
$message
   got : $got
expect : $expected
EOM
	}

	return $diag;
}

sub render_val
{
	# add in Data::Dumper stuff
	my $val = shift;

	my $rendered;
	if (defined $val)
	{
	 	$rendered = ref($val) ?
	 		(Scalar::Util::refaddr($val) eq $DNE_ADDR ?
	 			"Does not exist" :
				overload::StrVal($val)
			) :
			qq('$val');
	}
	else
	{
		$rendered = "undef";
	}

	return $rendered;
}

sub descend
{
	my ($d1, $d2) = @_;

	if (! $Expects and ref($d1) and UNIVERSAL::isa($d1, "Test::Deep::Cmp"))
	{
		my $where = $Stack->render('$data');
		confess "Found a special comparison in $where\nYou can only the specials in the expects structure";
	}

	if (ref $d1 and ref $d2)
	{
		# this check is only done when we're comparing 2 expecteds against each
		# other

		if ($Expects and UNIVERSAL::isa($d1, "Test::Deep::Cmp"))
		{
			# check they are the same class
			return 0 unless Test::Deep::blessed(Scalar::Util::blessed($d2))->descend($d1);
			if ($d1->can("compare"))
			{
				return $d1->compare($d2);
			}
		}

		my $s1 = Scalar::Util::refaddr($d1);
		my $s2 = Scalar::Util::refaddr($d2);

		if ($s1 eq $s2)
		{
			return 1;
		}
		if ($CompareCache->cmp($d1, $d2))
		{
			# we've tried comparing these already so either they turned out to
			# be the same or we must be in a loop and we have to assume they're
			# the same

			return 1;
		}
		else
		{
			$CompareCache->add($d1, $d2)
		}
	}

	$d2 = wrap($d2);

	$Stack->push({exp => $d2, got => $d1});

	if (ref($d1) and (Scalar::Util::refaddr($d1) == $DNE_ADDR))
	{
		# whatever it was suposed to be, it didn't exist and so it's an
		# automatic fail
		return 0;
	}

	if ($d2->descend($d1))
	{
#		print "d1 = $d1, d2 = $d2\nok\n";
		$Stack->pop;

		return 1;
	}
	else
	{
#		print "d1 = $d1, d2 = $d2\nnot ok\n";
		return 0;
	}
}

sub wrap
{
	my $data = shift;

	return $data if ref($data) and UNIVERSAL::isa($data, "Test::Deep::Cmp");

	my ($class, $base) = class_base($data);

	my $cmp;

	if($base eq '')
	{
		$cmp = shallow($data);
	}
	else
	{
		my $addr = Scalar::Util::refaddr($data);

		return $WrapCache{$addr} if $WrapCache{$addr};
		
		if($base eq 'ARRAY')
		{
			$cmp = array($data);
		}
		elsif($base eq 'HASH')
		{
			$cmp = hash($data);
		}
		elsif($base eq 'SCALAR' or $base eq 'REF')
		{
			$cmp = scalref($data);
		}
		elsif($] <= 5.010 ? ($base eq 'Regexp') : ($base eq 'REGEXP'))
		{
			$cmp = regexpref($data);
		}
		else
		{
			$cmp = shallow($data);
		}

		$WrapCache{$addr} = $cmp;
	}
	return $cmp;
}

sub class_base
{
	my $val = shift;

	if (ref $val)
	{
		my $blessed = Scalar::Util::blessed($val);
		$blessed = defined($blessed) ? $blessed : "";
		my $reftype = Scalar::Util::reftype($val);


		if ($] <= 5.010) {
			if ($blessed eq "Regexp" and $reftype eq "SCALAR")
			{
				$reftype = "Regexp"
			}
		}
		return ($blessed, $reftype);
	}
	else
	{
		return ("", "");
	}
}

sub render_stack
{
	my ($var, $stack) = @_;

	return $stack->render($var);
}

sub cmp_methods
{
	local $Test::Builder::Level = $Test::Builder::Level + 1;
	return cmp_deeply(shift, methods(@{shift()}), shift);
}

sub requireclass
{
	require Test::Deep::Class;

	my $val = shift;

	return Test::Deep::Class->new(1, $val);
}

# docs and export say this is call useclass, doh!

*useclass = \&requireclass;

sub noclass
{
	require Test::Deep::Class;

	my $val = shift;

	return Test::Deep::Class->new(0, $val);
}

sub set
{
	require Test::Deep::Set;

	return Test::Deep::Set->new(1, "", @_);
}

sub supersetof
{
	require Test::Deep::Set;

	return Test::Deep::Set->new(1, "sup", @_);
}

sub subsetof
{
	require Test::Deep::Set;

	return Test::Deep::Set->new(1, "sub", @_);
}

sub cmp_set
{
	local $Test::Builder::Level = $Test::Builder::Level + 1;
	return cmp_deeply(shift, set(@{shift()}), shift);
}

sub bag
{
	require Test::Deep::Set;

	return Test::Deep::Set->new(0, "", @_);
}

sub superbagof
{
	require Test::Deep::Set;

	return Test::Deep::Set->new(0, "sup", @_);
}

sub subbagof
{
	require Test::Deep::Set;

	return Test::Deep::Set->new(0, "sub", @_);
}

sub cmp_bag
{
	local $Test::Builder::Level = $Test::Builder::Level + 1;
	return cmp_deeply(shift, bag(@{shift()}), shift);
}

sub superhashof
{
	require Test::Deep::Hash;

	my $val = shift;

	return Test::Deep::SuperHash->new($val);
}

sub subhashof
{
	require Test::Deep::Hash;

	my $val = shift;

	return Test::Deep::SubHash->new($val);
}

sub builder
{
	if (@_)
	{
		$Test = shift;
	}
	return $Test;
}

1;

