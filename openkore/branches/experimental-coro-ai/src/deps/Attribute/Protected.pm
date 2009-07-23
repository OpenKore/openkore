package Attribute::Protected;

use 5.006;
use strict;
use warnings;

our $VERSION = '0.03';

use Attribute::Handlers;

sub UNIVERSAL::Protected : ATTR(CODE) {
    my($package, $symbol, $referent, $attr, $data, $phase) = @_;
    my $meth = *{$symbol}{NAME};
    no warnings 'redefine';
    no strict 'refs'; 
    *{$symbol} = sub {
	unless (caller->isa($package)) {
	    require Carp;
	    Carp::croak "$meth() is a protected method of $package!";
	}
	goto &$referent;
    };
}

sub UNIVERSAL::Private : ATTR(CODE) {
    my($package, $symbol, $referent, $attr, $data, $phase) = @_;
    my $meth = *{$symbol}{NAME};
    no warnings 'redefine';
    no strict 'refs'; 
    *{$symbol} = sub {
	unless (caller eq $package) {
	    require Carp;
	    Carp::croak "$meth() is a private method of $package!";
	}
	goto &$referent;
    };
}

sub UNIVERSAL::Public : ATTR(CODE) {
    my($package, $symbol, $referent, $attr, $data, $phase) = @_;
    # just a mark, do nothing
}

1;
__END__

=head1 NAME

Attribute::Protected - implementing proctected methods with attributes

=head1 SYNOPSIS

  package SomeClass;
  use Attribute::Protected;

  sub foo  : Public    { }
  sub _bar : Private   { }
  sub _baz : Protected { }

  sub another {
      my $self = shift;
      $self->foo;		# OK
      $self->_bar;		# OK
      $self->_baz;		# OK
  }

  package DerivedClass;
  @DerivedClass::ISA = qw(SomeClass);

  sub yetanother {
      my $self = shift;
      $self->foo;		# OK
      $self->_bar;		# NG: private method
      $self->_baz;		# OK
  }

  package main;

  my $some = SomeClass->new;
  $some->foo;		# OK
  $some->_bar;		# NG: private method
  $some->_baz;		# NG: protected method

=head1 DESCRIPTION

Attribute::Protected implements something like public / private /
protected methods in C++ or Java.

=head1 ATTRIBUTES

=over 4

=item Public

  sub foo : Public { }

just a mark. Can be called from everywhere.

=item Private

  sub _bar : Private { }

Can't be called from outside the class where it was declared.

=item Protected

  sub _baz : Protected { }

Can be called from the class where it was declared or its derived classes.

=back

When called from inappropriate classes, those methods throw an
exception like C<foo() is a protected method of Foo!>.

=head1 THOUGHT

=over 4

=item *

attributes (public, private and proteced) should be lowercased?

=back

=head1 AUTHOR

Tatsuhiko Miyagawa E<lt>miyagawa@bulknews.netE<gt>

This library is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 SEE ALSO

L<Attribute::Handlers>, L<protect>, L<Class::Fields>

=cut
