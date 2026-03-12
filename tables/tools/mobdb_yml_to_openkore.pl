#!/usr/bin/env perl
use strict;
use warnings;
use utf8;
use open ':std', ':encoding(UTF-8)';

# Usage:
#   perl mobdb_yml_to_openkore.pl input.yml output.txt
#
# Example:
#   perl mobdb_yml_to_openkore.pl mob_db.yml monsters_table.txt
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

# Header comment (optional)
print $out join("\t",
	qw(
		ID
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
	)
), "\n";

for my $mob (@{ $yaml->{Body} }) {
	next unless ref($mob) eq 'HASH';

	my $id            = defined $mob->{Id}            ? $mob->{Id}            : 0;
	my $level         = defined $mob->{Level}         ? $mob->{Level}         : 1;
	my $hp            = defined $mob->{Hp}            ? $mob->{Hp}            : 1;
	my $attack_range  = defined $mob->{AttackRange}   ? $mob->{AttackRange}   : 0;
	my $skill_range   = defined $mob->{SkillRange}    ? $mob->{SkillRange}    : 0;
	my $attack_delay  = defined $mob->{AttackDelay}   ? $mob->{AttackDelay}   : 0;
	my $attack_motion = defined $mob->{AttackMotion}  ? $mob->{AttackMotion}  : 0;
	my $size          = defined $mob->{Size}          ? $mob->{Size}          : 'Small';
	my $race          = defined $mob->{Race}          ? $mob->{Race}          : 'Formless';
	my $element       = defined $mob->{Element}       ? $mob->{Element}       : 'Neutral';
	my $element_lv    = defined $mob->{ElementLevel}  ? $mob->{ElementLevel}  : 1;
	my $chase_range   = defined $mob->{ChaseRange}    ? $mob->{ChaseRange}    : 0;

	print $out join("\t",
		$id,
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
	), "\n";
}

close $out;
print "Done. Wrote '$outfile'\n";