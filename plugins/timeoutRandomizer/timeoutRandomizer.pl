#####################################################################
# timeoutRandomizer - Range values for timeouts.txt.				#
# by @billabong93													#
#####################################################################

package OpenKore::Plugins::timeoutRandomizer;

use strict;
use warnings;

use File::Basename qw(dirname);
use File::Spec::Functions qw(catdir rel2abs);

BEGIN {
        my $plugin_dir = dirname(__FILE__);
        my $root_dir   = dirname(dirname($plugin_dir));

        my $src_dir  = rel2abs(catdir($root_dir, 'src'));
        my $deps_dir = rel2abs(catdir($src_dir, 'deps'));

        foreach my $path ($src_dir, $deps_dir) {
                next unless defined $path && -d $path;
                unshift @INC, $path unless grep { $_ eq $path } @INC;
        }
}

use Globals qw(%timeout);
use Log qw(message warning);
use Plugins;
use Scalar::Util qw(looks_like_number);
use Settings;
use Utils ();

our $VERSION = '1.0';

my %configured_ranges;
my $control_handle;
my $hooks;
my %missing_reported;
my $orig_timeOut;
my $override_installed = 0;
my $stateless_tick = 0;

BEGIN {
        $orig_timeOut = Utils->can('timeOut');
}

sub _original_timeout_sub {
        $orig_timeOut ||= Utils->can('timeOut');

        unless ($orig_timeOut) {
                warning "[timeoutRandomizer] Could not locate Utils::timeOut; plugin is disabled.\n";
        }

        return $orig_timeOut;
}

Plugins::register('timeoutRandomizer', 'Randomize configured timeouts within ranges', \&unload, \&reload);

$hooks = Plugins::addHooks(
        ['pos_load_timeouts.txt', \&on_timeouts_loaded, undef],
        ['start3',                \&on_start,           undef],
        ['AI_pre',                \&observe_timeouts,   undef],
);

sub on_start {
        if (!defined $control_handle) {
                $control_handle = Settings::addControlFile('timeout_randomizer.txt',
                        loader => [\&load_range_file], mustExist => 0, autoSearch => 1);
        }

        Settings::loadByHandle($control_handle) if defined $control_handle;
        apply_ranges();
}

if (_original_timeout_sub()) {
        no warnings 'redefine';
        *Utils::timeOut = sub ($;$) {
                my ($r_time, $timeout_value) = @_;
                my $original = _original_timeout_sub();
                return unless $original;

                unless (defined $r_time) {
                        warning "[timeoutRandomizer] Utils::timeOut called with undefined r_time.\n";
                        return;
                }

                my $meta = ref($r_time) eq 'HASH' ? $r_time->{timeout_randomizer} : undef;

                if ($meta) {
                        $meta->{stateful} = 1;
                        delete $meta->{last_stateless_tick};

                        _ensure_seed($r_time, $meta);

                        my $result = @_ > 1
                                ? $original->($r_time, $timeout_value)
                                : $original->($r_time);

                        if ($result) {
                                _assign_random_timeout($r_time, $meta);
                        }

                        return $result;
                }

                return @_ > 1
                        ? $original->($r_time, $timeout_value)
                        : $original->($r_time);
        };
        $override_installed = 1;
}

sub load_range_file {
        my ($file) = @_;

        %configured_ranges = ();

        unless (defined $file && -f $file) {
                message "[timeoutRandomizer] No timeout_randomizer.txt found; plugin is idle.\n", 'system';
                return 1;
        }

        open my $fh, '<', $file or do {
                warning sprintf "[timeoutRandomizer] Could not read %s: %s\n", $file, $!;
                return 0;
        };

        my $line_no = 0;
        while (my $line = <$fh>) {
                $line_no++;
                $line =~ s/\x{FEFF}//g;
                $line =~ s/#.*$//;
                $line =~ s/^\s+//;
                $line =~ s/\s+$//;
                next unless length $line;

                my ($name, $rest) = $line =~ /^(\S+)\s*(.*)$/;
                unless (defined $name && length $name) {
                        warning sprintf "[timeoutRandomizer] Invalid line %d in %s\n", $line_no, $file;
                        next;
                }

                my ($min, $max) = _parse_range($rest // '');
                unless (defined $min && defined $max) {
                        warning sprintf "[timeoutRandomizer] Invalid range for '%s' on line %d in %s\n", $name, $line_no, $file;
                        next;
                }

                $configured_ranges{$name} = { min => $min, max => $max };
        }

        close $fh;

        apply_ranges();

        return 1;
}

sub _parse_range {
        my ($expr) = @_;
        return unless defined $expr;

        my $normalized = $expr;
        $normalized =~ s/\.\./ /g;
        $normalized =~ s/,/ /g;
        $normalized =~ s/\s+/ /g;
        $normalized =~ s/^\s+//;
        $normalized =~ s/\s+$//;

        return unless length $normalized;

        my @parts = split /\s+/, $normalized;
        if (@parts == 1) {
                return _validate_number($parts[0]), _validate_number($parts[0]);
        }

        my ($min, $max) = @parts[0, 1];
        $min = _validate_number($min);
        $max = _validate_number($max);

        return unless defined $min && defined $max;

        return ($min, $max);
}

sub _validate_number {
        my ($value) = @_;
        return unless defined $value;
        return unless looks_like_number($value);

        $value = 0 + $value;
        $value = 0.1 if $value <= 0;
        return $value;
}

sub on_timeouts_loaded {
        apply_ranges();
}

sub apply_ranges {
        foreach my $name (keys %configured_ranges) {
                my $entry = $timeout{$name};
                if (ref $entry eq 'HASH') {
                        my ($min, $max) = @{ $configured_ranges{$name} }{qw(min max)};
                        ($min, $max) = ($max, $min) if defined $min && defined $max && $max < $min;

                        my $meta = $entry->{timeout_randomizer} ||= {};
                        @$meta{qw(min max name)} = ($min, $max, $name);
                        delete @$meta{qw(initialized last_value last_reset_time last_stateless_tick)};

                        _ensure_seed($entry, $meta);

                        delete $missing_reported{$name};
                } else {
                        next if $missing_reported{$name};
                        warning sprintf "[timeoutRandomizer] Timeout '%s' is not defined in timeouts.txt; waiting for it to become available.\n", $name;
                        $missing_reported{$name} = 1;
                }
        }

        foreach my $name (keys %timeout) {
                next if exists $configured_ranges{$name};
                my $entry = $timeout{$name};
                next unless ref $entry eq 'HASH';
                delete $entry->{timeout_randomizer};
                delete $missing_reported{$name};
        }
}

sub observe_timeouts {
        $stateless_tick++;

        foreach my $name (keys %configured_ranges) {
                my $entry = $timeout{$name};
                next unless ref $entry eq 'HASH';

                my $meta = $entry->{timeout_randomizer};
                next unless $meta;

                _ensure_seed($entry, $meta);

                if ($meta->{stateful}) {
                        if (exists $entry->{time}) {
                                my $time_mark = $entry->{time};

                                if (!defined $time_mark) {
                                        delete $meta->{last_reset_time};
                                        next;
                                }

                                if (!defined $meta->{last_reset_time} || $meta->{last_reset_time} != $time_mark) {
                                        _assign_random_timeout($entry, $meta);
                                        $meta->{last_reset_time} = $time_mark;
                                }
                        } else {
                                delete $meta->{last_reset_time};
                        }
                        next;
                }

                next if defined $meta->{last_stateless_tick} && $meta->{last_stateless_tick} == $stateless_tick;

                _assign_random_timeout($entry, $meta);
                $meta->{last_stateless_tick} = $stateless_tick;
        }
}

sub _ensure_seed {
        my ($entry, $meta) = @_;

        return unless $meta;

        unless ($meta->{initialized}) {
                _assign_random_timeout($entry, $meta);
                $meta->{initialized} = 1;
        }
}

sub _assign_random_timeout {
        my ($entry, $meta) = @_;

        return unless $meta;

        my ($min, $max) = @$meta{qw(min max)};
        return unless defined $min && defined $max;
        ($min, $max) = ($max, $min) if $max < $min;

        my $value = $min;
        if ($max > $min) {
                my $span = $max - $min;
                $value = $min + rand() * $span;

                my $epsilon = $span * 1e-12;
                $epsilon = 1e-12 if $epsilon <= 0;
                $value = $max if $value > $max - $epsilon;
        }

        $entry->{timeout} = $value;
        $meta->{last_value} = $value;
}

sub reload {
        Settings::loadByHandle($control_handle) if defined $control_handle;
        apply_ranges();
}

sub unload {
        Plugins::delHooks($hooks) if $hooks;
        Settings::removeFile($control_handle) if defined $control_handle;

        if ($override_installed) {
                no warnings 'redefine';
                *Utils::timeOut = $orig_timeOut;
                $override_installed = 0;
        }
}

1;