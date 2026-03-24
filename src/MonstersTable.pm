package MonstersTable;

use strict;
use warnings;
use Exporter qw(import);
use Globals qw(%monstersTable);

our @EXPORT_OK = qw(
	monster_exists
	monster_get
	monster_field
	monster_ai
	monster_level
	monster_hp
	monster_race
	monster_size
	monster_element
	monster_element_level
	monster_is_looter_by_ai
	monster_is_aggressive_by_ai
	initialize_compact_backend
	using_compact_backend
	reset_backend_state
);

my %compact_rows;
my %compact_enums;
my $use_compact_backend = 0;
my $loaded = 0;
my $loading = 0;
my %ai_flags;

my %FIELD_INDEX = (
	Level        => 0,
	HP           => 1,
	AttackRange  => 2,
	SkillRange   => 3,
	AttackDelay  => 4,
	AttackMotion => 5,
	Size         => 6,
	Race         => 7,
	Element      => 8,
	ElementLevel => 9,
	ChaseRange   => 10,
	Ai           => 11,
);

my %AI_MODE = (
	'01' => 0x81, '02' => 0x83, '03' => 0x1089, '04' => 0x3885,
	'05' => 0x2085, '06' => 0, '07' => 0x108B, '08' => 0x7085,
	'09' => 0x3095, '10' => 0x84, '11' => 0x84, '12' => 0x2085,
	'13' => 0x308D, '17' => 0x91, '19' => 0x3095, '20' => 0x3295,
	'21' => 0x3695, '24' => 0xA1, '25' => 0x1, '26' => 0xB695,
	'27' => 0x8084, 'ABR_PASSIVE' => 0x21, 'ABR_OFFENSIVE' => 0xA5
);

sub _ai_mode_value {
	my ($ai) = @_;
	$ai = defined $ai ? uc($ai) : '06';
	return exists $AI_MODE{$ai} ? $AI_MODE{$ai} : $AI_MODE{'06'};
}

sub _rebuild_ai_flags_cache {
	%ai_flags = ();
	if ($use_compact_backend) {
		for my $id (keys %compact_rows) {
			my $ai = $compact_enums{'Ai'}{ids}[$compact_rows{$id}[11]];
			my $mode = _ai_mode_value($ai);
			$ai_flags{$id}{looter} = ($mode & 0x2) ? 1 : 0;
			$ai_flags{$id}{aggressive} = ($mode & 0x4) ? 1 : 0;
		}
		return;
	}

	for my $id (keys %monstersTable) {
		next unless ref $monstersTable{$id} eq 'HASH';
		my $mode = _ai_mode_value($monstersTable{$id}{Ai});
		$ai_flags{$id}{looter} = ($mode & 0x2) ? 1 : 0;
		$ai_flags{$id}{aggressive} = ($mode & 0x4) ? 1 : 0;
	}
}

sub _exists_raw {
	my ($id) = @_;
	return exists $compact_rows{$id} if $use_compact_backend;
	return exists $monstersTable{$id};
}

sub _enum_id {
	my ($type, $name) = @_;
	return unless defined $name;
	$compact_enums{$type}{ids} ||= [];
	$compact_enums{$type}{names} ||= {};
	if (!exists $compact_enums{$type}{names}{$name}) {
		my $id = scalar(@{$compact_enums{$type}{ids}});
		$compact_enums{$type}{names}{$name} = $id;
		$compact_enums{$type}{ids}[$id] = $name;
	}
	return $compact_enums{$type}{names}{$name};
}

sub _ensure_loaded {
	return 1 if $loaded;
	return 0 if $loading;
	$loaded = 1;
	return 1;
}

sub initialize_compact_backend {
	my %args = @_;
	my $purge_legacy = $args{purge_legacy} ? 1 : 0;

	%compact_rows = ();
	%compact_enums = ();

	for my $id (keys %monstersTable) {
		my $entry = $monstersTable{$id};
		next unless ref $entry eq 'HASH';

		$compact_rows{$id} = [
			defined $entry->{Level} ? $entry->{Level} : 0,
			defined $entry->{HP} ? $entry->{HP} : 0,
			defined $entry->{AttackRange} ? $entry->{AttackRange} : 0,
			defined $entry->{SkillRange} ? $entry->{SkillRange} : 0,
			defined $entry->{AttackDelay} ? $entry->{AttackDelay} : 0,
			defined $entry->{AttackMotion} ? $entry->{AttackMotion} : 0,
			_enum_id('Size', defined $entry->{Size} ? $entry->{Size} : 'Small'),
			_enum_id('Race', defined $entry->{Race} ? $entry->{Race} : 'Formless'),
			_enum_id('Element', defined $entry->{Element} ? $entry->{Element} : 'Neutral'),
			defined $entry->{ElementLevel} ? $entry->{ElementLevel} : 1,
			defined $entry->{ChaseRange} ? $entry->{ChaseRange} : 0,
			_enum_id('Ai', defined $entry->{Ai} ? uc($entry->{Ai}) : '06'),
		];
	}

	if ($purge_legacy) {
		%monstersTable = ();
	}

	$use_compact_backend = 1;
	_rebuild_ai_flags_cache();
	return scalar(keys %compact_rows);
}

sub using_compact_backend {
	return $use_compact_backend;
}

sub monster_exists {
	my ($id) = @_;
	_ensure_loaded();
	return 0 unless defined $id && $id ne '';
	return _exists_raw($id);
}

sub monster_get {
	my ($id) = @_;
	_ensure_loaded();
	return unless defined $id && $id ne '';
	return unless _exists_raw($id);
	return unless !$use_compact_backend;
	return $monstersTable{$id};
}

sub monster_field {
	my ($id, $field) = @_;
	_ensure_loaded();
	return unless defined $field && $field ne '';
	return unless defined $id && $id ne '';
	return unless _exists_raw($id);

	if ($use_compact_backend) {
		if (!exists $FIELD_INDEX{$field}) {
			return;
		}
		my $idx = $FIELD_INDEX{$field};
		my $value = $compact_rows{$id}[$idx];
		if ($field eq 'Size' || $field eq 'Race' || $field eq 'Element' || $field eq 'Ai') {
			return $compact_enums{$field}{ids}[$value];
		}
		return $value;
	}

	my $entry = monster_get($id);
	return unless $entry;
	return $entry->{$field};
}

sub monster_ai {
	my ($id) = @_;
	my $ai = monster_field($id, 'Ai');
	return defined $ai && $ai ne '' ? $ai : '06';
}

sub monster_level {
	my ($id) = @_;
	return monster_field($id, 'Level');
}

sub monster_hp {
	my ($id) = @_;
	return monster_field($id, 'HP');
}

sub monster_race {
	my ($id) = @_;
	return monster_field($id, 'Race');
}

sub monster_size {
	my ($id) = @_;
	return monster_field($id, 'Size');
}

sub monster_element {
	my ($id) = @_;
	return monster_field($id, 'Element');
}

sub monster_element_level {
	my ($id) = @_;
	return monster_field($id, 'ElementLevel');
}

sub monster_is_looter_by_ai {
	my ($id) = @_;
	_ensure_loaded();
	return 0 unless defined $id && $id ne '';
	return 0 unless _exists_raw($id);
	return $ai_flags{$id}{looter} if exists $ai_flags{$id} && exists $ai_flags{$id}{looter};
	my $mode = _ai_mode_value(monster_ai($id));
	return ($mode & 0x2) ? 1 : 0;
}

sub monster_is_aggressive_by_ai {
	my ($id) = @_;
	_ensure_loaded();
	return 0 unless defined $id && $id ne '';
	return 0 unless _exists_raw($id);
	return $ai_flags{$id}{aggressive} if exists $ai_flags{$id} && exists $ai_flags{$id}{aggressive};
	my $mode = _ai_mode_value(monster_ai($id));
	return ($mode & 0x4) ? 1 : 0;
}

sub reset_backend_state {
	%compact_rows = ();
	%compact_enums = ();
	%ai_flags = ();
	$use_compact_backend = 0;
	$loaded = 0;
	$loading = 0;
}

1;
