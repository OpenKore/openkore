#!/usr/bin/env perl
use strict;
use warnings;
use utf8;
use open ':std', ':encoding(UTF-8)';

# Usage:
#   perl mobdb_yml_to_monsters_table_txt.pl input.yml output.txt
#
# Example:
#   perl mobdb_yml_to_monsters_table_txt.pl mob_db.yml monsters_table.txt
#
# Requires:
#   cpan YAML::XS
# or
#   cpanm YAML::XS

use YAML::XS qw(LoadFile);

my ($infile, $outfile) = @ARGV;

die "Usage: perl $0 <input mob_db.yml> <output txt>\n"
	unless defined $infile && defined $outfile;

my $yaml = LoadFile($infile);

die "Invalid mob_db.yml: missing Body section\n"
	unless ref($yaml) eq 'HASH' && ref($yaml->{Body}) eq 'ARRAY';

open my $out, '>', $outfile
	or die "Cannot open output file '$outfile': $!\n";

my %ai_constant = (
	'01' => 0x81, '02' => 0x83, '03' => 0x1089, '04' => 0x3885,
	'05' => 0x2085, '06' => 0, '07' => 0x108B, '08' => 0x7085,
	'09' => 0x3095, '10' => 0x84, '11' => 0x84, '12' => 0x2085,
	'13' => 0x308D, '17' => 0x91, '19' => 0x3095, '20' => 0x3295,
	'21' => 0x3695, '24' => 0xA1, '25' => 0x1, '26' => 0xB695,
	'27' => 0x8084, 'ABR_PASSIVE' => 0x21, 'ABR_OFFENSIVE' => 0xA5
);

my %ai_mode_flags = (
	isAIMode_Aggressive                 => 0x0000004,
	isAIMode_Looter                     => 0x0000002,
	isAIMode_Assist                     => 0x0000008,
	isAIMode_CanMove                    => 0x0000001,
	isAIMode_CastSensorIdle             => 0x0000010,
	isAIMode_CastSensorChase            => 0x0000200,
	isAIMode_MVP                        => 0x0080000,
	isAIMode_KnockbackImmune            => 0x0200000,
	isAIMode_Detector                   => 0x2000000,
	isAIMode_TakesFixed_1_Damage_Melee  => 0x0010000,
	isAIMode_TakesFixed_1_Damage_Ranged => 0x0040000,
	isAIMode_TakesFixed_1_Damage_Magic  => 0x0020000,
	isAIMode_TakesFixed_1_Damage_None   => 0x0100000,
);
my %class_mode_bits = (
	Boss        => 0x6200000,
	Guardian    => 0x4000000,
	Battlefield => 0xC000000,
	Event       => 0x1000000,
);
my %modes_mode_bits = (
	CanMove          => 0x0000001,
	Looter           => 0x0000002,
	Aggressive       => 0x0000004,
	Assist           => 0x0000008,
	CastSensorIdle   => 0x0000010,
	NoRandomWalk     => 0x0000020,
	NoCast           => 0x0000040,
	CanAttack        => 0x0000080,
	CastSensorChase  => 0x0000200,
	ChangeChase      => 0x0000400,
	Angry            => 0x0000800,
	ChangeTargetMelee=> 0x0001000,
	ChangeTargetChase=> 0x0002000,
	TargetWeak       => 0x0004000,
	RandomTarget     => 0x0008000,
	IgnoreMelee      => 0x0010000,
	IgnoreMagic      => 0x0020000,
	IgnoreRanged     => 0x0040000,
	Mvp              => 0x0080000,
	IgnoreMisc       => 0x0100000,
	KnockBackImmune  => 0x0200000,
	TeleportBlock    => 0x0400000,
	FixedItemDrop    => 0x1000000,
	Detector         => 0x2000000,
	StatusImmune     => 0x4000000,
	SkillImmune      => 0x8000000,
);

my %valid_size = map { $_ => 1 } qw(Small Medium Large);
my %valid_race = map { $_ => 1 } qw(Formless Undead Brute Plant Insect Fish Demon Demi-Human Angel Dragon Demihuman);
my %valid_element = map { $_ => 1 } qw(Neutral Water Earth Fire Wind Poison Holy Shadow Ghost Undead Dark);

my @header = qw(
	ID
	Name
	Level
	Hp
	AttackRange
	SkillRange
	AttackDelay
	AttackMotion
	Size
	Race
	Element
	ElementLevel
	ChaseRange
	Ai
	isAIMode_Aggressive
	isAIMode_Looter
	isAIMode_Assist
	isAIMode_CanMove
	isAIMode_CastSensorIdle
	isAIMode_CastSensorChase
	isAIMode_MVP
	isAIMode_KnockbackImmune
	isAIMode_Detector
	isAIMode_TakesFixed_1_Damage_Melee
	isAIMode_TakesFixed_1_Damage_Ranged
	isAIMode_TakesFixed_1_Damage_Magic
	isAIMode_TakesFixed_1_Damage_None
);

print $out join("\t", @header), "\n";

for my $mob (@{ $yaml->{Body} }) {
	next unless ref($mob) eq 'HASH';

	my $id            = sanitize_numeric_field($mob, 'Id', 0);
	my $level         = sanitize_numeric_field($mob, 'Level', 1);
	my $hp            = sanitize_numeric_field($mob, 'Hp', 1);
	my $attack_range  = sanitize_numeric_field($mob, 'AttackRange', 0);
	my $skill_range   = sanitize_numeric_field($mob, 'SkillRange', 0);
	my $attack_delay  = sanitize_numeric_field($mob, 'AttackDelay', 0);
	my $attack_motion = sanitize_numeric_field($mob, 'AttackMotion', 0);
	my $size          = sanitize_enum_field($mob, 'Size', 'Small', \%valid_size);
	my $race          = sanitize_race_field($mob);
	my $element       = sanitize_element_field($mob);
	my $element_lv    = sanitize_numeric_field($mob, 'ElementLevel', 1);
	my $chase_range   = sanitize_numeric_field($mob, 'ChaseRange', 0);
	my $ai            = sanitize_ai_field($mob);
	my $name          = sanitize_name_field($mob, $id);
	my $class         = sanitize_class_field($mob);

	my $mode_value = build_mode_value($mob, $ai, $class);
	my @row = (
		$id,
		$name,
		$level,
		$hp,
		$attack_range,
		$skill_range,
		$attack_delay,
		$attack_motion,
		$size,
		$race,
		$element,
		$element_lv,
		$chase_range,
		$ai,
	);

	for my $flag_name (@header[14 .. $#header]) {
		push @row, ($mode_value & $ai_mode_flags{$flag_name}) ? 1 : 0;
	}

	print $out join("\t", @row), "\n";
}

close $out;
print "Done. Wrote '$outfile'\n";

sub sanitize_numeric_field {
	my ($mob, $field, $default) = @_;
	my $value = $mob->{$field};

	if (!defined $value || $value eq '' || $value !~ /^\d+$/) {
		report_default($mob, $field, $value, $default);
		return $default;
	}

	return int($value);
}

sub sanitize_enum_field {
	my ($mob, $field, $default, $valid_values) = @_;
	my $value = $mob->{$field};

	if (!defined $value || $value eq '' || !$valid_values->{$value}) {
		report_default($mob, $field, $value, $default);
		return $default;
	}

	return $value;
}

sub sanitize_race_field {
	my ($mob) = @_;
	my $race = $mob->{Race};

	$race = 'Demi-Human' if defined $race && $race eq 'Demihuman';
	return sanitize_enum_field({ %{$mob}, Race => $race }, 'Race', 'Formless', \%valid_race);
}

sub sanitize_element_field {
	my ($mob) = @_;
	my $element = $mob->{Element};

	$element = 'Shadow' if defined $element && $element eq 'Dark';
	return sanitize_enum_field({ %{$mob}, Element => $element }, 'Element', 'Neutral', \%valid_element);
}

sub sanitize_ai_field {
	my ($mob) = @_;
	my $value = $mob->{Ai};

	if (!defined $value || $value eq '') {
		report_default($mob, 'Ai', $value, '06');
		return '06';
	}

	$value = uc($value);
	$value = sprintf('%02d', $value) if $value =~ /^\d+$/;

	if (!exists $ai_constant{$value}) {
		report_default($mob, 'Ai', $mob->{Ai}, '06');
		return '06';
	}

	return $value;
}

sub sanitize_class_field {
	my ($mob) = @_;
	my $value = $mob->{Class};

	return undef if !defined $value || $value eq '';
	if (!exists $class_mode_bits{$value}) {
		report_default($mob, 'Class', $value, 'normal monster');
		return undef;
	}

	return $value;
}

sub sanitize_name_field {
	my ($mob, $id) = @_;
	my $name = defined $mob->{Name} && $mob->{Name} ne '' ? $mob->{Name} : $mob->{AegisName};

	if (defined $name) {
		$name =~ s/[\r\n\t]+/ /g;
		$name =~ s/^\s+|\s+$//g;
	}

	if (!defined $name || $name eq '') {
		my $default = defined $id && $id =~ /^\d+$/ ? "Unknown Monster $id" : 'Unknown Monster';
		report_default($mob, 'Name', $mob->{Name}, $default);
		return $default;
	}

	return $name;
}

sub build_mode_value {
	my ($mob, $ai, $class) = @_;

	my $mode_value = $ai_constant{$ai};
	$mode_value |= $class_mode_bits{$class} if defined $class;

	if (ref $mob->{Modes} eq 'HASH') {
		for my $mode_name (keys %{$mob->{Modes}}) {
			next unless $mob->{Modes}{$mode_name};

			if (!exists $modes_mode_bits{$mode_name}) {
				report_default($mob, "Modes.$mode_name", $mob->{Modes}{$mode_name}, 'ignored');
				next;
			}

			$mode_value |= $modes_mode_bits{$mode_name};
		}
	}

	return $mode_value;
}

sub report_default {
	my ($mob, $field, $value, $default) = @_;
	my $id = defined $mob->{Id} ? $mob->{Id} : 'unknown';
	$value = defined $value && $value ne '' ? $value : '<empty>';
	warn "[mobdb_yml_to_monsters_table_txt] Mob ID $id has invalid $field value '$value'; using default '$default'\n";
}
