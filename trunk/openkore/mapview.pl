#!/usr/bin/env perl
#########################################################################
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#########################################################################

use strict;
use FindBin qw($RealBin);
use lib "$RealBin/src";
use Getopt::Long;

my %options = (
	fields => 'fields',
	maps => 'map'
);
GetOptions(
	"fields=s" => \$options{fields},
	"maps=s" => \$options{maps},
	"help" => \$options{help}
);

if ($options{help}) {
	my $msg = <<"	EOF";
		mapview.pl [OPTIONS]

		Options:
		 --fields=path        Path to the folder containing .fld files.
		 --maps=path          Path to the folder containing map images.
	EOF
	$msg =~ s/^\t*//gm;
	print $msg;
	exit 1;
}

my $app = new App;
$app->MainLoop;


package App;

use Wx ':everything';
use Wx::Event qw(EVT_TIMER);
use base qw(Wx::App);

use Interface::Wx::MapViewer;

my $frame;
my $sizer;
my $mapview;
my $status;
my %field;

sub OnInit {
	my $self = shift;

	$frame = new Wx::Frame(undef, -1, 'Map viewer');
	$frame->Show(1);

	$sizer = new Wx::BoxSizer(wxVERTICAL);
	$frame->SetSizer($sizer);

	$mapview = new Interface::Wx::MapViewer($frame);
	$mapview->setMapDir($options{maps});
	$mapview->onMouseMove(\&onMouseMove);
	$mapview->onClick(\&onClick);
	$mapview->onMapChange(\&onMapChange);
	$sizer->Add($mapview, 1, wxGROW);

	$status = new Wx::StatusBar($frame, -1, wxST_SIZEGRIP);
	$status->SetFieldsCount(2);
	$status->SetStatusWidths(80, -1);
	$sizer->Add($status, 0, wxGROW);

	my $timer = new Wx::Timer($self, 5);
	EVT_TIMER($self, 5, \&onTimer);
	$timer->Start(500);
	onTimer();
	return 1;
}

sub onMouseMove {
	my (undef, $x, $y) = @_;
	$status->SetStatusText("Mouse over: $x, $y", 1);
}

sub onClick {
}

sub onMapChange {
	$frame->SetTitle("$field{name}");
	$frame->Fit;
}

sub onTimer {
	return unless open(F, "< logs/walk.dat");
	my @lines = <F>;
	close F;
	s/[\r\n]//g foreach (@lines);

	if ($lines[0] ne $field{name}) {
		return unless getField("$options{fields}/$lines[0].fld", \%field);
	}
	$mapview->set($lines[0], $lines[1], $lines[2], \%field);

	my @monsters;
	for (my $i = 3; $i < @lines; $i++) {
		my ($type, $x, $y) = split / /, $lines[$i];
		if ($type eq "ML") {
			my %monster;
			$monster{pos_to} = {x => $x, y => $y};
			push @monsters, \%monster;
		}
	}
	$mapview->setMonsters(\@monsters);

	$mapview->update;
	$status->SetStatusText("$lines[1], $lines[2]", 0);
}


sub getField {
	my $file = shift;
	my $r_hash = shift;

	undef %{$r_hash};
	unless (-e $file) {
		my %aliases = (
			'new_1-1.fld' => 'new_zone01.fld',
			'new_2-1.fld' => 'new_zone01.fld',
			'new_3-1.fld' => 'new_zone01.fld',
			'new_4-1.fld' => 'new_zone01.fld',
			'new_5-1.fld' => 'new_zone01.fld',

			'new_1-2.fld' => 'new_zone02.fld',
			'new_2-2.fld' => 'new_zone02.fld',
			'new_3-2.fld' => 'new_zone02.fld',
			'new_4-2.fld' => 'new_zone02.fld',
			'new_5-2.fld' => 'new_zone02.fld',

			'new_1-3.fld' => 'new_zone03.fld',
			'new_2-3.fld' => 'new_zone03.fld',
			'new_3-3.fld' => 'new_zone03.fld',
			'new_4-3.fld' => 'new_zone03.fld',
			'new_5-3.fld' => 'new_zone03.fld',

			'new_1-4.fld' => 'new_zone04.fld',
			'new_2-4.fld' => 'new_zone04.fld',
			'new_3-4.fld' => 'new_zone04.fld',
			'new_4-4.fld' => 'new_zone04.fld',
			'new_5-4.fld' => 'new_zone04.fld',
		);

		my ($dir, $base) = $file =~ /^(.*[\\\/])?(.*)$/;
		if (exists $aliases{$base}) {
			$file = "${dir}$aliases{$base}";
		}

		if (! -e $file) {
			return 0;
		}
	}

	# Load the .fld file
	$r_hash->{name} = $file;
	$r_hash->{name} =~ s/.*[\\\/]//;
	$r_hash->{name} =~ s/(.*)\..*/$1/;

	open FILE, "< $file";
	binmode(FILE);
	my $data;
	{
		local($/);
		$data = <FILE>;
		close FILE;
		@$r_hash{'width', 'height'} = unpack("S1 S1", substr($data, 0, 4, ''));
		$r_hash->{rawMap} = $data;
	}
	return 1;
}
