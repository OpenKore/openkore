package Interface::Wx::Window::Homunculus;

use strict;
use base 'Interface::Wx::Base::StatView';

use Globals qw/$char %jobs_lut $conState/;
use Translation qw/T TF/;

use constant {
	HO_STATE_ALIVE => 0,
	HO_STATE_REST => 2,
	HO_STATE_DEAD => 4,
};

use constant {
	HO_SKILL_VAPORIZE => 'AM_REST',
	HO_SKILL_CALL => 'AM_CALLHOMUN',
	HO_SKILL_RESURRECT => 'AM_RESURRECTHOMUN',
};

sub new {
	my ($class, $parent, $id) = @_;
	
	my $self = $class->SUPER::new ($parent, $id,
		[
			{key => 'name', type => 'name'},
			{key => 'level', type => 'name'},
			{key => 'type', type => 'type'},
			{key => 'hp', title => T('HP'), type => 'gauge', color => 'smooth'},
			{key => 'sp', title => T('SP'), type => 'gauge', color => 'smooth'},
			{key => 'exp', title => T('Exp'), type => 'gauge'},
			{key => 'intimacy', title => T('Int'), type => 'gauge'},
			{key => 'hunger', title => T('Rep'), type => 'gauge', color => 'hunger'},
			{key => 'atk', title => T('Atk'), type => 'stat'},
			{key => 'matk', title => T('Matk'), type => 'stat'},
			{key => 'hit', title => T('Hit'), type => 'stat'},
			{key => 'crit', title => T('Crit'), type => 'stat'},
			{key => 'def', title => T('Def'), type => 'stat'},
			{key => 'mdef', title => T('Mdef'), type => 'stat'},
			{key => 'flee', title => T('Flee'), type => 'stat'},
			{key => 'aspd', title => T('Aspd'), type => 'stat'},
			#{key => 'speed', title => 'Walk speed', type => 'stat'},
			{key => 'skillPoint', title => T('Skill'), type => 'stat'},
			{key => 'feed', title => T('Feed'), type => 'control'},
			{key => 'vaporize', title => T('Vaporize'), type => 'control'},
			{key => 'call', title => T('Call'), type => 'control'},
			{key => 'resurrect', title => T('Res'), type => 'control'},
		],
	);
	
	$self->{title} = T('Homunculus');
	
	Scalar::Util::weaken(my $weak = $self);
	my $hook = sub {
		my ($hook, $args) = @_;
		
		$weak->update;
	};
	$self->{hooks} = Plugins::addHooks (
		['packet/map_changed',            $hook],
		['packet/homunculus_info',        $hook],
		['packet/homunculus_property',    $hook],
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
	
	$self->set ('feed',
		$char->{homunculus} && $char->{homunculus}{state} == HO_STATE_ALIVE
	);
	$self->set ('vaporize',
		$char->{homunculus} && $char->{homunculus}{state} == HO_STATE_ALIVE
		&& $char->{skills}{(HO_SKILL_VAPORIZE)} && $char->{skills}{(HO_SKILL_VAPORIZE)}{lv}
	);
	$self->set ('call',
		(!$char->{homunculus} || !defined $char->{homunculus}{state} || $char->{homunculus}{state} == HO_STATE_REST)
		&& $char->{skills}{(HO_SKILL_CALL)} && $char->{skills}{(HO_SKILL_CALL)}{lv}
	);
	$self->set ('resurrect',
		(!$char->{homunculus} || (!defined $char->{homunculus}{state} && $char->{homunculus}{state} == HO_STATE_DEAD))
		&& $char->{skills}{(HO_SKILL_RESURRECT)} && $char->{skills}{(HO_SKILL_RESURRECT)}{lv}
	);
	
	return unless $char->{homunculus};
	
	$self->Freeze;
	
	$self->set ('name', $char->{homunculus}->name);
	$self->set ('level', $char->{homunculus}{level});
	$self->set ('type', $jobs_lut{$char->{homunculus}{jobID}} || $char->{homunculus}{jobID});
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
	
	$self->setStatus ($char->{homunculus}->statusesString);
	
	$self->setImage ('bitmaps/actors/' . $char->{homunculus}{jobID} . '.png');
	
	$self->GetSizer->Layout;
	
	$self->Thaw;
}

sub _onControl {
	my ($self, $key) = @_;
	
	if ($key eq 'feed') {
		Commands::run ('homun feed');
	} elsif ($key eq 'call') {
		Commands::run ('ss ' . Skill::lookupIDNByHandle (HO_SKILL_CALL));
	} elsif ($key eq 'vaporize') {
		Commands::run ('ss ' . Skill::lookupIDNByHandle (HO_SKILL_VAPORIZE));
	} elsif ($key eq 'resurrect') {
		Commands::run ('ss ' . Skill::lookupIDNByHandle (HO_SKILL_RESURRECT));
	}
}

1;
