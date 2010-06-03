package Interface::Wx::Window::PlayerStore;

use strict;
use base 'Interface::Wx::Base::Store';

use Globals qw(@venderListsID $venderID @venderItemList);
use Translation qw(T TF);

{
	my $hooks;
	
	sub new {
		my ($class, $parent, $id) = @_;
		
		Scalar::Util::weaken(my $weak = my $self = $class->SUPER::new($parent, $id, {
			arrayref => \@venderItemList,
			source => 'sparse',
		}));
		
		$self->{title} = T('Player Store');
		
		$hooks = Plugins::addHooks(map {[ $_, sub { $weak->{list}->update } ]} qw(packet_mapChange packet/vender_items_list));
		
		$self
	}
	
	sub DESTROY { Plugins::delHooks($hooks) }
}

sub _onBuy {
	my ($self) = @_;
	my ($item) = $self->{list}->getSelection or return;
	my $amount = $self->getAmount or return;
	
	for my $vender (0 .. @venderListsID-1) {
		if ($venderListsID[$vender] eq $venderID) {
			for (0 .. @venderItemList-1) {
				if ($venderItemList[$_] && $venderItemList[$_]{nameID} == $item->{nameID}) {
					Commands::run("vender $vender $_ $amount");
					last
				}
			}
			last
		}
	}
}

1;
