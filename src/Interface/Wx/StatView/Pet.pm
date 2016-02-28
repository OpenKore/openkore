package Interface::Wx::StatView::Pet;

use strict;
use base 'Interface::Wx::StatView';

use Globals qw/$char %pet %jobs_lut $conState/;
use Misc qw/itemNameSimple monsterName/;
use Translation qw/T TF/;

sub new {
	my ($class, $parent, $id) = @_;
	
	my $self = $class->SUPER::new ($parent, $id,
		[
			{key => 'name', type => 'name'},
			{key => 'level', type => 'name'},
			{key => 'type', type => 'type'},
			{key => 'intimacy', title => T('Intimacy'), type => 'gauge'},
			{key => 'hunger', title => T('Hunger'), type => 'gauge', color => 'smooth'},
			{key => 'accessory', title => T('Accessory'), type => 'stat'},
			{key => 'feed', title => T('Feed'), type => 'control'},
			{key => 'performance', title => T('Performance'), type => 'control'},
			{key => 'unequip', title => T('Unequip'), type => 'control'},
			{key => 'return', title => T('Return'), type => 'control'},
		],
	);
	
	$self->update;
	
	return $self;
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
