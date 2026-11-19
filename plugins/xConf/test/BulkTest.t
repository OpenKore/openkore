use strict;
use warnings;
use utf8;
use FindBin qw($Bin);
use lib "$Bin/../../../src", "$Bin/../../../src/deps";
use Globals;
use Misc ();
use Commands ();
use Plugins ();
use Settings ();
use FileParsers ();
use File::Temp qw(tempdir);
use JSON::PP;
use Test::More;

my $dir = tempdir(CLEANUP => 1);
Settings::setControlFolders($dir);
my @names = qw(items_control.txt mon_control.txt);
my @handles = (
    Settings::addControlFile("$dir/$names[0]", internalName => $names[0],
        loader => [\&FileParsers::parseItemsControl, \%items_control], autoSearch => 0),
    Settings::addControlFile("$dir/$names[1]", internalName => $names[1],
        loader => [\&FileParsers::parseMonControl, \%mon_control], autoSearch => 0),
);
Plugins::load("$Bin/../xConf.pl");
ok(Plugins::registered('xConf'), 'plugin loads');
my $json = JSON::PP->new->canonical;
sub put {
    my ($name, $text) = @_;
    open my $fh, '>:encoding(UTF-8)', "$dir/$name" or die $!;
    print {$fh} $text;
    close $fh or die $!;
}
sub contents {
    open my $fh, '<:encoding(UTF-8)', "$dir/$_[0]" or die $!;
    local $/; <$fh>;
}
sub fresh {
    %xConf::bulk_cache = ();
    %config = (debug => 0);
    %items_lut = (1 => 'Item1', 2 => 'Item2', 1208 => 'Épée');
    %itemSlotCount_lut = (1208 => 4);
    %monsters_lut = (1 => 'Monster1', 2 => 'Monster2');
    put($names[0], "# kept comment\nall 0 1 0 0 0\n1 0 0 1 0 0\n2 0 0 1 0 0\n");
    put($names[1], "# kept monster comment\nall 0 0 0 0 0 0 0 0 1\n1 1 0 0 0 0 0 0 0 1\n2 1 0 0 0 0 0 0 0 1\n");
    Settings::loadByHandle($_) for @handles;
}
sub apply {
    my ($index, $changes) = @_;
    Plugins::callHook($index ? 'bulk_mconf' : 'bulk_iconf', {changes => $changes});
}
sub matches_core {
    my ($index, $label) = @_;
    my %expected;
    if ($index) { FileParsers::parseMonControl("$dir/$names[$index]", \%expected) }
    else { FileParsers::parseItemsControl("$dir/$names[$index]", \%expected) }
    is($json->encode($index ? \%mon_control : \%items_control), $json->encode(\%expected), $label);
}

subtest 'cold and warm cache agree with complete core parses' => sub {
    fresh();
    for my $i (1 .. 8) {
        apply(0, {1 => "$i 0 1 0 0"});
        matches_core(0, "item update $i");
        apply(1, {1 => ($i % 2).' 0 0 0 0 0 0 0 1'});
        matches_core(1, "monster update $i");
    }
    ok(exists $xConf::bulk_cache{$names[0]}, 'private item cache exists');
    ok(exists $xConf::bulk_cache{$names[1]}, 'private monster cache exists');
    ok(defined $xConf::write_cache{$names[0]}{tail_char_offset}, 'repeated item batch uses tail writes');
    ok(defined $xConf::write_cache{$names[1]}{tail_char_offset}, 'repeated monster batch uses tail writes');
};

subtest 'unchanged direct requests do not write or reload' => sub {
    fresh();
    my $before = contents($names[0]);
    my $reloads = 0;
    my $hook = Plugins::addHook('postloadfiles', sub { $reloads++ });
    apply(0, {1 => '0 0 1 0 0'});
    apply(1, {1 => '1 0 0 0 0 0 0 0 1'});
    is($reloads, 0, 'no reload is dispatched for either unchanged batch');
    is(contents($names[0]), $before, 'no canonicalization write for an unchanged batch');
    Plugins::delHook($hook);
};

subtest 'short bank payloads and interactive commands share the fast writer' => sub {
    fresh();
    apply(0, {1 => '2 1 0'});
    matches_core(0, 'short item payload preserves undefined cart fields');
    my $reloads = 0;
    my $hook = Plugins::addHook('postloadfiles', sub { $reloads++ });
    apply(0, {1 => '2 1 0'});
    is($reloads, 0, 'unchanged short bank payload skips reload');
    Commands::run('iconf 1 3 1 0 0 0');
    is($items_control{1}{keep}, 3, 'interactive item command updates the rule');
    Commands::run('mconf 1 1 0 0 0 5 6 7 8 9');
    is($mon_control{1}{weight}, 9, 'interactive monster command keeps all nine fields');
    my $before = $reloads;
    Commands::run('mconf 1 1 0 0 0 5 6 7 8 9');
    is($reloads, $before, 'unchanged nine-field command skips reload');
    matches_core(0, 'interactive item state equals core');
    matches_core(1, 'interactive monster state equals core');
    Plugins::delHook($hook);
};

subtest 'UTF-8 quoted slotted aliases and duplicate IDs are canonicalized' => sub {
    fresh();
    put($names[0], "\x{FEFF}1208 1 0 0 0 0\r\n# café\r\nall 0 1 0\r\n1208 2 0 0 0 0\r\n  \"Épée [4]\" 3 0 0 0 0\r\n\r\n");
    Settings::loadByHandle($handles[0]);
    apply(0, {1208 => '22 0 0 0 0'});
    my $text = contents($names[0]);
    is(scalar(() = $text =~ /^1208 /mg), 1, 'one canonical ID row');
    unlike($text, qr/^\s*"Épée/m, 'quoted name row removed');
    like($text, qr/# café/, 'UTF-8 comment preserved');
    matches_core(0, 'cold Unicode parse equals core');
    apply(0, {1208 => '23 0 0 0 0'});
    matches_core(0, 'warm Unicode parse equals core');
};

subtest 'cache is isolated from loaded-record mutations and post-load hooks' => sub {
    fresh();
    apply(0, {1 => '1 0 1 0 0'});
    $items_control{2}{keep} = 555;
    apply(0, {1 => '2 0 1 0 0'});
    is($items_control{2}{keep}, 0, 'mutation cannot leak into the private cache');
    my $calls = 0;
    my $hook = Plugins::addHook('pos_load_items_control.txt', sub {
        $calls++;
        $items_control{2}{keep} = 777;
    });
    apply(0, {1 => '3 0 1 0 0'});
    is($calls, 1, 'normal post-load hook runs');
    is($items_control{2}{keep}, 777, 'post-load transformation is visible');
    Plugins::delHook($hook);
    apply(0, {1 => '4 0 1 0 0'});
    is($items_control{2}{keep}, 0, 'post-load transformation did not mutate the cache');
    matches_core(0, 'published state is equivalent to parsing');
};

subtest 'ambiguous legacy names fall back to the core parser' => sub {
    fresh();
    put($names[0], "all 0 1 0\nItem 2 0 1 0 0\nItem10 9 0 1 0 0\n\"Item10\" 4 0 1 0 0\n1 0 0 1 0 0\n");
    Settings::loadByHandle($handles[0]);
    apply(0, {1 => '1 0 1 0 0'});
    matches_core(0, 'first write preserves legacy parsing semantics');
    ok($xConf::write_cache{$names[0]}{unsafe}{item10}, 'ambiguous physical key is tracked');
    $items_lut{10} = 'Item10';
    apply(0, {10 => '5 0 1 0 0'});
    matches_core(0, 'removing aliased rows does not leave stale parsed keys');
    fresh();
    put($names[1], "all 0 0 0 0 0 0 0 0 1\n1 1\t0 0 0 0 0 0 0 1\n2 1 0 0 0 0 0 0 0 1\n");
    Settings::loadByHandle($handles[1]);
    apply(1, {2 => '0 0 0 0 0 0 0 0 1'});
    matches_core(1, 'mixed legacy tab/space identifiers retain core semantics');
    ok($xConf::write_cache{$names[1]}{unsafe}{'1 1'}, 'ambiguous parsed tab key is tracked');
    apply(1, {1 => '1 0 0 0 0 0 0 0 1'});
    matches_core(1, 'removal of mixed-separator row removes its old parsed key');
};

subtest 'identifier projection agrees with both core parsers' => sub {
    my $case = 0;
    for my $line (
        '1 0 1 0', '001 0 1 0', "1\t0 1 0", "1 0\t1 0", ' 1 0 1 0',
        'all 0 1 0', 'Item10 0 1 0', 'Item 2Stone 0 1 0', "Saint's Robe 0 1 0",
        '"Quoted 10" 0 1 0', "'Quoted 10' 0 1 0", '  "Quoted 10" 0 1 0',
        'Épée [4] 0 1 0', "\x{FEFF}1 0 1 0", 'OnlyAName', '10', '# comment',
        "all\t0 1 0", "1 0 1 0\t# comment", 'ItemName -1 0.5 0',
    ) {
        $case++;
        for my $index (0, 1) {
            put($names[$index], "$line\n");
            my %parsed;
            if ($index) { FileParsers::parseMonControl("$dir/$names[$index]", \%parsed) }
            else { FileParsers::parseItemsControl("$dir/$names[$index]", \%parsed) }
            my $key = xConf::_core_control_key($names[$index], $line);
            is_deeply([sort keys %parsed], [defined $key ? $key : ()],
                "core identifier: $names[$index], case $case");
        }
    }
};

subtest 'same-size same-timestamp external edits invalidate the cache' => sub {
    fresh();
    apply(0, {1 => '1 0 1 0 0'});
    my @stat = stat "$dir/$names[0]";
    my $text = contents($names[0]);
    $text =~ s/^2 0 /2 9 /m;
    put($names[0], $text);
    utime $stat[8], $stat[9], "$dir/$names[0]";
    apply(0, {1 => '2 0 1 0 0'});
    is($items_control{2}{keep}, 9, 'external change is retained');
    matches_core(0, 'full refresh after external edit equals core');
};

subtest 'tail byte offsets, shrinking values and non-tail batches remain correct' => sub {
    fresh();
    put($names[0], "# açúcar café\nall 0 1 0 0 0\n1 0 0 1 0 0\n2 0 0 1 0 0\n");
    Settings::loadByHandle($handles[0]);
    for my $value (1, 123456, 7, 89012, 2) {
        apply(0, {1 => "$value 0 1 0 0"});
        matches_core(0, "UTF-8 prefix and value length $value");
    }
    like(contents($names[0]), qr/^# açúcar café/m, 'prefix bytes are preserved');
    apply(0, {2 => '4 0 1 0 0'});
    matches_core(0, 'different non-tail ID falls back correctly');
    apply(0, {1 => '5 0 1 0 0', 2 => '6 0 1 0 0'});
    matches_core(0, 'expanded tail batch is correct');
    my $text = contents($names[0]);
    $text =~ s/\r?\n/\r\n/g;
    put($names[0], "\x{FEFF}".$text);
    apply(0, {1 => '8 0 1 0 0'});
    matches_core(0, 'external BOM and newline changes invalidate byte offsets');
};

subtest 'includes and custom/pre-load hooks retain ordinary loading' => sub {
    fresh();
    put('extra.txt', "2 8 0 1 0 0\n");
    put($names[0], "all 0 1 0\n!include extra.txt\n1 0 0 1 0 0\n");
    Settings::loadByHandle($handles[0]);
    apply(0, {1 => '1 0 1 0 0'});
    ok(!exists $xConf::bulk_cache{$names[0]}, 'includes do not enable the cache');
    is($items_control{2}{keep}, 8, 'included rule loaded');
    put('extra.txt', "2 9 0 1 0 0\n");
    apply(0, {1 => '2 0 1 0 0'});
    is($items_control{2}{keep}, 9, 'included file edits are observed');

    fresh();
    my $calls = 0;
    my $hook = Plugins::addHook('load_items_control.txt', sub {
        my ($name, $args) = @_;
        $calls++;
        %{$args->{args}[0]} = (custom => {keep => 99});
        $args->{return} = 1;
    });
    apply(0, {1 => '1 0 1 0 0'});
    is($calls, 1, 'custom loader called exactly once');
    is($items_control{custom}{keep}, 99, 'custom loader output preserved');
    ok(!exists $xConf::bulk_cache{$names[0]}, 'custom loader does not populate the cache');
    Plugins::delHook($hook);

    fresh();
    $hook = Plugins::addHook('pre_load_items_control.txt', sub {
        my $text = contents($names[0]);
        $text =~ s/^2 0 /2 7 /m;
        put($names[0], $text);
    });
    apply(0, {1 => '1 0 1 0 0'});
    is($items_control{2}{keep}, 7, 'pre-load file mutation observed');
    Plugins::delHook($hook);
};

subtest 'errors remove temporary hooks and preserve invalid input files' => sub {
    fresh();
    my $hook = Plugins::addHook('pos_load_items_control.txt', sub { die "expected test exception\n" });
    eval { apply(0, {1 => '1 0 1 0 0'}) };
    like($@, qr/expected test exception/, 'reload error propagated');
    ok(!Plugins::hasHook('load_items_control.txt'), 'temporary loader hook removed after exception');
    Plugins::delHook($hook);
    matches_core(0, 'completed core state remains valid after observer exception');
    fresh();
    open my $fh, '>:raw', "$dir/$names[0]" or die $!;
    print {$fh} "\xFFinvalid UTF-8\n";
    close $fh;
    eval { apply(0, {1 => '1 0 1 0 0'}) };
    ok(length($@), 'invalid UTF-8 rejected before writing');
    open $fh, '<:raw', "$dir/$names[0]" or die $!;
    my $bytes = do { local $/; <$fh> };
    close $fh;
    is($bytes, "\xFFinvalid UTF-8\n", 'invalid input file remains untouched');
    is($items_control{1}{keep}, 0, 'decode failure leaves loaded state untouched');
};

Settings::removeFile($_) for @handles;
ok(Plugins::unload('xConf'), 'plugin unloads');
ok(!%xConf::bulk_cache, 'unload clears cached file state');
ok(!%xConf::write_cache, 'unload clears writer offsets');
done_testing;
