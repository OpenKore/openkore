package Interface::Wx::StatView::Homunculus;

use strict;
use base 'Interface::Wx::StatView';

use Globals;

sub new {
	my ($class, $parent, $id) = @_;
	
	my $self = $class->SUPER::new ($parent, $id,
		[
			{key => 'name', type => 'name'},
			{key => 'level', type => 'name'},
			{key => 'type', type => 'type'},
			{key => 'hp', title => 'HP', type => 'gauge', color => 'smooth'},
			{key => 'sp', title => 'SP', type => 'gauge', color => 'smooth'},
			{key => 'exp', title => 'Exp', type => 'gauge'},
			{key => 'intimacy', title => 'Intimacy', type => 'gauge'},
			{key => 'hunger', title => 'Hunger', type => 'gauge', color => 'hunger'},
			{key => 'atk', title => 'Atk', type => 'stat'},
			{key => 'matk', title => 'Matk', type => 'stat'},
			{key => 'hit', title => 'Hit', type => 'stat'},
			{key => 'crit', title => 'Critical', type => 'stat'},
			{key => 'def', title => 'Def', type => 'stat'},
			{key => 'mdef', title => 'Mdef', type => 'stat'},
			{key => 'flee', title => 'Flee', type => 'stat'},
			{key => 'aspd', title => 'Aspd', type => 'stat'},
			{key => 'speed', title => 'Walk speed', type => 'substat'},
			{key => 'skillPoint', title => 'Skill point', type => 'substat'},
		],
	);
	
	$self->update;
	
	return $self;
}

sub update {
	my ($self) = @_;
	
	return unless $char && $char->{homunculus} && $conState == Network::IN_GAME;
	
	$self->Freeze;
	
	$self->set ('name', $char->{homunculus}->name);
	$self->set ('level', $char->{homunculus}{level});
	$self->set ('type', $jobs_lut{$char->{homunculus}{jobID}} // $char->{homunculus}{jobID});
	$self->set ('hp', [$char->{homunculus}{hp}, $char->{homunculus}{hp_max}]) if $char->{homunculus}{hp_max};
	$self->set ('sp', [$char->{homunculus}{sp}, $char->{homunculus}{sp_max}]) if $char->{homunculus}{sp_max};
	$self->set ('exp', [$char->{homunculus}{exp}, $char->{homunculus}{exp_max}]) if $char->{homunculus}{exp_max};
	$self->set ('intimacy', [$char->{homunculus}{intimacy}, 1000]);
	$self->set ('hunger', [$char->{homunculus}{hunger}, 100]);
	$self->set ('atk', $char->{homunculus}{atk});
	$self->set ('matk', $char->{homunculus}{matk});
	$self->set ('hit', $char->{homunculus}{hit});
	$self->set ('crit', $char->{homunculus}{critical});
	$self->set ('def', $char->{homunculus}{def});
	$self->set ('mdef', $char->{homunculus}{mdef});
	$self->set ('flee', $char->{homunculus}{flee});
	$self->set ('aspd', $char->{homunculus}{aspd});
	$self->set ('skillPoint', $char->{homunculus}{points_skill});
	#$self->set ('speed', sprintf '%.2f', 1 / $char->{walk_speed}) if $char->{walk_speed};
	
	$self->setStatus (defined $char->{homunculus}{statuses} && %{$char->{homunculus}{statuses}} ? join ', ', keys %{$char->{homunculus}{statuses}} : undef);
	
	$self->setImage ('bitmaps/actors/' . $char->{homunculus}{jobID} . '.png');
	
	$self->GetSizer->Layout;
	
	$self->Thaw;
}

1;
