package awakeningAfterDeath;
use strict;
use warnings;
# OpenKore reloads plugins with do FILE; named subs remain in the Perl package.
no warnings 'redefine';
use Plugins;
use Globals qw($char);

Plugins::register('awakeningAfterDeath', 'Refresh Awakening Potion after death', \&unload);
my $hooks = Plugins::addHooks(
    ['self_died', \&clear_buff],
    ['self_resurrected', \&clear_buff],
);

sub clear_buff {
    return unless $char && $char->statusActive('EFST_ATTHASTE_POTION2');
    $char->setStatus('EFST_ATTHASTE_POTION2', 0);
}

sub unload { Plugins::delHooks($hooks) }
1;
