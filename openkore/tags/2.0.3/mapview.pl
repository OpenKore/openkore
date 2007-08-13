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
	my $msg = <<EOF;
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
use Field;

my $frame;
my $sizer;
my $mapview;
my $status;

my $field;
my $bus;
my %state;

sub OnInit {
	my $self = shift;

	$frame = new Wx::Frame(undef, -1, 'Map viewer', wxDefaultPosition, wxDefaultSize,
		wxDEFAULT_FRAME_STYLE ^ wxMAXIMIZE_BOX);
	$frame->SetClientSize(75, 100);
	$frame->Show(1);

	$sizer = new Wx::BoxSizer(wxVERTICAL);

	$mapview = new Interface::Wx::MapViewer($frame);
	$mapview->setMapDir($options{maps});
	$mapview->onMouseMove->add(undef, \&onMouseMove);
	$mapview->onMapChange->add(undef, \&onMapChange);
	$sizer->Add($mapview, 1, wxGROW);

	$status = new Wx::StatusBar($frame, -1, wxST_SIZEGRIP);
	$status->SetFieldsCount(2);
	$status->SetStatusWidths(80, -1);
	$sizer->Add($status, 0, wxGROW);

	$frame->SetSizer($sizer);

	if ($ARGV[0] eq '') {
		$mapview->onClick->add(undef, \&onClick);

		my $timer = new Wx::Timer($self, 5);
		EVT_TIMER($self, 5, \&onTimer);
		$timer->Start(500);
		onTimer();

		$timer = new Wx::Timer($self, 6);
		EVT_TIMER($self, 6, \&onBusTimer);
		$timer->Start(50);

	} else {
		$field = new Field(file => "$options{fields}/$ARGV[0].fld");
		$mapview->set($ARGV[0], $ARGV[1], $ARGV[2], $field);
		$mapview->update;
	}

	return 1;
}

sub onMouseMove {
	my (undef, undef, $args) = @_;
	my ($x, $y) = @{$args};
	$x = 0 if ($x < 0);
	$y = 0 if ($y < 0);
	$status->SetStatusText("Mouse over: $x, $y", 1);
}

sub onClick {
	my (undef, undef, $args) = @_;
	my ($x, $y) = @{$args};

	if ($state{busHost} && (!$bus || $bus->serverHost() ne $state{busHost} || $bus->serverPort() ne $state{busPort})) {
		require Bus::Client;
		$bus = new Bus::Client(
			host => $state{busHost},
			port => $state{busPort},
			privateOnly => 1,
			userAgent => "Map Viewer"
		);
	}
	if ($bus) {
		$bus->send("MoveTo", {
			TO => $state{busClientID},
			field => $field->name(),
			x => $x,
			y => $y
		});
	}
}

sub onMapChange {
	$frame->SetTitle($field->name());
	$frame->Fit;
}

sub onTimer {
	my $f;
	return unless open($f, "<:utf8", "$options{logs}/state.txt");

	%state = (NPC => [], Monster => [], Player => []);
	while (!eof($f)) {
		my $line = <$f>;
		$line =~ s/[\r\n]//g;
		my ($key, $value) = split /=/, $line, 2;
		if ($key eq 'NPC' || $key eq 'Monster' || $key eq 'Player') {
			my ($x, $y) = split / /, $value;
			push @{$state{$key}}, { x => $x, y => $y };
		} else {
			$state{$key} = $value;
		}
	}
	close $f;

	if (!$field || $state{fieldName} ne $field->name()) {
		eval {
			$field = new Field(file => "$options{fields}/$state{fieldBaseName}.fld",
				loadDistanceMap => 0);
			$field->{name} = $state{fieldName};
		};
	}
	$mapview->set($state{fieldBaseName}, $state{x}, $state{y}, $field);

	my (@npcs, @monsters, @players);
	foreach my $entry (@{$state{NPC}}) {
		my %actor = (pos_to => $entry, pos => $entry);
		push @npcs, \%actor;
	}
	foreach my $entry (@{$state{Monster}}) {
		my %actor = (pos_to => $entry);
		push @monsters, \%actor;
	}
	foreach my $entry (@{$state{Player}}) {
		my %actor = (pos_to => $entry);
		push @players, \%actor;
	}

	$mapview->setMonsters(\@monsters);
	$mapview->setPlayers(\@players);
	$mapview->setNPCs(\@npcs);

	$mapview->update;
	$status->SetStatusText("$state{x}, $state{y}", 0);
}

sub onBusTimer {
	$bus->iterate() if ($bus);
}
