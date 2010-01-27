package Interface::Wx::StatView::Mercenary;

use strict;
use base 'Interface::Wx::StatView';

use Globals qw/$char %jobs_lut $conState/;
use Utils qw/getFormattedDate/;

sub new {
	my ($class, $parent, $id) = @_;
	
	my $self = $class->SUPER::new ($parent, $id,
		[
			{key => 'name', type => 'name'},
			{key => 'level', type => 'name'},
			{key => 'type', type => 'type'},
			{key => 'hp', title => 'HP', type => 'gauge', color => 'smooth'},
			{key => 'sp', title => 'SP', type => 'gauge', color => 'smooth'},
			{key => 'loyalty', title => 'Loyalty', type => 'gauge'},
			{key => 'atk', title => 'Atk', type => 'stat'},
			{key => 'matk', title => 'Matk', type => 'stat'},
			{key => 'hit', title => 'Hit', type => 'stat'},
			{key => 'crit', title => 'Critical', type => 'stat'},
			{key => 'def', title => 'Def', type => 'stat'},
			{key => 'mdef', title => 'Mdef', type => 'stat'},
			{key => 'flee', title => 'Flee', type => 'stat'},
			{key => 'aspd', title => 'Aspd', type => 'stat'},
			#{key => 'speed', title => 'Walk speed', type => 'substat'},
			{key => 'time', title => 'Contract ends', type => 'substat'},
			{key => 'kills', title => 'Kills', type => 'substat'},
			{key => 'summons', title => 'Summons', type => 'substat'},
			{key => 'dismiss', title => 'Dismiss', type => 'control'},
		],
	);
	
	$self->update;
	
	return $self;
}

sub update {
	my ($self) = @_;
	
	return unless $conState == Network::IN_GAME;
	
	$self->set ('dismiss', $char->{mercenary});
	
	return unless $char->{mercenary};
	
	$self->Freeze;
	
	$self->set ('name', $char->{mercenary}->name);
	$self->set ('level', $char->{mercenary}{level});
	$self->set ('type', $jobs_lut{$char->{mercenary}{jobID}} || $char->{mercenary}{jobID});
	$self->set ('hp', [$char->{mercenary}{hp}, $char->{mercenary}{hp_max}]) if $char->{mercenary}{hp_max};
	$self->set ('sp', [$char->{mercenary}{sp}, $char->{mercenary}{sp_max}]) if $char->{mercenary}{sp_max};
	$self->set ('loyalty', [$char->{mercenary}{faith}, 1000]);
	$self->set ('atk', $char->{mercenary}{atk});
	$self->set ('matk', $char->{mercenary}{matk});
	$self->set ('hit', $char->{mercenary}{hit});
	$self->set ('crit', $char->{mercenary}{critical});
	$self->set ('def', $char->{mercenary}{def});
	$self->set ('mdef', $char->{mercenary}{mdef});
	$self->set ('flee', $char->{mercenary}{flee});
	$self->set ('aspd', $char->{mercenary}{aspd});
	$self->set ('time', defined $char->{mercenary}{contract_end} ? getFormattedDate (int $char->{mercenary}{contract_end}) : 'N/A');
	$self->set ('kills', $char->{mercenary}{kills});
	$self->set ('summons', $char->{mercenary}{summons});
	#$self->set ('speed', sprintf '%.2f', 1 / $char->{walk_speed}) if $char->{walk_speed};
	
	$self->setStatus (defined $char->{mercenary}{statuses} && %{$char->{mercenary}{statuses}} ? join ', ', keys %{$char->{mercenary}{statuses}} : undef);
	
	$self->setImage ('bitmaps/actors/' . $char->{mercenary}{jobID} . '.png');
	
	$self->GetSizer->Layout;
	
	$self->Thaw;
}

sub _onControl {
	my ($self, $key) = @_;
	
	if ($key eq 'dismiss') {
		Commands::run ('merc fire');
	}
}

1;
