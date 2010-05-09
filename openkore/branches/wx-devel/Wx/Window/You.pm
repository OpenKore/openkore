package Interface::Wx::Window::You;

use strict;
use base 'Interface::Wx::Base::StatView';

use Globals qw/$char %config %jobs_lut %sex_lut $conState $accountID/;

sub new {
	my ($class, $parent, $id) = @_;
	
	my $self = $class->SUPER::new ($parent, $id,
		[
			{key => 'name', type => 'name'},
			{key => 'level', type => 'name'},
			{key => 'jobLevel', title => '/', type => 'name'},
			{key => 'type', type => 'type'},
			{key => 'sex', type => 'type'},
			{key => 'hp', title => 'HP', type => 'gauge', color => 'smooth'},
			{key => 'sp', title => 'SP', type => 'gauge', color => 'smooth'},
			{key => 'exp', title => 'Exp', type => 'gauge'},
			{key => 'jobExp', title => 'Job', type => 'gauge'},
			{key => 'weight', title => 'Weight', type => 'gauge', color => 'weight'},
			{key => 'str', title => 'Str', type => 'stat', bonus => 1, increment => 1},
			{key => 'agi', title => 'Agi', type => 'stat', bonus => 1, increment => 1},
			{key => 'vit', title => 'Vit', type => 'stat', bonus => 1, increment => 1},
			{key => 'int', title => 'Int', type => 'stat', bonus => 1, increment => 1},
			{key => 'dex', title => 'Dex', type => 'stat', bonus => 1, increment => 1},
			{key => 'luk', title => 'Luk', type => 'stat', bonus => 1, increment => 1},
			{key => 'speed', title => 'Speed', type => 'stat'},
			{key => 'atk', title => 'Atk', type => 'substat', bonus => 1},
			{key => 'matk', title => 'Matk', type => 'substat', range => 1},
			{key => 'hit', title => 'Hit', type => 'substat'},
			{key => 'crit', title => 'Critical', type => 'substat'},
			{key => 'def', title => 'Def', type => 'substat', bonus => 1},
			{key => 'mdef', title => 'Mdef', type => 'substat', bonus => 1},
			{key => 'flee', title => 'Flee', type => 'substat', bonus => 1},
			{key => 'aspd', title => 'Aspd', type => 'substat'},
			{key => 'statPoint', title => 'Status P.', type => 'substat'},
			{key => 'skillPoint', title => 'Skill P.', type => 'substat'},
		],
	);
	
	Scalar::Util::weaken(my $weak = $self);
	my $hook = sub {
		my ($hook, $args) = @_;
		
		$weak->update unless $hook eq 'changed_status' && $args->{actor}{ID} ne $accountID;
	};
	$self->{hooks} = Plugins::addHooks (
		['packet/map_changed',         $hook],
		['packet/hp_sp_changed',       $hook],
		['packet/stat_info',           $hook],
		['packet/stat_info2',          $hook],
		['packet/stats_points_needed', $hook],
		['changed_status',             $hook],
	);
	
	$self->update;
	
	return $self;
}

sub DESTROY {
	my ($self) = @_;
	
	Plugins::delHooks ($self->{hooks});
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
