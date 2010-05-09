package Interface::Wx::Window::Pet;

use strict;
use base 'Interface::Wx::Base::StatView';

use Globals qw/$char %pet %jobs_lut $conState/;
use Misc qw/itemNameSimple monsterName/;

sub new {
	my ($class, $parent, $id) = @_;
	
	my $self = $class->SUPER::new ($parent, $id,
		[
			{key => 'name', type => 'name'},
			{key => 'level', type => 'name'},
			{key => 'type', type => 'type'},
			{key => 'intimacy', title => 'Intimacy', type => 'gauge'},
			{key => 'hunger', title => 'Hunger', type => 'gauge', color => 'smooth'},
			{key => 'accessory', title => 'Accessory', type => 'stat'},
			{key => 'feed', title => 'Feed', type => 'control'},
			{key => 'performance', title => 'Performance', type => 'control'},
			{key => 'unequip', title => 'Unequip', type => 'control'},
			{key => 'return', title => 'Return', type => 'control'},
		],
	);
	
	Scalar::Util::weaken(my $weak = $self);
	my $hook = sub {
		my ($hook, $args) = @_;
		
		$weak->update;
	};
	$self->{hooks} = Plugins::addHooks (
		['packet/map_changed', $hook],
		['packet/pet_info',    $hook],
		['packet/pet_info2',   $hook],
	);
	
	$self->update;
	
	return $self;
}

sub DESTROY {
	my ($self) = @_;
	
	Plugins::delHooks($self->{hooks});
}

sub update {
	my ($self) = @_;
	
	return unless $conState == Network::IN_GAME;
	
	$self->set ('feed', defined %pet && $pet{ID});
	$self->set ('performance', defined %pet && $pet{ID});
	$self->set ('unequip', defined %pet && $pet{ID} && $pet{accessory});
	$self->set ('return', defined %pet && $pet{ID});
	
	return unless defined %pet && $pet{ID};
	
	$self->Freeze;
	
	$self->set ('name', $pet{name});
	$self->set ('level', $pet{level});
	$self->set ('type', monsterName ($pet{type}) || $pet{type});
	$self->set ('intimacy', [$pet{friendly}, 1000]);
	$self->set ('hunger', [$pet{hungry}, 100]);
	$self->set ('accessory', itemNameSimple ($pet{accessory}));
	
	$self->setImage ('bitmaps/actors/' . $pet{type} . '.png');
	
	$self->GetSizer->Layout;
	
	$self->Thaw;
}

sub _onControl {
	my ($self, $key) = @_;
	
	if ($key eq 'feed') {
		Commands::run ('pet feed');
	} elsif ($key eq 'performance') {
		Commands::run ('pet performance');
	} elsif ($key eq 'unequip') {
		Commands::run ('pet unequip');
	} elsif ($key eq 'return') {
		Commands::run ('pet return');
	}
}

1;
