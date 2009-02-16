package Attribute::Overload;

use warnings;
use strict;
use Attribute::Handlers;

our $VERSION = '0.04';


# RAWDATA to get '""' as such;
# CODE would interpret it as empty string and return nothing

sub UNIVERSAL::Overload : ATTR(CODE,RAWDATA) {
	my ($pkg, $symbol, $data) = @_[0,1,4];
	our %overload;
	for (ref $data eq 'ARRAY' ? @$data : $data) {
		die "Too late to overload constant $_ in CHECK for $symbol\n"
		    if /^(integer|float|binary|qr?)$/;
		s!\"\"!""!g;
		$overload{$pkg}{$_} = *{$symbol}{NAME};
	}
}


sub INIT {
	# only eval here, because multiple overloaded subs must only
	# trigger one 'use overload' statement
	our %overload;

	my $code;

	while (my ($pkg, $pkgdef) = each %overload) {
		my (@code, @constcode);
		while (my ($op, $sub) = each %$pkgdef) {
			if ($op =~ /^(integer|float|binary|qr?)$/) {
				push @constcode => "$op => \\&$sub";
			} else {
				push @code => "'$op' => \\&$sub";
			}
		}
		next unless @code || @constcode;  # huh? no defs?
		$code .= "package $pkg;\n";
		$code .= "use overload\n" . join(",\n" => @code) . ";\n"
		    if @code;

		# Note: the following doesn't do anything, since import()
		# is called at BEGIN via use(), but attributes are only
		# evaluated during CHECK. So it's commented out for now.

		# $code .= "BEGIN { sub import { overload::constant (\n" .
		#     join(",\n" => @constcode) . ")}};\n" if @constcode;
	}

	eval $code if $code;
	die $@ if $@;
}


1;


__END__

=head1 NAME

Attribute::Overload - Attribute that makes overloading easier

=head1 SYNOPSIS

  use Attribute::Overload;
  sub add : Overload(+) { ... }

=head1 DESCRIPTION

The C<Overload> attribute, when used on a subroutine, declares that subroutine
as the handler in the current package for the operation(s) indicated by the
attribute options. Thus it frees you from the implementation details of how to
declare overloads and keeps the definitions where they belong, with the
operation handlers.

For details of which operations can be overloaded and what the overloading
function gets passed see the L<overload> manpage.

Note that you can't overload constants this way, since this has to happen
during BEGIN time, but attributes are only evaluated at CHECK time, at least
as far as L<Attribute::Handlers> is concerned.

=head1 TAGS

If you talk about this module in blogs, on del.icio.us or anywhere else,
please use the C<attributeoverload> tag.

=head1 BUGS AND LIMITATIONS

No bugs have been reported.

Please report any bugs or feature requests to
C<bug-attribute-overload@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org>.

=head1 INSTALLATION

See perlmodinstall for information and options on installing Perl modules.

=head1 AVAILABILITY

The latest version of this module is available from the Comprehensive Perl
Archive Network (CPAN). Visit <http://www.perl.com/CPAN/> to find a CPAN
site near you. Or see <http://www.perl.com/CPAN/authors/id/M/MA/MARCEL/>.

=head1 AUTHOR

Marcel GrE<uuml>nauer, C<< <marcel@cpan.org> >>

=head1 COPYRIGHT AND LICENSE

Copyright 2001-2007 by Marcel GrE<uuml>nauer

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

