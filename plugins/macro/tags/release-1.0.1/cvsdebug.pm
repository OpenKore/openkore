# $Header$
#
# package cvsdebug (arachno)
#
# copy this file into your openkore top folder
#
# This source code is licensed under the
# GNU General Public License, Version 2.
# See http://www.gnu.org/licenses/gpl.html

package cvsdebug;

use strict;
use Log qw(message);

sub new {
  my ($class, $file, $debug, @ex) = @_;
  my ($name) = $file =~ /^.*\/(.*)\.pl$/;
  my $self = { name => $name,
               file => $file,
               revision => getRevision($file),
               debug => $debug,
               examine => @ex
             };
  bless ($self, $class);
  message "[$self->{name}] cvsdebug initialized\n", "cvsdebug";
  return $self;
}

sub DESTROY {
  my $self = shift;
  return unless $self->{debug};
  message "[$self->{name}] unloading $self->{file} ".
               "debug level was $self->{debug}, have a nice day.\n", "cvsdebug";
  $self->dump();
}

sub dump {
  my $self = shift;
  message "dumping ..\n", "cvsdebug";
  foreach my $dmp (@{$self->{examine}}) {
    message "parsing $dmp\n", "cvsdebug";
    if (ref($dmp) eq 'ARRAY') {dumpArray(\@{$dmp})}
    elsif (ref($dmp) eq 'HASH') {dumpHash(\%{$dmp})}
    else {message "$$dmp\n", "cvsdebug"};
    message "--\n", "cvsdebug";
  }
}

sub debug {
  my ($self, $message, $level) = @_;
  if ($self->{debug} & $level) {message "[$self->{name}] $message\n", "cvsdebug"}
}

sub setDebug {
  my $self = shift; $self->{debug} = shift if @_;
  message "[$self->{name}] debug level: $self->{debug}\n", "cvsdebug";
}

sub revision {
  my $self = shift; return $self->{revision}
}

sub dumpHash {
  my ($hash, $level) = @_; $level = 0 unless defined $level;
  foreach my $h (keys %{$hash}) {
    message "  "x$level."-> $h\n", "cvsdebug";
    if (ref($$hash{$h}) eq 'ARRAY') {dumpArray(\@{$$hash{$h}}, $level+1)}
    elsif (ref($$hash{$h}) eq 'HASH') {dumpHash(\%{$$hash{$h}}, $level+1)}
    else {message "  "x($level+1)."  $$hash{$h}\n", "cvsdebug"}
  }
}

sub dumpArray {
  foreach my $a (@{$_[0]}) {message "  "x$_[1]." $a\n", "cvsdebug"}
}

sub getRevision {
  my $fname = shift;
  open(F, "< $fname" ) or die "Can't open $fname: $!";
  while (<F>) {
    if (/Header:/) {
       my ($rev) = $_ =~ /.pl,v (.*?) [0-9]{4}/i;
       close F; return $rev;
    }
  }
  close F;
}

1;

__END__

=head1 NAME

cvsdebug - package for debugging openkore plugins

=head1 VERSION

$Revision: 3455 $

=head1 SYNOPSIS

    package whatever;
    use cvsdebug;

    my $cvs = new cvsdebug(
           "/path/to/whatever.pl",
           $level,
           [\%hash, \%hash_of_hashes, \@array, ..]
    );
    ...
    $cvs->debug "message", $level;
    ...
    $cvs->dump();
    ...
    $cvs->setDebug($level);
    ...
    $cvs->getRevision();
    ...
    undef $cvs;

=head1 DESCRIPTION

This package is intented to be a little helper for debugging openkore plugins.

=head2 Initializing the cvsdebug object

=over 4

    my $object = new cvsdebug(args);

Where I<args> are:

=over

=item *

the filename of the plugin you want to debug

=item *

the debug level

=item *

the hashes or arrays you want to dump when destructor is called

=back

=back

=head2 Using cvsdebug

=over 4

=item C<debug($message, $level)>

Sends I<$message> to console if I<$level> is greater or equal to the level specified
either when the object was created or C<setDebug($level)> was called.

=item C<dump()>

Dumps the content of the hashes or arrays specified with C<new>

=item C<setDebug($level)>

Sets debug level to I<$level>.

=item C<getRevision()>

Parses F</path/to/your/plugin.pl> and looks for a cvs C<$Header>. Returns the cvs revision.

=back

=head2 destroying a cvsdebug object

=over 4

Remove the object using C<undef $object>. The destructor will be called which dumps the
contents of the variables/hashes/hashes of hashes/arrays/... given with C<new()>;

=back

=head1 BUGS

The destructor needs some refining.

=head1 AVAILABILITY

Get it via CVS:

C<cvs -d:pserver:anonymous@cvs.sf.net:/cvsroot/openkore login>

C<cvs -d:pserver:anonymous@cvs.sf.net:/cvsroot/openkore co -P macro>

=head1 AUTHOR

Arachno <arachnophobia at users dot sf dot net>

=cut
