BEGIN {
    if (!exists $ENV{wx_msw_dark_mode}) {
        $ENV{wx_msw_dark_mode} = 1;
        my $exe = $ENV{PAR_PROGNAME} || $^X;
        exec { $exe } map {
            my $arg = $_;
            $arg =~ s/(\\*)"/$1$1\\"/g;
            $arg =~ s/(\\*)$/$1$1/;
            qq("$arg");
        } ($exe, @ARGV) or die "restart failed: $!";
    }
}
use strict;
use File::Basename qw(dirname);
use File::Spec;
use FindBin;
$ENV{OPENKORE_DEFAULT_INTERFACE} = 'Wx';
$ENV{INTERPRETER} = $ENV{PAR_PROGNAME} || $^X;
my $directory = dirname($ENV{PAR_PROGNAME} || $0);
my $script = File::Spec->catfile($directory, 'openkore.pl');
if (@ARGV && $ARGV[0] eq '!') {
    shift @ARGV;
    while (@ARGV && $ARGV[0] =~ /^-I(.*)/) {
        unshift @INC, $1;
        shift @ARGV;
    }
    $script = shift @ARGV;
}
$0 = $script;
FindBin::again();
my $loaded = do $script;
die $@ || "$script: $!" unless defined $loaded;
main::__start() if defined &main::__start;
