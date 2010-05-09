package Interface::Wx::Window::Mercenary;

use strict;
use base 'Interface::Wx::Base::StatView';

use Globals qw/$char %jobs_lut $conState/;
use Translation qw/T TF/;
use Utils qw/getFormattedDate/;

sub new {
	my ($class, $parent, $id) = @_;
	
	my $self = $class->SUPER::new ($parent, $id,
		[
			{key => 'name', type => 'name'},
			{key => 'level', type => 'name'},
			{key => 'type', type => 'type'},
			{key => 'hp', title => T('HP'), type => 'gauge', color => 'smooth'},
			{key => 'sp', title => T('SP'), type => 'gauge', color => 'smooth'},
			{key => 'loyalty', title => T('Loy'), type => 'gauge'},
			{key => 'atk', title => T('Atk'), type => 'stat'},
			{key => 'matk', title => T('Matk'), type => 'stat'},
			{key => 'hit', title => T('Hit'), type => 'stat'},
			{key => 'crit', title => T('Crit'), type => 'stat'},
			{key => 'def', title => T('Def'), type => 'stat'},
			{key => 'mdef', title => T('Mdef'), type => 'stat'},
			{key => 'flee', title => T('Flee'), type => 'stat'},
			{key => 'aspd', title => T('Aspd'), type => 'stat'},
			#{key => 'speed', title => 'Walk speed', type => 'stat'},
			{key => 'time', title => T('End'), type => 'stat'},
			{key => 'kills', title => T('Kills'), type => 'stat'},
			{key => 'summons', title => T('Sum'), type => 'stat'},
			{key => 'dismiss', title => T('Dismiss'), type => 'control'},
		],
	);
	
	$self->{title} = T('Mercenary');
	
	Scalar::Util::weaken(my $weak = $self);
	my $hook = sub {
		my ($hook, $args) = @_;
		
		$weak->update;
	};
	$self->{hooks} = Plugins::addHooks (
		['packet/map_changed',            $hook],
		['packet/mercenary_init',         $hook],
		['packet/mercenary_param_change', $hook],
		['packet/mercenary_off',          $hook],
		['packet/message_string',         $hook],
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
