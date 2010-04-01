package Interface::Wx::StatView::You;

use strict;
use base 'Interface::Wx::StatView';

use Globals qw/$char %config %jobs_lut %sex_lut $conState/;
use Translation qw/T TF/;

sub new {
	my ($class, $parent, $id) = @_;
	
	my $self = $class->SUPER::new ($parent, $id,
		[
			{key => 'name', type => 'name'},
			{key => 'level', type => 'name'},
			{key => 'jobLevel', title => '/', type => 'name'},
			{key => 'type', type => 'type'},
			{key => 'sex', type => 'type'},
			{key => 'hp', title => T('HP'), type => 'gauge', color => 'smooth'},
			{key => 'sp', title => T('SP'), type => 'gauge', color => 'smooth'},
			{key => 'exp', title => T('Exp'), type => 'gauge'},
			{key => 'jobExp', title => T('Job'), type => 'gauge'},
			{key => 'weight', title => T('Weight'), type => 'gauge', color => 'weight'},
			{key => 'str', title => T('Str'), type => 'stat', bonus => 1, increment => 1},
			{key => 'agi', title => T('Agi'), type => 'stat', bonus => 1, increment => 1},
			{key => 'vit', title => T('Vit'), type => 'stat', bonus => 1, increment => 1},
			{key => 'int', title => T('Int'), type => 'stat', bonus => 1, increment => 1},
			{key => 'dex', title => T('Dex'), type => 'stat', bonus => 1, increment => 1},
			{key => 'luk', title => T('Luk'), type => 'stat', bonus => 1, increment => 1},
			{key => 'speed', title => T('Walk speed'), type => 'stat'},
			{key => 'atk', title => T('Atk'), type => 'substat', bonus => 1},
			{key => 'matk', title => T('Matk'), type => 'substat', range => 1},
			{key => 'hit', title => T('Hit'), type => 'substat'},
			{key => 'crit', title => T('Critical'), type => 'substat'},
			{key => 'def', title => T('Def'), type => 'substat', bonus => 1},
			{key => 'mdef', title => T('Mdef'), type => 'substat', bonus => 1},
			{key => 'flee', title => T('Flee'), type => 'substat', bonus => 1},
			{key => 'aspd', title => T('Aspd'), type => 'substat'},
			{key => 'statPoint', title => T('Status point'), type => 'substat'},
			{key => 'skillPoint', title => T('Skill point'), type => 'substat'},
		],
	);
	
	$self->update;
	
	return $self;
}

sub update {
	my ($self) = @_;
	
	return unless $char && $conState == Network::IN_GAME;
	
	$self->Freeze;
	
	$self->set ('name', $char->name);
	$self->set ('level', $char->{lv});
	$self->set ('jobLevel', $char->{lv_job});
	$self->set ('type', $jobs_lut{$char->{jobID}} || $char->{jobID});
	$self->set ('sex', $sex_lut{$char->{sex}} || $char->{sex});
	$self->set ('hp', [$char->{hp}, $char->{hp_max}]) if $char->{hp_max};
	$self->set ('sp', [$char->{sp}, $char->{sp_max}]) if $char->{sp_max};
	$self->set ('exp', [$char->{exp}, $char->{exp_max}]) if $char->{exp_max};
	$self->set ('jobExp', [$char->{exp_job}, $char->{exp_job_max}]) if $char->{exp_job_max};
	$self->set ('weight', [$char->{weight}, $char->{weight_max}]) if $char->{weight_max};
	foreach my $stat (qw/str agi vit int dex luk/) {
		$self->set ($stat, $char->{$stat}, undef, $char->{$stat.'_bonus'}, $char->{'points_'.$stat},
			($char->{'points_'.$stat} <= $char->{points_free} and $char->{$stat} < 99 || $config{statsAdd_over_99})
		);
	}
	$self->set ('atk', $char->{attack}, undef, $char->{attack_bonus});
	$self->set ('matk', $char->{attack_magic_min}, $char->{attack_magic_max});
	$self->set ('hit', $char->{hit});
	$self->set ('crit', $char->{critical});
	$self->set ('def', $char->{def}, undef, $char->{def_bonus});
	$self->set ('mdef', $char->{def_magic}, undef, $char->{def_magic_bonus});
	$self->set ('flee', $char->{flee}, undef, $char->{flee_bonus});
	$self->set ('aspd', $char->{attack_speed});
	$self->set ('statPoint', $char->{points_free});
	$self->set ('skillPoint', $char->{points_skill});
	$self->set ('speed', sprintf '%.2f', 1 / $char->{walk_speed}) if $char->{walk_speed};
	
	$self->setStatus (defined $char->{statuses} && %{$char->{statuses}} ? join ', ', keys %{$char->{statuses}} : undef);
	
	$self->setImage ('bitmaps/heads/' . $char->{sex} . '/' . $char->{hair_style} . '.gif', {x => 1, y => $char->{hair_color}, w => 8, h => 9});
	
	$self->GetSizer->Layout;
	
	$self->Thaw;
}

sub _onIncrement {
	my ($self, $key) = @_;
	
	Commands::run ("stat_add $key");
}

1;
