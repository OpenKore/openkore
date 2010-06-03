package Interface::Wx::Window::NPCStore;

use strict;
use base 'Interface::Wx::Base::Store';

use Globals qw(@storeList);
use Translation qw(T TF);

{
	my $hooks;
	
	sub new {
		my ($class, $parent, $id) = @_;
		
		Scalar::Util::weaken(my $weak = my $self = $class->SUPER::new($parent, $id, {
			arrayref => \@storeList,
		}));
		
		$self->{title} = T('NPC Store');
		
		$hooks = Plugins::addHooks(map {[ $_, sub { $weak->{list}->update } ]} qw(packet_mapChange packet/npc_store_info));
		
		$self
	}
	
	sub DESTROY { Plugins::delHooks($hooks) }
}

sub _onBuy {
	my ($self) = @_;
	my ($item) = $self->{list}->getSelection or return;
	my $amount = $self->getAmount or return;
	
	for (0 .. @storeList-1) {
		if ($storeList[$_]{nameID} == $item->{nameID}) {
			Commands::run("buy $_ $amount");
			last;
		}
	}
}

1;
