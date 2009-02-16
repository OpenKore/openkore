use strict;
use warnings;

package Test::Deep::MM;

sub import
{
	my $self = shift;

	my ($pkg) = caller();
	my $mpkg = $pkg."::Methods";
	foreach my $attr (@_)
	{
		if ($attr =~ /^[a-z]/)
		{
			no strict 'refs';
			*{$mpkg."::$attr"} = \&{$attr};
		}
		else
		{
			my $get_name = $mpkg."::get$attr";
			my $set_name = $mpkg."::set$attr";
			my $get_sub = sub {
				return $_[0]->{$attr};
			};
			my $set_sub = sub {
				return $_[0]->{$attr} = $_[1];
			};

			{
				no strict 'refs';
				*$get_name = $get_sub;
				*$set_name = $set_sub;
				push(@{$pkg."::ISA"}, $mpkg);
			}
		}
	}
}

sub new
{
	my $pkg = shift;

	my $self = bless {}, $pkg;

	$self->init(@_);

	return $self;
}

sub init
{
	my $self = shift;

	while (@_)
	{
		my $name = shift || confess("No name");

		my $method = "set$name";
		$self->$method(shift);
	}
}

1;
