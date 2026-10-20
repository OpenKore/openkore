package sitStatusReconcile;
use strict;
use warnings;
use Plugins;
use Globals qw($accountID $char);
use Actor;

Plugins::register('sitStatusReconcile',
    'Clear stale EFST_SIT after confirmed own stand action', \&unload);
my $hooks = Plugins::addHooks(
    ['packet/actor_action', \&on_actor_action, undef],
);

sub unload {
    Plugins::delHooks($hooks);
}

sub on_actor_action {
    my ($hook, $args) = @_;
    return unless $args && ref($args) eq 'HASH';
    return unless defined $args->{type} && $args->{type} == 3; # ACTION_STAND
    return unless defined $args->{sourceID};
    my $actor = Actor::get($args->{sourceID});
    return unless $actor && $actor->{statuses} && $actor->{statuses}{EFST_SIT};
    $actor->setStatus('EFST_SIT', 0);
}

1;
