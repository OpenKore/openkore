#!/usr/bin/env perl
use strict;
use Config;
use File::Spec;

my $lines;
open(F, "< Makefile.in");
$lines = join('', <F>);
$lines =~ s/[\r\n]/\n/g;
close F;

sub convertPath {
	my $str = shift;
	$str =~ s/\\/\//g;
	return $str;
}

sub search {
	my $paths = shift;
	my $file = shift;
	foreach (@{$paths}) {
		if (-f "$_/$file") {
			return "$_/$file";
			last;
		}
	}
	return;
}

my $win32 = ($^O eq "cygwin" || $^O eq "MSWin32");
my $CYGWIN = ($win32) ? "-mno-cygwin -mdll -DWIN32" : "";
my $DLLWRAP = ($win32) ?
		'dllwrap -mno-cygwin --driver=$(CXX) --target=i386-mingw32 --def symbols.gccdef' :
		'$(CXX) -shared -fPIC';
my $DLLEXT = ($win32) ? "dll" : "so";
my $PERL = convertPath $Config{perlpath};
my $XSUBPP = '$(PERL) ' . convertPath(search(\@INC, "ExtUtils/xsubpp") || search([File::Spec->path()], "xsubpp"));
my $TYPEMAP = convertPath search(\@INC, "ExtUtils/typemap");
my $COREDIR = convertPath "$Config{installarchlib}/CORE";
my $PERLCFLAGS = ($win32) ?
		'-Wno-unused -Wno-implicit -D__MINGW32__ -D_INTPTR_T_DEFINED -D_UINTPTR_T_DEFINED' :
		'-fPIC -Wno-unused -Wno-implicit -D_REENTRANT -D_GNU_SOURCE -DTHREADS_HAVE_PIDS -D_LARGEFILE_SOURCE -D_FILE_OFFSET_BITS=64';
my $LIBPERL = ($win32) ? "$COREDIR/perl58.lib" : "";
my $SOCFLAGS = ($win32) ? "" : "-fPIC";

my $header = <<EOF;
CYGWIN=$CYGWIN
DLLWRAP=$DLLWRAP
DLLEXT=$DLLEXT

PERL=$PERL
XSUBPP=$XSUBPP
TYPEMAP=$TYPEMAP
COREDIR=$COREDIR
PERLCFLAGS=$PERLCFLAGS
LIBPERL=$LIBPERL
SOCFLAGS=$SOCFLAGS
EOF

$lines =~ s/\n\tdlltool.*?\n/\n/s if (!$win32);
$lines =~ s/\@HEADER\@/$header/s;

sub replaceIfUnix {
	return ($^O eq "MSWin32" || $^O eq "cygwin") ? "\n" : "\n$_[0]\n";
}
sub replaceIfWin32 {
	return ($^O eq "MSWin32" || $^O eq "cygwin") ? "\n$_[0]\n" : "\n";
}
$lines =~ s/\n#if unix\n(.*?)\n#endif\n/&replaceIfUnix($1)/seg;
$lines =~ s/\n#if win32\n(.*?)\n#endif\n/&replaceIfWin32($1)/seg;

open(F, "> Makefile.real");
print F $lines;
close(F);
