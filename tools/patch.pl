#!/usr/bin/perl -w

use strict;
use warnings;

use Date::Manip;
use Encode;
use File::Copy;
use Getopt::Long;
use LWP::UserAgent;
use Net::FTP;
use YAML::Syck;

$|++;

my $ua = LWP::UserAgent->new;

my $opt = get_options(
    {
        allow_url         => 'http://patch.1.online.ragnarok.warpportal.net/patch02/patch_allow.txt',
        list_url          => 'http://patch.1.online.ragnarok.warpportal.net/patch02/patch2.txt',
        download_base_url => 'ftp://ropatch2.gravityus.com/patch',
        git_dir           => "$ENV{HOME}/git/openkore/tables/iRO/official",
        download_dir      => "$ENV{HOME}/patches",
    }, {
        'allow_url=s'         => 'the "is patching currently allowed" URL',
        'check_files'         => 'force re-check of previously downloaded files',
        'download_base_url=s' => 'FTP URL to the patch server',
        'download_dir=s'      => 'directory for temporary downloaded files',
        'force|f'             => 'force download even if the allow-url says we are not allowed to',
        'git_dir=s'           => 'the files OpenKore cares about will be placed in this directory',
        'list_url=s'          => 'URL to the list of patch files',
    }
);

if ( !patch_allowed() ) {
    print "Patching is not currently allowed. You may use --force to force patching.\n";
    exit;
}

if ( !grep { -f "$_/grf_extract" } split ':', $ENV{PATH} ) {
    print "This program requires grf_extract. Please make sure it is in your \$PATH.\n";
    print "grf_extract is available at https://github.com/allanon/grf\n";
    exit;
}

mkdir $opt->{download_dir};

print 'Checking patch list... ';
my $patches = patch_list();
printf "done. Found [%d] patches.\n", scalar @$patches;

if ( $opt->{check_files} ) {
    print "Checking whether files have changed on the server.\n";
    foreach ( @$patches ) {
        my $file = "$opt->{download_dir}/$_";

        next if !-f $file;

        if ( ftp_data( $_ )->{size} && -s $file != ftp_data( $_ )->{size} ) {
            print "File [$_] has changed size. Renaming to [$_.bak] and downloading a new copy.\n";
            rename $file => "$file.bak";
            unlink "$file.yml";
        } elsif ( ftp_data( $_ )->{time} && ftp_data( $_ )->{time} != ( stat( $file ) )[9] ) {
            print "File [$_] has changed modification date. Renaming to [$_.bak] and downloading a new copy.\n";
            rename $file => "$file.bak";
            unlink "$file.yml";
        }
    }
}

my $recent_patches = [ ( reverse @$patches )[ 0 .. 20 ] ];

my $downloaded = 0;
foreach ( reverse @$recent_patches ) {
    my $url  = "$opt->{download_base_url}/$_";
    my $file = "$opt->{download_dir}/$_";

    next if -f $file;

    unlink "$file.yml";

    print "Downloading file [$file]... ";
    $ua->get( $url, ':content_file' => $file );
    print "done.\n";

    my $time = ftp_data( $_ )->{time};
    utime $time, $time, $file;
    $downloaded++;
}
print "No new files found.\n" if !$downloaded;

# Extract file lists from each gpf.
foreach ( reverse @$recent_patches ) {
    my $file = "$opt->{download_dir}/$_";

    next if $file !~ /\.g[pr]f$/o;
    next if !-f $file;
    next if -f "$file.yml";

    # Extract file list.
    my $data = backticks( 'grf_extract', $file );
    my @lines = split /\n/, $data;

    shift @lines;    # Loading GRF: ...
    shift @lines;    # # of files: ...

    my $files = { map {/^  (.*) \((\d+)\)/o} @lines };
    YAML::Syck::DumpFile( "$file.yml", $files );
}

# Merge the gpf file lists together to find the latest version of each file.
my $latest = {};
foreach my $p ( reverse @$patches ) {
    my $yml = "$opt->{download_dir}/$p.yml";

    next if !-f $yml;

    my $files = YAML::Syck::LoadFile( $yml );
    $latest->{$_} ||= $p foreach keys %$files;
}
YAML::Syck::DumpFile( "$opt->{download_dir}/latest.yml", $latest );

# Extract the latest version of interesting files.
my $extracted = eval { YAML::Syck::LoadFile( "$opt->{download_dir}/extracted_files.yml" ) } || {};
my $extract_dir = "$opt->{download_dir}/extracted_files";
mkdir $extract_dir if !-d $extract_dir;
foreach ( sort keys %$latest ) {
    next if !/\.txt$/;

    next if $extracted->{$_} && $latest->{$_} eq $extracted->{$_};
    my ( $base ) = m{([^/\\]+)$};
    system 'grf_extract', "$opt->{download_dir}/$latest->{$_}", $_ => "$extract_dir/$base";

    # GRF files typically have a screwed up mix of UCS-2 and UTF-8. Fix them.
    fix_unicode( "$extract_dir/$base" );

    $extracted->{$_} = $latest->{$_};
}
YAML::Syck::DumpFile( "$opt->{download_dir}/extracted_files.yml", $extracted );

# Copy the files into the git directory.
my $map = {
    'idnum2itemdesctable.txt'        => 'itemsdescriptions.txt',
    'idnum2itemdisplaynametable.txt' => 'items.txt',
    'itemslotcounttable.txt'         => 'itemslotcounttable.txt',
    'mapnametable.txt'               => 'maps.txt',
    'quests.txt'                     => 'quests.txt',
    'resnametable.txt'               => 'resnametable.txt',
    'skillnametable.txt'             => 'skillnametable.txt',
};
foreach ( sort keys %$map ) {
    printf "Copying [%s] to [%s].\n", $_, $map->{$_};
    File::Copy::cp "$extract_dir/$_" => "$opt->{git_dir}/$map->{$_}";
}

sub patch_allowed {
    $opt->{force} || $ua->get( $opt->{allow_url} )->content eq 'allow';
}

sub patch_list {
    [ grep {$_} map { m{^(\d+)\s+([^/\s]+)$} && $2 } split /[\r\n]+/, $ua->get( $opt->{list_url} )->content ];
}

sub ftp;

sub ftp {
    our $ftp;
    if ( !$ftp ) {
        my $uri = URI->new( $opt->{download_base_url} );
        $ftp = Net::FTP->new( $uri->host );
        $ftp->login;
        $ftp->cwd( $uri->path );
    }
    $ftp;
}

sub ftp_data {
    our $ftp_data_cache ||= {};
    $ftp_data_cache->{ $_[0] } ||= {    #
        time => ftp->mdtm( $_[0] ) || 0,
        size => ftp->size( $_[0] ) || 0,
    };
}

sub backticks {
    my ( @cmd ) = @_;

    my $pid = open( my $fp, '-|' );

    if ( !$pid ) {
        ( $>, $) ) = ( $<, $( );
        exec( @cmd ) || die "Unable to exec program @cmd: $!\n";
    }

    local $/;
    my $output = <$fp>;
    close( $fp );

    $output;
}

sub fix_unicode {
    my ( $file ) = @_;

    # Regular expressions to match the full UTF-8 spec and the UCS-2 part of UTF-16BE.
    my $ascii = qr/[\x00-\x7E]/;
    my $utf8  = qr/
          [\x09\x0A\x0D\x20-\x7E]            # ASCII
        | [\xC2-\xDF][\x80-\xBF]             # non-overlong 2-byte
        |  \xE0[\xA0-\xBF][\x80-\xBF]        # excluding overlongs
        | [\xE1-\xEC\xEE\xEF][\x80-\xBF]{2}  # straight 3-byte
        |  \xED[\x80-\x9F][\x80-\xBF]        # excluding surrogates
        |  \xF0[\x90-\xBF][\x80-\xBF]{2}     # planes 1-3
        | [\xF1-\xF3][\x80-\xBF]{3}          # planes 4-15
        |  \xF4[\x80-\x8F][\x80-\xBF]{2}     # plane 16
    /x;
    my $ucs2 = qr/
          [\x7F-\xD7\xE0-\xFF][\x00-\xFF]    # 2-byte
    /x;

    # Read the GRF file.
    local $/;
    open FP, '<', $file;
    my $data = <FP>;
    close FP;

    # Eat the leading BOM, if any.
    $data =~ s/^[\xFF\xFE]{2}//gos;

    # Convert CRLF to just LF.
    $data =~ s/\r\n/\n/gos;

    # Convert data from mixed UTF-8 and UTF-16BE to just UTF-8.
    $data = join "\n", map { s/($ascii*)($ucs2+)/Encode::decode('UTF-8', "$1").Encode::decode('UTF-16BE', "$2")/egos;$_; } split "\n", $data;

    # Ensure exactly one trailing newline.
    $data =~ s/\n*$/\n/os;

    # Write the file out.
    open FP, '>', $file;
    binmode( FP, ':utf8' );
    print FP $data;
    close FP;
}

sub get_options {
    my ( $opt_def, $opt_str ) = @_;

    # Add some default options.
    $opt_str = {
        'help|h' => 'this help',
        %$opt_str,
    };

    # Auto-convert underscored long names to dashed long names.
    foreach ( keys %$opt_str ) {
        my ( $name, $type ) = split '=';
        my @opts = split /\|/, $name;
        my ( $underscored ) = grep {/_/} @opts;
        my ( $dashed )      = grep {/-/} @opts;
        if ( $underscored && !$dashed ) {
            $dashed = $underscored;
            $dashed =~ s/_/-/g;
            splice @opts, ( length( $opts[-1] ) == 1 ? $#opts : @opts ), 0, $dashed;
            my $key = join '|', @opts;
            $key .= "=$type" if $type;
            $opt_str->{$key} = $opt_str->{$_};
            delete $opt_str->{$_};
        }
    }

    my $opt = {%$opt_def};
    my $success = GetOptions( $opt, keys %$opt_str );
    usage( $opt_def, $opt_str ) if $opt->{help} || !$success;

    $opt;
}

sub usage {
    my ( $opt_def, $opt_str ) = @_;
    my $maxlen = 0;
    my $opt    = {};
    foreach ( keys %$opt_str ) {
        my ( $name, $type ) = split '=';
        my ( $var ) = split /\|/, $name;
        my ( $long ) = reverse grep { length $_ != 1 } split /\|/, $name;
        my ( $short ) = grep { length $_ == 1 } split /\|/, $name;
        $maxlen = length $long if $long && $maxlen < length $long;
        $opt->{ $long || $short || '' } = {
            short   => $short,
            long    => $long,
            desc    => $opt_str->{$_},
            default => $opt_def->{$var}
        };
    }
    print "Usage: $0 [options]\n";
    foreach ( map { $opt->{$_} } sort keys %$opt ) {
        printf "  %2s %-*s  %s%s\n",    #
            $_->{short} ? "-$_->{short}" : '', $maxlen + 2, $_->{long} ? "--$_->{long}" : '', $_->{desc}, $_->{default} ? " (default: $_->{default})" : "";
    }
    exit;
}

