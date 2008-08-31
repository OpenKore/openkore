#!/usr/bin/env perl
# Documentation extractor. Extracts documentation from comments from .pm files and put them in HTML files.

use strict;
use warnings;
use File::Spec;
use FindBin;

use Extractor;
use Writer;

our @modules;

open(F, "< modules.txt");
foreach (<F>) {
	s/[\r\n]//;
	next if ($_ eq "");

	my $package = $_;
	my $file = "../$_.pm";
	$file =~ s/::/\//g;
	Extractor::addModule($file, $package);
	push @modules, $package;
}
close F;

foreach (values %Extractor::modules) {
	Writer::writeModuleHTML($_);
}
writeContentTable();



sub error {
	print STDERR "** Error: @_";
}

sub writeContentTable {
	my $html;
	my $f;

	if (!open($f, "< $FindBin::Bin/data/index-template.html")) {
		error "Unable to open $FindBin::Bin/data/index-template.html\n";
		exit 1;
	}
	local($/);
	$html = <$f>;
	close($f);

	sub writeModulesList {
		my ($pattern, $negative) = @_;
		my $list = '';
		foreach my $package (@modules) {
			next unless (defined $pattern && ( (!$negative && $package =~ /$pattern/) || ($negative && $package !~ /$pattern/) ));

			my $file = $Extractor::modules{$package}{htmlFile};
			$list .= "<tr onclick=\"location.href='$file';\">\n" .
				"\t<td class=\"moduleName\"><a href=\"$file\">$package</a></td>\n" .
				"\t<td class=\"moduleDesc\">$Extractor::modules{$package}{name}</td>\n" .
				"</tr>";
		}
		return $list;
	}

	$html =~ s/\@MODIFIED\@/gmtime/ge;
	$html =~ s/\@MODULES\@/&writeModulesList('^(Base|Utils::|Interface::Wx)', 1)/ge;
	$html =~ s/\@UTILS_MODULES\@/&writeModulesList('^(Base|Utils::)')/ge;
	$html =~ s/\@WXMODULES\@/&writeModulesList('^Interface::Wx')/ge;
	if (!open($f, "> srcdoc/index.html")) {
		error "Unable to write to srcdoc/index.html\n";
		exit 1;
	}
	print $f $html;
	close($f);
}
