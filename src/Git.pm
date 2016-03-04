package Git;

use strict;
use warnings;

use Compress::Zlib;

sub detect_git {
    my ( $file ) = @_;

    my $git_dir = find_git_dir( $file );
    return if !$git_dir;

    my $fp;
    my $head_file = open( $fp, '<', "$git_dir/HEAD" ) && <$fp> =~ /ref: (.*)/ && $1;
    return if !$head_file;

    # The SHA may be in its own file in .git/refs/heads (the normal case), or it may be in .git/packed-refs (right after `git gc`).
    my $sha;
    if ( open $fp, '<', "$git_dir/$head_file" ) {
        $sha = <$fp>;
        close $fp;
        chomp $sha;
    } elsif ( open $fp, '<', "$git_dir/packed-refs" ) {
        while ( <$fp> ) {
            ( $sha ) = /^(\w+) \Q$head_file\E$/;
            last if $sha;
        }
        close $fp;
    }
    return if !$sha;

    my $timestamp = commit_timestamp( git_get_commit( $git_dir, $sha ) );

    return {
        dir       => $git_dir,
        sha       => $sha,
        timestamp => $timestamp,
    };
}

sub commit_timestamp {
    my ( $commit ) = @_;
    return if !$commit;
    return if $commit !~ /^committer (.*) (\d+) [+-]\d+$/ms;
    "$2";
}

# Extract a git commit from either "loose files" or a packfile.
# http://schacon.github.io/gitbook/7_the_packfile.html
sub git_get_commit {
    my ( $git_dir, $sha ) = @_;

    # The simple case: not in a pack file.
    my $loose_path = sprintf '%s/objects/%s/%s', $git_dir, substr( $sha, 0, 2 ), substr $sha, 2;
    if ( -f $loose_path ) {
        open my $fp, '<', $loose_path;
        my $out = git_inflate( $fp );
        close $fp;
        return $out;
    }

    opendir DIR, "$git_dir/objects/pack" or return;
    my $indexes = [ map { chomp;$_; } grep {/\.idx$/} readdir DIR ];
    closedir DIR;
    foreach my $idx ( @$indexes ) {
        next if !open my $idx_fp, "$git_dir/objects/pack/$idx";
        my $head_len = 4 + 4 + 256 * 4;
        my $head     = '';
        read $idx_fp, $head, $head_len;
        next if !$head;
        my ( $magic, $version, @fanout ) = unpack 'a4 N N256', $head;

        if ( $magic ne "\xfftOc" || $version != 2 ) {

            # Uh oh, unknown file magic or version. Hope this works...
            print "Unknown pack file index header.\n";
        }

        my $key = ord pack 'H2', substr $sha, 0, 2;
        my $min = $key ? $fanout[ $key - 1 ] : 0;
        my $max = $fanout[$key];

        my $sha_index;
        seek $idx_fp, $head_len + $min * 20, 0;
        my $packed_commit = pack 'H40', $sha;
        for ( my $i = $min ; $i <= $max && !defined $sha_index ; $i++ ) {
            my $str = '';
            read $idx_fp, $str, 20;
            $sha_index = $i if $str eq $packed_commit;
        }
        next if !defined $sha_index;

        my $offset;
        seek $idx_fp, $head_len + $fanout[255] * ( 20 + 4 ) + $sha_index * 4, 0;
        read $idx_fp, $offset, 4;
        $offset = unpack 'N', $offset;

        # All done with the index file.
        close $idx_fp;

        my $packfile = $idx;
        $packfile =~ s/\.idx$/.pack/;

        my $pack_fp;
        open $pack_fp, '<', "$git_dir/objects/pack/$packfile";

        # Skip type and unpacked size.
        seek $pack_fp, $offset, 0;
        for ( my $i = 0xff ; $i & 0x80 ; $i = ord getc $pack_fp ) { }

        # Extract data.
        return git_inflate( $pack_fp );
    }
}

sub git_inflate {
    my ( $fp ) = @_;

    my $inflate = inflateInit();

    my $out = '';
    my $buf = '';
    while ( !length $buf && read $fp, $buf, 2048 ) {
        $out .= $inflate->inflate( $buf );
    }

    $out;
}

sub git_commit_date {
    my ( $commit ) = @_;
}

# Assume we're somewhere in the checked-out git tree. Hopefully this is true.
sub find_git_dir {
    my ( $dir ) = @_;

    # Convert a file path to a directory.
    $dir =~ s{[^/\\]+$}{} if -f $dir;

    my $c = 40;
    while ( --$c > 0 && opendir DIR, $dir ) {
        my @files = readdir DIR;
        closedir DIR;

        my ( $git_dir ) = grep { $_ eq '.git' } @files;
        return "$dir/$git_dir" if $git_dir;

        $dir = "$dir/..";
    }
}

1;
