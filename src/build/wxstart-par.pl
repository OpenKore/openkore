BEGIN {
    delete $ENV{PAR_GLOBAL_TEMP} if delete $ENV{OPENKORE_WX_RESTART_TEMP};
    my $root = delete $ENV{OPENKORE_WX_RESTART_ROOT};
    if (!$root && $^O eq 'MSWin32') {
        $root = eval {
            require Config;
            require Win32::API;
            my $size = $Config::Config{ptrsize} == 8 ? 568 : 556;
            my $parent_offset = $Config::Config{ptrsize} == 8 ? 32 : 24;
            my $entry = pack('L', $size) . "\0" x ($size - 4);
            my $snapshot = Win32::API->new('kernel32', 'CreateToolhelp32Snapshot', 'NN', 'N')->Call(2, 0);
            my $root_pid = 0;
            if ($snapshot && pack('J', $snapshot) ne "\xff" x $Config::Config{ptrsize}) {
                my $first = Win32::API->new('kernel32', 'Process32FirstW', 'NP', 'N');
                my $next = Win32::API->new('kernel32', 'Process32NextW', 'NP', 'N');
                my $found = $first->Call($snapshot, $entry);
                while ($found) {
                    if (unpack('x8L', $entry) == $$) {
                        $root_pid = unpack("x${parent_offset}L", $entry);
                        last;
                    }
                    $found = $next->Call($snapshot, $entry);
                }
                Win32::API->new('kernel32', 'CloseHandle', 'N', 'N')->Call($snapshot);
            }
            $root_pid;
        } || 0;
    }
    $main::OPENKORE_WX_ROOT_PID = $root;
    if (!exists $ENV{wx_msw_dark_mode}) {
        $ENV{wx_msw_dark_mode} = 1;
        if (!exists $ENV{PAR_GLOBAL_TEMP} && $ENV{PAR_TEMP}) {
            $ENV{PAR_GLOBAL_TEMP} = $ENV{PAR_TEMP};
            $ENV{OPENKORE_WX_RESTART_TEMP} = 1;
        }
        $ENV{OPENKORE_WX_RESTART_ROOT} = $root if $root;
        my $exe = $ENV{PAR_PROGNAME} || $^X;
        my $status = system { $exe } map {
            my $arg = $_;
            $arg =~ s/(\\*)"/$1$1\\"/g;
            $arg =~ s/(\\*)$/$1$1/;
            qq("$arg");
        } ($exe, @ARGV);
        die "restart failed: $!" if $status == -1;
        exit($status >> 8);
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
