# This is Exception::Class from http://cpan.uwinnipeg.ca/htdocs/Exception-Class/Exception/Class.html
# Slightly modified to export the 'caught' method by default.
package Exception::Class;

use 5.005;

use strict;
use vars qw($VERSION $BASE_EXC_CLASS %CLASSES);

use Exporter;
use base qw(Exporter);
our @EXPORT_OK = qw(caught);

use Scalar::Util qw(blessed);


BEGIN { $BASE_EXC_CLASS ||= 'Exception::Class::Base'; }

$VERSION = '1.21';

sub import
{
    my $class = shift;

    local $Exception::Class::Caller = caller();

    my %c;

    my %needs_parent;
    while (my $subclass = shift)
    {
	my $def = ref $_[0] ? shift : {};
	$def->{isa} = $def->{isa} ? ( ref $def->{isa} ? $def->{isa} : [$def->{isa}] ) : [];

        $c{$subclass} = $def;
    }

    # We need to sort by length because if we check for keys in the
    # Foo::Bar:: stash, this creates a "Bar::" key in the Foo:: stash!
 MAKE_CLASSES:
    foreach my $subclass ( sort { length $a <=> length $b } keys %c )
    {
        my $def = $c{$subclass};

	# We already made this one.
	next if $CLASSES{$subclass};

	{
	    no strict 'refs';
	    foreach my $parent (@{ $def->{isa} })
	    {
		unless ( keys %{"$parent\::"} )
		{
		    $needs_parent{$subclass} = { parents => $def->{isa},
						 def => $def };
		    next MAKE_CLASSES;
		}
	    }
	}

	$class->_make_subclass( subclass => $subclass,
				def => $def || {},
                              );
    }

    foreach my $subclass (keys %needs_parent)
    {
	# This will be used to spot circular references.
	my %seen;
	$class->_make_parents( \%needs_parent, $subclass, \%seen );
    }

    $class->export_to_level(1, $class, 'caught');
}

sub _make_parents
{
    my $class = shift;
    my $needs = shift;
    my $subclass = shift;
    my $seen = shift;
    my $child = shift; # Just for error messages.

    no strict 'refs';

    # What if someone makes a typo in specifying their 'isa' param?
    # This should catch it.  Either it's been made because it didn't
    # have missing parents OR it's in our hash as needing a parent.
    # If neither of these is true then the _only_ place it is
    # mentioned is in the 'isa' param for some other class, which is
    # not a good enough reason to make a new class.
    die "Class $subclass appears to be a typo as it is only specified in the 'isa' param for $child\n"
	unless exists $needs->{$subclass} || $CLASSES{$subclass} || keys %{"$subclass\::"};

    foreach my $c ( @{ $needs->{$subclass}{parents} } )
    {
	# It's been made
	next if $CLASSES{$c} || keys %{"$c\::"};

	die "There appears to be some circularity involving $subclass\n"
	    if $seen->{$subclass};

	$seen->{$subclass} = 1;

	$class->_make_parents( $needs, $c, $seen, $subclass );
    }

    return if $CLASSES{$subclass} || keys %{"$subclass\::"};

    $class->_make_subclass( subclass => $subclass,
			    def => $needs->{$subclass}{def} );
}

sub _make_subclass
{
    my $class = shift;
    my %p = @_;

    my $subclass = $p{subclass};
    my $def = $p{def};

    my $isa;
    if ($def->{isa})
    {
	$isa = ref $def->{isa} ? join ' ', @{ $def->{isa} } : $def->{isa};
    }
    $isa ||= $BASE_EXC_CLASS;

    my $code = <<"EOPERL";
package $subclass;

use vars qw(\$VERSION);

use base qw($isa);

\$VERSION = '1.1';

1;

EOPERL


    if ($def->{description})
    {
	(my $desc = $def->{description}) =~ s/([\\\'])/\\$1/g;
	$code .= <<"EOPERL";
sub description
{
    return '$desc';
}
EOPERL
    }

    my @fields;
    if ( my $fields = $def->{fields} )
    {
	@fields = UNIVERSAL::isa($fields, 'ARRAY') ? @$fields : $fields;

	$code .=
            "sub Fields { return (\$_[0]->SUPER::Fields, " .
            join(", ", map { "'$_'" } @fields) . ") }\n\n";

        foreach my $field (@fields)
	{
	    $code .= sprintf("sub %s { \$_[0]->{%s} }\n", $field, $field);
	}
    }

    if ( my $alias = $def->{alias} )
    {
        die "Cannot make alias without caller"
            unless defined $Exception::Class::Caller;

        no strict 'refs';
        *{"$Exception::Class::Caller\::$alias"} = sub { $subclass->throw(@_) };
    }

    eval $code;

    die $@ if $@;

    $CLASSES{$subclass} = 1;
}

sub caught
{
    my $e = $@;
    my $class;
    if (@_ == 1) {
    	$class = $_[0];
    } else {
    	$class = $_[1];
    }

    return unless blessed($e) && $e->isa( $class );
    return $e;
}

sub Classes { sort keys %Exception::Class::CLASSES }

package Exception::Class::Base;

use Class::Data::Inheritable;
use Devel::StackTrace 1.07;

use base qw(Class::Data::Inheritable);

BEGIN
{
    __PACKAGE__->mk_classdata('Trace');
    *do_trace = \&Trace;
    __PACKAGE__->mk_classdata('NoRefs');
    *NoObjectRefs = \&NoRefs;
    __PACKAGE__->NoRefs(1);

    __PACKAGE__->mk_classdata('RespectOverload');
    __PACKAGE__->RespectOverload(0);


    sub Fields { () }
}

use overload
    # an exception is always true
    bool => sub { 1 },
    '""' => 'as_string',
    fallback => 1;

use vars qw($VERSION);

$VERSION = '1.2';

# Create accessor routines
BEGIN
{
    my @fields = qw( message pid uid euid gid egid time trace package file line );

    no strict 'refs';
    foreach my $f (@fields)
    {
	*{$f} = sub { my $s = shift; return $s->{$f}; };
    }
    *{'error'} = \&message;
}

1;

sub Classes { Exception::Class::Classes() }

sub throw
{
    my $proto = shift;

    $proto->rethrow if ref $proto;

    die $proto->new(@_);
}

sub rethrow
{
    my $self = shift;

    die $self;
}

sub new
{
    my $proto = shift;
    my $class = ref $proto || $proto;

    my $self = bless {}, $class;

    $self->_initialize(@_);

    return $self;
}

sub _initialize
{
    my $self = shift;
    my %p = @_ == 1 ? ( error => $_[0] ) : @_;

    # Try to get something useful in there (I hope).  Or just give up.
    $self->{message} = $p{message} || $p{error} || $! || '';

    $self->{show_trace} = $p{show_trace} if exists $p{show_trace};

    # CORE::time is important to fix an error with some versions of
    # Perl
    $self->{time} = CORE::time();
    $self->{pid}  = $$;
    $self->{uid}  = $<;
    $self->{euid} = $>;
    $self->{gid}  = $(;
    $self->{egid} = $);

    my @ignore_class   = (__PACKAGE__);
    my @ignore_package = 'Exception::Class';

    if ( my $i = delete $p{ignore_class} )
    {
        push @ignore_class, ( ref($i) eq 'ARRAY' ? @$i : $i );
    }

    if ( my $i = delete $p{ignore_package} )
    {
        push @ignore_package, ( ref($i) eq 'ARRAY' ? @$i : $i );
    }

    $self->{trace} =
        Devel::StackTrace->new( ignore_class     => \@ignore_class,
                                ignore_package   => \@ignore_package,
                                no_refs          => $self->NoRefs,
                                respect_overload => $self->RespectOverload,
                              );

    if ( my $frame = $self->trace->frame(0) )
    {
        $self->{package} = $frame->package;
        $self->{line} = $frame->line;
        $self->{file} = $frame->filename;
    }

    my %fields = map { $_ => 1 } $self->Fields;
    while ( my ($key, $value) = each %p )
    {
       next if $key =~ /^(?:error|message|show_trace)$/;

       if ( $fields{$key})
       {
           $self->{$key} = $value;
       }
       else
       {
           Exception::Class::Base->throw
               ( error =>
                 "unknown field $key passed to constructor for class " . ref $self );
       }
    }
}

sub description
{
    return 'Generic exception';
}

sub show_trace
{
    my $self = shift;

    if (@_)
    {
        $self->{show_trace} = shift;
    }

    return exists $self->{show_trace} ? $self->{show_trace} : $self->Trace;
}

sub as_string
{
    my $self = shift;

    my $str = $self->full_message;
    $str .= "\n\n" . $self->trace->as_string
        if $self->show_trace;

    return $str;
}

sub full_message { $_[0]->{message} }

#
# The %seen bit protects against circular inheritance.
#
eval <<'EOF' if $] == 5.006;
sub isa
{
    my ($inheritor, $base) = @_;
    $inheritor = ref($inheritor) if ref($inheritor);

    my %seen;

    no strict 'refs';
    my @parents = ($inheritor, @{"$inheritor\::ISA"});
    while (my $class = shift @parents)
    {
        return 1 if $class eq $base;

        push @parents, grep {!$seen{$_}++} @{"$class\::ISA"};
    }
    return 0;
}
EOF

1;

__END__

=head1 NAME

Exception::Class - A module that allows you to declare real exception classes in Perl

=head1 SYNOPSIS

  use Exception::Class
      ( 'MyException',

        'AnotherException' =>
        { isa => 'MyException' },

        'YetAnotherException' =>
        { isa => 'AnotherException',
          description => 'These exceptions are related to IPC' },

        'ExceptionWithFields' =>
        { isa => 'YetAnotherException',
          fields => [ 'grandiosity', 'quixotic' ],
          alias => 'throw_fields',
      );

  # try
  eval { MyException->throw( error => 'I feel funny.' ) };

  # catch
  if ( UNIVERSAL::isa( $@, 'MyException' ) )
  {
     warn $@->error, "\n, $@->trace->as_string, "\n";
     warn join ' ',  $@->euid, $@->egid, $@->uid, $@->gid, $@->pid, $@->time;

     exit;
  }
  elsif ( UNIVERSAL::isa( $@, 'ExceptionWithFields' ) )
  {
     $@->quixotic ? do_something_wacky() : do_something_sane();
  }
  else
  {
     ref $@ ? $@->rethrow : die $@;
  }

  # use an alias - without parens subroutine name is checked at
  # compile time
  throw_fields error => "No strawberry", grandiosity => "quite a bit";

=head1 DESCRIPTION

Exception::Class allows you to declare exception hierarchies in your
modules in a "Java-esque" manner.

It features a simple interface allowing programmers to 'declare'
exception classes at compile time.  It also has a base exception
class, Exception::Class::Base, that can be easily extended.

It is designed to make structured exception handling simpler and
better by encouraging people to use hierarchies of exceptions in their
applications, as opposed to a single catch-all exception class.

This module does not implement any try/catch syntax.  Please see the
"OTHER EXCEPTION MODULES (try/catch syntax)" section for more
information on how to get this syntax.

=head1 DECLARING EXCEPTION CLASSES

Importing C<Exception::Class> allows you to automagically create
C<Exception::Class::Base> subclasses.  You can also create subclasses
via the traditional means of defining your own subclass with C<@ISA>.
These two methods may be easily combined, so that you could subclass
an exception class defined via the automagic import, if you desired
this.

The syntax for the magic declarations is as follows:

'MANDATORY CLASS NAME' => \%optional_hashref

The hashref may contain the following options:

=over 4

=item * isa

This is the class's parent class.  If this isn't provided then the
class name in C<$Exception::Class::BASE_EXC_CLASS> is assumed to be
the parent (see below).

This parameter lets you create arbitrarily deep class hierarchies.
This can be any other C<Exception::Class::Base> subclass in your
declaration I<or> a subclass loaded from a module.

To change the default exception class you will need to change the
value of C<$Exception::Class::BASE_EXC_CLASS> I<before> calling
C<import()>.  To do this simply do something like this:

BEGIN { $Exception::Class::BASE_EXC_CLASS = 'SomeExceptionClass'; }

If anyone can come up with a more elegant way to do this please let me
know.

CAVEAT: If you want to automagically subclass an
C<Exception::Class::Base> subclass loaded from a file, then you
I<must> compile the class (via use or require or some other magic)
I<before> you import C<Exception::Class> or you'll get a compile time
error.

=item * fields

This allows you to define additional attributes for your exception
class.  Any field you define can be passed to the C<throw()> or
C<new()> methods as additional parameters for the constructor.  In
addition, your exception object will have an accessor method for the
fields you define.

This parameter can be either a scalar (for a single field) or an array
reference if you need to define multiple fields.

Fields will be inherited by subclasses.

=item * alias

Specifying an alias causes this class to create a subroutine of the
specified name in the I<caller's> namespace.  Calling this subroutine
is equivalent to calling C<< <class>->throw(@_) >> for the given
exception class.

Besides convenience, using aliases also allows for additional compile
time checking.  If the alias is called I<without parentheses>, as in
C<throw_fields "an error occurred">, then Perl checks for the
existence of the C<throw_fields()> subroutine at compile time.  If
instead you do C<< ExceptionWithFields->throw(...) >>, then Perl
checks the class name at runtime, meaning that typos may sneak
through.

=item * description

Each exception class has a description method that returns a fixed
string.  This should describe the exception I<class> (as opposed to
any particular exception object).  This may be useful for debugging if
you start catching exceptions you weren't expecting (particularly if
someone forgot to document them) and you don't understand the error
messages.

=back

The C<Exception::Class> magic attempts to detect circular class
hierarchies and will die if it finds one.  It also detects missing
links in a chain, for example if you declare Bar to be a subclass of
Foo and never declare Foo.

=head1 Catching Exceptions

C<Exception::Class> provides some syntactic sugar for catching
exceptions in a safe manner:

 eval { ... }

 if ( my $e = Exception::Class->caught('My::Error') )
 {
     cleanup();
     do_something_with_exception($e);
 }

The C<caught()> method returns an exception object if the last thrown
exception is of the given class, or a subclass of that class.
Otherwise it returns false.

You should B<always> make a copy of the exception object, rather than
using C<$@> directly.  This is necessary because if your C<cleanup()>
function uses C<eval>, or calls something which uses it, then C<$@> is
overwritten.  Copying the exception preserves it for the call to
C<do_something_with_exception()>.

=head2 Uncatchable Exceptions

Internally, the C<caught()> method will call C<isa()> on the exception
object.  You could make an exception "uncatchable" by overriding
C<isa()> in that class like this:

 package Exception::Uncatchable;

 sub isa { shift->rethrow }

Of course, this only works if you always call 
C<< Exception::Class->caught() >> after an C<eval>.

=head1 Exception::Class::Base CLASS METHODS

=over 4

=item * Trace($boolean)

Each C<Exception::Class::Base> subclass can be set individually to
include a a stracktrace when the C<as_string> method is called.  The
default is to not include a stacktrace.  Calling this method with a
value changes this behavior.  It always returns the current value
(after any change is applied).

This value is inherited by any subclasses.  However, if this value is
set for a subclass, it will thereafter be independent of the value in
C<Exception::Class::Base>.

This is a class method, not an object method.

=item * NoRefs($boolean)

When a C<Devel::StackTrace> object is created, it walks through the
stack and stores the arguments which were passed to each subroutine on
the stack.  If any of these arguments are references, then that means
that the C<Devel::StackTrace> ends up increasing the refcount of these
references, delaying their destruction.

Since C<Exception::Class::Base> uses C<Devel::StackTrace> internally,
this method provides a way to tell C<Devel::StackTrace> not to store
these references.  Instead, C<Devel::StackTrace> replaces references
with their stringified representation.

This method defaults to true.  As with C<Trace()>, it is inherited by
subclasses but setting it in a subclass makes it independent
thereafter.

=item * RespectOverload($boolean)

When a C<Devel::StackTrace> object stringifies, by default it ignores
stringification overloading on any objects being dealt with.

Since C<Exception::Class::Base> uses C<Devel::StackTrace> internally,
this method provides a way to tell C<Devel::StackTrace> to respect
overloading.

This method defaults to false.  As with C<Trace()>, it is inherited by
subclasses but setting it in a subclass makes it independent
thereafter.

=item * Fields

This method returns the extra fields defined for the given class, as
an array.

=item * throw( $message )

=item * throw( message => $message )

=item * throw( error => $error )

This method creates a new object with the given error message.  If no
error message is given, C<$!> is used.  It then die's with this object
as its argument.

This method also takes a C<show_trace> parameter which indicates
whether or not the particular exception object being created should
show a stacktrace when its C<as_string()> method is called.  This
overrides the value of C<Trace()> for this class if it is given.

The frames included in the trace can be controlled by the C<ignore_class>
and C<ignore_package> parameters. These are passed directly to
Devel::Stacktrace's constructor. See C<Devel::Stacktrace> for more details.

If only a single value is given to the constructor it is assumed to be
the message parameter.

Additional keys corresponding to the fields defined for the particular
exception subclass will also be accepted.

=item * new

This method takes the same parameters as C<throw()>, but instead of
dying simply returns a new exception object.

This method is always called when constructing a new exception object
via the C<throw()> method.

=item * description

Returns the description for the given C<Exception::Class::Base>
subclass.  The C<Exception::Class::Base> class's description is
"Generic exception" (this may change in the future).  This is also an
object method.

=back

=head1 Exception::Class::Base OBJECT METHODS

=over 4

=item * rethrow

Simply dies with the object as its sole argument.  It's just syntactic
sugar.  This does not change any of the object's attribute values.
However, it will cause C<caller()> to report the die as coming from
within the C<Exception::Class::Base> class rather than where rethrow
was called.

Of course, you always have access to the original stacktrace for the
exception object.

=item * message

=item * error

Returns the error/message associated with the exception.

=item * pid

Returns the pid at the time the exception was thrown.

=item * uid

Returns the real user id at the time the exception was thrown.

=item * gid

Returns the real group id at the time the exception was thrown.

=item * euid

Returns the effective user id at the time the exception was thrown.

=item * egid

Returns the effective group id at the time the exception was thrown.

=item * time

Returns the time in seconds since the epoch at the time the exception
was thrown.

=item * package

Returns the package from which the exception was thrown.

=item * file

Returns the file within which the exception was thrown.

=item * line

Returns the line where the exception was thrown.

=item * trace

Returns the trace object associated with the object.

=item * show_trace($boolean)

This method can be used to set whether or not a strack trace is
included when the as_string method is called or the object is
stringified.

=item * as_string

Returns a string form of the error message (something like what you'd
expect from die).  If the class or object is set to show traces then
then the full trace is also included.  The result looks like
C<Carp::confess()>.

=item * full_message

Called by the C<as_string()> method to get the message.  By default,
this is the same as calling the C<message()> method, but may be
overridden by a subclass.  See below for details.

=back

=head1 OVERLOADING

The C<Exception::Class::Base> object is overloaded so that
stringification produces a normal error message.  It just calls the
as_string method described above.  This means that you can just
C<print $@> after an C<eval> and not worry about whether or not its an
actual object.  It also means an application or module could do this:

 $SIG{__DIE__} = sub { Exception::Class::Base->throw( error => join '', @_ ); };

and this would probably not break anything (unless someone was
expecting a different type of exception object from C<die()>).

=head1 OVERRIDING THE as_string METHOD

By default, the C<as_string()> method simply returns the value
C<message> or C<error> param plus a stack trace, if the class's
C<Trace()> method returns a true value or C<show_trace> was set when
creating the exception.

However, once you add new fields to a subclass, you may want to
include those fields in the stringified error.

Inside the C<as_string()> method, the message (non-stack trace)
portion of the error is generated by calling the C<full_message()>
method.  This can be easily overridden.  For example:

  sub full_message
  {
      my $self = shift;

      my $msg = $self->message;

      $msg .= " and foo was " . $self->foo;

      return $msg;
  }

=head1 USAGE RECOMMENDATION

If you're creating a complex system that throws lots of different
types of exceptions, consider putting all the exception declarations
in one place.  For an app called Foo you might make a
C<Foo::Exceptions> module and use that in all your code.  This module
could just contain the code to make C<Exception::Class> do its
automagic class creation.  Doing this allows you to more easily see
what exceptions you have, and makes it easier to keep track of them.

This might look something like this:

  package Foo::Bar::Exceptions;

  use Exception::Class ( Foo::Bar::Exception::Senses =>
                        { description => 'sense-related exception' },

                         Foo::Bar::Exception::Smell =>
                         { isa => 'Foo::Bar::Exception::Senses',
                           fields => 'odor',
                           description => 'stinky!' },

                         Foo::Bar::Exception::Taste =>
                         { isa => 'Foo::Bar::Exception::Senses',
                           fields => [ 'taste', 'bitterness' ],
                           description => 'like, gag me with a spoon!' },

                         ... );

You may want to create a real module to subclass
C<Exception::Class::Base> as well, particularly if you want your
exceptions to have more methods.

=head2 Subclassing Exception::Class::Base

As part of your usage of C<Exception::Class>, you may want to create
your own base exception class which subclasses
C<Exception::Class::Base>.  You should feel free to subclass any of
the methods documented above.  For example, you may want to subclass
C<new()> to add additional information to your exception objects.

=head1 Exception::Class FUNCTIONS

The C<Exception::Class> method offers one function, C<Classes()>,
which is not exported.  This method returns a list of the classes that
have been created by calling the C<Exception::Class> import() method.
Note that this is I<all> the subclasses that have been created, so it
may include subclasses created by things like CPAN modules, etc.  Also
note that if you simply define a subclass via the normal Perl method
of setting C<@ISA> or C<use base>, then your subclass will not be
included.

=head1 OTHER EXCEPTION MODULES (try/catch syntax)

If you are interested in adding try/catch/finally syntactic sugar to
your code then I recommend you check out U. Arun Kumar's C<Error.pm>
module, which implements this syntax.  It also includes its own base
exception class, C<Error::Simple>.

If you would prefer to use the C<Exception::Class::Base> class
included with this module, you'll have to add this to your code
somewhere:

  push @Exception::Class::Base::ISA, 'Error'
      unless Exception::Class::Base->isa('Error');

It's a hack but apparently it works.

=head1 AUTHOR

Dave Rolsky, <autarch@urth.org>

=head1 SEE ALSO

Devel::StackTrace - used by this module to create stack traces

Error.pm - implements try/catch in Perl.  Also provides an exception
base class.

Test::Exception - a module that helps you test exception based code.

Numerous other modules/frameworks seem to have their own exception
classes (SPOPS and Template Toolkit, to name two) but none of these
seem to be designed for use outside of these packages.

=cut
