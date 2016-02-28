package magicpowerfixup;
use strict;

my $hooks = Plugins::addHook(packet_skilluse => sub {
	my (undef, $args) = @_;
	
	if (
		$args->{skillID} != 0x16e # HW_MAGICPOWER
		and my $actor = Actor::get($args->{sourceID})
	) {
		$actor->setStatus(EFST_MAGICPOWER => 0)
	}
});

Plugins::register(
	__PACKAGE__,
	'Fix for servers where EFST_MAGICPOWER stays as active',
	sub { Plugins::delHooks($hooks) }
);
