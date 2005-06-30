package Extractor;

use strict;
use warnings;

our %modules;
our %functions;


sub error {
	print STDERR "** Error: @_";
}

sub initItem {
	my $hash = shift;
	$hash->{params} = [];
	$hash->{name} = '';
	$hash->{desc} = '';
	$hash->{example} = '';
	$hash->{returns} = '';
}


# Extractor::addModule(file, package)
# Extract documentation from a Perl module.
sub addModule {
	my $file = shift;
	my $package = shift;

	if (!open(F, "< $file")) {
		error "Unable to open $file for reading.\n";
		return 0;
	}
	binmode F;

	my $linenum = 0;
	my $state = 'ready';
	my %module = (
		package => $package,
		name => '',
		desc => '',
		items => {},
		categories => {},
		file => $file
		);
	my %item;
	my $category = '';
	initItem(\%item);

	foreach my $line (<F>) {
		$linenum++;
		$line =~ s/\r//g;

		if ($line !~ /^#/) {
			if ($state =~ /^function-/ && $item{name} ne '') {
				# The end of a function description has been reached
				my %copy = %item;
				$copy{desc} =~ s/\n+$//s;
				$copy{example} =~ s/\n+$//s;
				$copy{package} = $package;
				$copy{category} = $category;

				$module{items}{$copy{name}} = \%copy;
				$module{categories}{$category}{$copy{name}} = \%copy;
				$functions{$copy{name}} = \%copy;
			}

			%item = ();
			initItem(\%item);
			$state = 'ready';
			next;
		}

		if ($state eq 'ready') {
			# Ready to accept the beginning of documentation comments.
			# Look for lines that start with '##'.
			if ($line eq "##\n") {
				$state = 'start';
			} elsif ($line =~ /^### CATEGORY: (.+)$/) {
				$category = $1;
				$state = 'category';
			}

		} elsif ($state eq 'start') {
			# Reading first line of a documentation comment.
			if ($line =~ /^# MODULE DESCRIPTION: (.+)/) {
				# This comment block is a module description
				$module{name} = $1 if ($1);
				$state = 'module-description';

			} else {
				# This is a function description
				($item{name}, $item{param_declaration}) = $line =~ /^# ([a-z0-9_:\$\->{}]+) *(\(.*\))?/i;
				$item{param_declaration} = '' if (!defined $item{param_declaration});
				$state = 'function-params';
			}

		} elsif ($state eq 'module-description') {
			$line =~ s/^# ?//;
			next if ($line eq "\n" && length($module{desc}) == 0);
			$module{desc} .= $line;

		} elsif ($state eq 'function-params') {
			$line =~ s/^# ?//;
			if ($line eq "\n") {
				# We have reached an empty line. This means there
				# are no parameter descriptions left to read.
				# The next line is the function description.
				$state = 'function-description';

				# The "Returns" parameter deserves special treatment.
				my $i = 0;
				foreach my $param (@{$item{params}}) {
					if ($param->[0] eq 'Returns') {
						$item{returns} = $param->[1];
						delete $item{params}[$i];
						last;
					}
					$i++;
				}

			} else {
				# Process parameter
				$line =~ s/\n//;
				if (index($line, ':') == -1) {
					# A ':' character is missing.
					if (@{$item{params}} == 0) {
						# This is an invalid parameter description.
						error "\"$line\" ($file line $linenum) is not a valid parameter description.\n";

					} else {
						# This is part of the previous parameter description.
						$item{params}[$#{$item{params}}][1] .= $line;
					}
					next;
				}

				my ($param, $desc) = split(/ *: */, $line, 2);
				push @{$item{params}}, [$param, $desc];
			}

		} elsif ($state eq 'function-description') {
			$line =~ s/^# ?//;
			next if ($line eq "\n" && length($item{desc}) == 0);

			if ($line eq "Example:\n") {
				$state = 'function-example';
				next;
			}
			$item{desc} .= $line;

		} elsif ($state eq 'function-example') {
			$line =~ s/^# ?//;
			$item{example} .= $line;
		}
	}
	close(F);

	$modules{$package} = \%module;
	return 1;
}

1;
