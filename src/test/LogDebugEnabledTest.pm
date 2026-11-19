package LogDebugEnabledTest;
use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);
use Log ();
use Settings ();

sub start {
    no warnings 'once';
    local %Log::config;
    local @Log::hooks;
    local %Log::debugFiles;
    local %Log::debugConsole;
    local $Log::interface=bless {output=>[],beeps=>0},'LogDebugEnabledTest::Interface';
    my $interface=$Log::interface;
    my $builds=0;
    my $emit=sub {
        my ($domain,$level)=@_;
        Log::debug(do {$builds++; "fixture\n"},$domain,$level) if Log::debugEnabled($domain,$level);
    };
    %Log::config=(debug=>0);
    $emit->('eventMacro',3);
    is($builds,0,'suppressed message never constructed');
    is_deeply($interface->{output},[],'suppressed console output unchanged');
    $Log::config{debugDomains}='eventMacro,route';
    $emit->('eventMacro',3); $emit->('route',2);
    is($builds,2,'debugDomains bypasses the numeric verbosity');
    is(scalar @{$interface->{output}},2,'domain-enabled messages emitted');
    $Log::config{squelchDomains}='eventMacro';
    ok(!Log::debugEnabled('eventMacro',3),'squelch takes precedence over debugDomains');
    $Log::config{debug}=5;
    ok(Log::debugEnabled('eventMacro',3),'squelch raises level to five instead of dropping messages');
    %Log::config=(debug=>2);
    ok(Log::debugEnabled('route',2),'equal numeric level included');
    ok(!Log::debugEnabled('route',3),'higher level excluded');
    ok(Log::debugEnabled('route',undef),'default level is one');
    %Log::config=(debug=>'');
    ok(Log::debugEnabled('route',1),'empty debug setting follows processMsg default one');
    ok(!Log::debugEnabled('route',2),'empty setting does not enable level two');
    %Log::config=();
    ok(!Log::debugEnabled('route',1),'undefined debug means zero');
    $Log::config{debugDomains}='console';
    ok(Log::debugEnabled(undef,3),'default domain is console');

    %Log::config=(debug=>0);
    my @observed;
    local @Log::hooks=(
        {func=>sub {push @observed,[@_[0..4]]}},
        {func=>sub {push @observed,['second']}});
    $emit->('route',3);
    is_deeply(\@observed,[['debug','route',3,0,"fixture\n"],['second']],
        'suppressed messages retain hook arguments and callback order');
    @Log::hooks=();
    ok(!Log::debugEnabled('route',3),'hook removal takes effect immediately');

    my $dir=tempdir(CLEANUP=>1);
    local $Settings::logs_folder=$dir;
    local $Log::logTimestamp=0;
    $Log::debugFiles{route}=['fixture.txt'];
    $emit->('route',3);
    open my $fh,'<',"$dir/fixture.txt" or die $!;
    is(do {local $/; <$fh>},"fixture\n",'domain file receives messages below console verbosity');
    close $fh;
    delete $Log::debugFiles{route};
    ok(!Log::debugEnabled('route',3),'destination removal takes effect immediately');
    $Log::config{beepDomains}='route';
    $emit->('route',3);
    is($interface->{beeps},1,'beep is preserved below console verbosity');
    delete $Log::config{beepDomains};
    $Log::config{debug}=2;
    $Log::debugConsole{route}=0;
    ok(Log::debugEnabled('route',2),'console bookkeeping is conservatively retained for accepted levels');
    $Log::config{debug}=0;
    ok(!Log::debugEnabled('route',2),'runtime verbosity changes observed without cache invalidation');


}

package LogDebugEnabledTest::Interface;
sub writeOutput {push @{$_[0]{output}},[@_[1..3]]}
sub beep {$_[0]{beeps}++}
1;
