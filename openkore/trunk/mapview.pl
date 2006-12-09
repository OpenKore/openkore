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
use lib "$RealBin/src/deps";
use Getopt::Long;

my %options = (
	fields => 'fields',
	maps => 'map',
	logs => 'logs',
);
GetOptions(
	"fields=s" => \$options{fields},
	"maps=s" => \$options{maps},
	"logs=s" => \$options{logs},
	"help" => \$options{help}
);

if ($options{help}) {
	my $msg = <<"	EOF";
		mapview.pl [OPTIONS]

		Options:
		 --fields=path        Path to the folder containing .fld files.
		 --maps=path          Path to the folder containing map images.
		 --logs=path          Path to the folder containing log files.
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
use IPC;

my $frame;
my $sizer;
my $mapview;
my $status;
my %field;
my %ipcInfo;
my $ipc;

sub OnInit {
	my $self = shift;

	$frame = new Wx::Frame(undef, -1, 'Map viewer', wxDefaultPosition, wxDefaultSize,
		wxDEFAULT_FRAME_STYLE ^ wxMAXIMIZE_BOX);
	$frame->SetClientSize(75, 100);
	$frame->Show(1);

	$sizer = new Wx::BoxSizer(wxVERTICAL);

	$mapview = new Interface::Wx::MapViewer($frame);
	$mapview->setMapDir($options{maps});
	$mapview->onMouseMove(\&onMouseMove);
	$mapview->onMapChange(\&onMapChange);
	$sizer->Add($mapview, 1, wxGROW);

	$status = new Wx::StatusBar($frame, -1, wxST_SIZEGRIP);
	$status->SetFieldsCount(2);
	$status->SetStatusWidths(80, -1);
	$sizer->Add($status, 0, wxGROW);

	$frame->SetSizer($sizer);

	if ($ARGV[0] eq '') {
		$mapview->onClick(\&onClick);

		my $timer = new Wx::Timer($self, 5);
		EVT_TIMER($self, 5, \&onTimer);
		$timer->Start(500);
		onTimer();

	} else {
		getField("$options{fields}/$ARGV[0].fld", \%field);
		$field{realName} = $ARGV[0];
		$mapview->set($ARGV[0], $ARGV[1], $ARGV[2], \%field);
		$mapview->update;
	}

	return 1;
}

sub onMouseMove {
	my (undef, $x, $y) = @_;
	$x = 0 if ($x < 0);
	$y = 0 if ($y < 0);
	$status->SetStatusText("Mouse over: $x, $y", 1);
}

sub onClick {
	my (undef, $x, $y) = @_;

	if ($ipcInfo{host} && (!$ipc || $ipc->host ne $ipcInfo{host})) {
		$ipc = new IPC("Map Viewer", $ipcInfo{host}, $ipcInfo{port});
		while ($ipc && $ipc->connected && !$ipc->ready) {
			$ipc->iterate;
		}
	}
	if ($ipc && $ipc->ready && $ipc->connected) {
		$ipc->send("move to",
			TO => $ipcInfo{ID},
			field => $field{realName},
			x => $x,
			y => $y);
	}
}

sub onMapChange {
	$frame->SetTitle("$field{realName}");
	$frame->Fit;
}

sub onTimer {
	return unless open(F, "< $options{logs}/walk.dat");
	my @lines = <F>;
	close F;
	s/[\r\n]//g foreach (@lines);

	my ($fieldName, $fieldBaseName) = split / /, $lines[0];
	if ($fieldName ne $field{name}) {
		return unless getField("$options{fields}/$fieldBaseName.fld", \%field);
		$field{realName} = $fieldName;
	}
	$mapview->set($fieldBaseName, $lines[1], $lines[2], \%field);

	($ipcInfo{host}, $ipcInfo{port}, $ipcInfo{ID}) = split / /, $lines[3];

	my (@monsters, @players, @npcs);
	for (my $i = 4; $i < @lines; $i++) {
		my ($type, $x, $y) = split / /, $lines[$i];
		if ($type eq "ML") {
			my %monster;
			$monster{pos_to} = {x => $x, y => $y};
			push @monsters, \%monster;
		} elsif ($type eq "PL") {
			my %player;
			$player{pos_to} = {x => $x, y => $y};
			push @players, \%player;
		} elsif ($type eq "NL" ) {
			my %npc;
			$npc{pos} = {x => $x, y => $y};
			push @npcs, \%npc;
		}
	}
	$mapview->setMonsters(\@monsters);
	$mapview->setPlayers(\@players);
	$mapview->setNPCs(\@npcs);

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
	$r_hash->{baseName} = $r_hash->{name};

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
