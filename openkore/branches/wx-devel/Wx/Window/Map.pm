#########################################################################
#  OpenKore - WxWidgets Interface
#  Map viewer control
#
#  Copyright (c) 2004 OpenKore development team
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#
#  $Revision$
#  $Id$
#
#########################################################################
package Interface::Wx::Window::Map;

# TODO: rewrite a lot

use strict;
use Wx ':everything';
use Wx::Event qw(EVT_SIZE EVT_PAINT EVT_LEFT_DOWN EVT_RIGHT_DOWN EVT_MOTION EVT_MOUSEWHEEL EVT_ERASE_BACKGROUND);
use File::Spec;
use base 'Wx::Panel';
use FastUtils;
use Log qw(message);
use Globals;
use Translation qw(TF);
use Utils qw(calcPosition distance timeOut);

use constant PI => 3.14;

our %addedHandlers;

sub new {
	my $class = shift;
	my $self = $class->SUPER::new(@_);
	$self->{mapDir} = 'map';
	$self->{points} = [];
	$self->SetBackgroundColour(new Wx::Colour(0, 0, 0));
	
	$self->{brush}{text}        = new Wx::Brush(new Wx::Colour(0, 255, 0), wxSOLID);
	$self->{brush}{dest}        = new Wx::Brush(new Wx::Colour(255, 110, 245), wxSOLID);
	$self->{brush}{party}       = new Wx::Brush(new Wx::Colour(0, 0, 255), wxSOLID);
	$self->{textColor}{party}   = new Wx::Colour (0, 0, 255);
	$self->{brush}{player}      = new Wx::Brush(new Wx::Colour(0, 200, 0), wxSOLID);
	$self->{textColor}{player}  = new Wx::Colour (0, 127, 0);
	$self->{brush}{monster}     = new Wx::Brush(new Wx::Colour(215, 0, 0), wxSOLID);
	$self->{textColor}{monster} = new Wx::Colour (127, 0, 0);
	$self->{brush}{npc}         = new Wx::Brush(new Wx::Colour(180, 0, 255), wxSOLID);
	$self->{textColor}{npc}     = new Wx::Colour (127, 0, 127);
	$self->{brush}{portal}      = new Wx::Brush(new Wx::Colour(255, 128, 64), wxSOLID);
	$self->{textColor}{portal}  = new Wx::Colour (191, 95, 47);
	$self->{brush}{slave}       = new Wx::Brush(new Wx::Colour(0, 0, 127), wxSOLID);
	
	$self->{brush}{gaugeBg}     = new Wx::Brush(new Wx::Colour(63, 63, 63), wxSOLID);
	$self->{brush}{gaugeFg}     = new Wx::Brush(new Wx::Colour(0, 255, 0), wxSOLID);
	$self->{size}{gauge}        = {w => 10, h => 2};
	
	$self->{portalSize} = 3;
	$self->{actorSize} = 2;
	
	$self->{zoom} = 1;
	$self->{view}{x} = 0;
	$self->{view}{y} = 0;
	
	EVT_SIZE($self, \&_onResize);
	EVT_PAINT($self, \&_onPaint);
	EVT_LEFT_DOWN($self, \&_onClick);
	EVT_RIGHT_DOWN($self, \&_onRightClick);
	EVT_MOTION($self, \&_onMotion);
	EVT_MOUSEWHEEL($self, \&_onWheel);
	EVT_ERASE_BACKGROUND($self, \&_onErase);
	
	Scalar::Util::weaken(my $weak = $self);
	
	$self->{hooks} = Plugins::addHooks (
		['packet/minimap_indicator', sub {
			my (undef, $args) = @_;
			
			$weak->indicator(
				$args->{type} != 2,
				$args->{x}, $args->{y},
				$args->{red}, $args->{green}, $args->{blue}, $args->{alpha}
			);
		}],
		['mainLoop_pre', sub {
			my (undef, $args) = @_;
			
			if (timeOut($weak->{updateTime}, 0.15)) {
				$weak->updateGlue;
				$weak->{updateTime} = time;
			}
		}],
	);
	
	$self->onClick(sub { $weak->onMapClick(@_[1,-1]) });
	
	$self->parsePortals(Settings::getTableFilename("portals.txt"));
	if ($field && $char) {
		$self->set($field->name(), $char->{pos_to}{x}, $char->{pos_to}{y}, $field);
	}
	
	$self->{npcs} = [];
	$self->{monsters} = [];
	$self->{slaves} = [];
	
	return $self;
}

sub DESTROY {
	my ($self) = @_;
	
	Plugins::delHooks($self->{hooks});
}

sub updateGlue {
	my $self = shift;
	return unless ($field && $char);

	my $myPos = calcPosition($char);

	$self->set($field->name(), $myPos->{x}, $myPos->{y}, $field, $char->{look});
	
	my ($i, $args, $routeTask, $route);
	$self->setRoute(
		defined ($i = AI::findAction ('route')) && ($args = AI::args ($i)) && (
			($routeTask = $args->getSubtask) && %{$routeTask} && ($route = $routeTask->{solution}) && @$route
			||
			$args->{dest} && $args->{dest}{pos} && ($route = [{x => $args->{dest}{pos}{x}, y => $args->{dest}{pos}{y}}])
		) ? [@$route] : ()
	);
	
	$self->setPlayers ([values %players]);
	$self->setParty ([values %{$char->{party}{users}}]) if $char->{party} && $char->{party}{users};
	$self->setMonsters ([values %monsters]);
	$self->setNPCs ([values %npcs]);
	$self->setSlaves ([values %slaves]);
	
	$self->update;
	#$self->{mapViewTimeout}{time} = time;
}

sub onMapClick {
	# Clicked on map viewer control
	my ($self, $x, $y) = @_;
	
	Plugins::callHook('interface/helpcontext', {});
	Plugins::callHook('interface/defaultFocus', {});
	
	for (
		(map {[$_, $_->{pos}, $config{wx_map_npcSticking} || 1, "talk $_->{binID}"]} @{$self->{npcs}}),
		(map {[$_, $_->{pos}, $config{wx_map_monsterSticking} || 1, "a $_->{binID}"]} @{$self->{monsters}}),
		($self->{portals}{$field->name} ? map {[$_, {x=>$_->{x}, y=>$_->{y}}, $config{wx_map_portalSticking} || 5]} @{$self->{portals}{$field->name}} : ()),
	) {
		my ($actor, $pos, $distance, $command) = @$_;
		
		if (distance($pos, {x=>$x, y=>$y}) <= $distance) {
			if ($command) {
				Commands::run($command);
				return;
			}
			($x, $y) = @$pos{qw/x y/};
		}
	}
	
	Commands::run("move $x $y");
}

#### Events ####

sub onClick {
	my $self = shift;
	my $callback = shift;
	my $user_data = shift;
	$self->{clickCb} = $callback;
	$self->{clickData} = $user_data;
}

sub onMouseMove {
	my $self = shift;
	my $callback = shift;
	my $user_data = shift;
	$self->{mouseMoveCb} = $callback;
	$self->{mouseMoveData} = $user_data;
}

sub onMapChange {
	my $self = shift;
	my $callback = shift;
	my $user_data = shift;
	$self->{mapChangeCb} = $callback;
	$self->{mapChangeData} = $user_data;
}

#### Public methods ####

sub set {
	my ($self, $map, $x, $y, $field, $look) = @_;

	$self->{field}{width} = $field->width() if ($field && $field->width());
	$self->{field}{height} = $field->height() if ($field && $field->height());

	if ($map && $map ne $self->{field}{name}) {
		# Map changed
		$self->{field}{name} = $map;
		$self->{field}{x} = $x;
		$self->{field}{y} = $y;
		$self->{field}{look} = $look;
		
		$self->{field}{object} = $field;
		return unless $self->_updateBitmap;
		
		$self->{mapChangeCb}->($self->{mapChangeData}) if ($self->{mapChangeCb});
		$self->{needUpdate} = 1;
		
	} elsif ($x ne $self->{field}{x} || $y ne $self->{field}{y}) {
		# Position changed
		$self->{field}{x} = $x;
		$self->{field}{y} = $y;
		$self->{field}{look} = $look;
		$self->{needUpdate} = 1;
	}
}

sub setRoute {
	my ($self, $solution) = @_;
	
	if (defined $solution) {
		$self->{route} = $solution;
		$self->{needUpdate} = 1;
	} elsif (defined $self->{route}) {
		undef $self->{route};
		$self->{needUpdate} = 1;
	}
}

sub setMonsters {
	my $self = shift;
	my $monsters = shift;
	my $old = $self->{monsters};

	if (!$old || @{$monsters} != @{$old}) {
		$self->{needUpdate} = 1;
		$self->{monsters} = $monsters;
		return;
	}

	for (my $i = 0; $i < @{$monsters}; $i++) {
		my $pos1 = $monsters->[$i]{pos_to};
		my $pos2 = $old->[$i]{pos_to};
		if ($pos1->{x} != $pos2->{x} && $pos1->{y} != $pos2->{y}) {
			$self->{needUpdate} = 1;
			$self->{monsters} = $monsters;
			return;
		}
	}
}

# UNUSED
#sub setPortals {
#	my $self = shift;
#	$self->{portals} = shift;
#	$self->{needUpdate} = 1;
#}

sub setPlayers {
	my $self = shift;
	my $players = shift;
	my $old = $self->{players};

	if (!$old || @{$players} != @{$old}) {
		$self->{needUpdate} = 1;
		$self->{players} = $players;
		return;
	}

	for (my $i = 0; $i < @{$players}; $i++) {
		my $pos1 = $players->[$i]{pos_to};
		my $pos2 = $old->[$i]{pos_to};
		if ($pos1->{x} != $pos2->{x} && $pos1->{y} != $pos2->{y}) {
			$self->{needUpdate} = 1;
			$self->{players} = $players;
			return;
		}
	}
}

sub setParty {
	my ($self, $players) = @_;
	
	unless ($self->{party} and @$players == @{$self->{party}}) {
		$self->{needUpdate} = 1;
		$self->{party} = $players;
	} else {
		for (my $i = 0; $i < @$players; $i++) {
			next if $players->[$i]{ID} eq $accountID
			or $players->[$i]{map} ne $self->{party}[$i]{map}
			or $players->[$i]{online} == $self->{party}[$i]{online}
			&& $players->[$i]{pos}{x} == $self->{party}[$i]{pos}{x}
			&& $players->[$i]{pos}{y} == $self->{party}[$i]{pos}{y}
			&& $players->[$i]{hp} == $self->{party}[$i]{hp}
			&& $players->[$i]{hp_max} == $self->{party}[$i]{hp_max};
			
			$self->{needUpdate} = 1;
			$self->{party} = $players;
			last;
		}
	}
}

sub setNPCs {
	my $self = shift;
	my $npcs = shift;
	my $old = $self->{npcs};

	if (!$old || @{$npcs} != @{$old}) {
		$self->{needUpdate} = 1;
		$self->{npcs} = $npcs;
		return;
	}

	for (my $i = 0; $i < @{$npcs}; $i++) {
		my $pos1 = $npcs->[$i]{pos};
		my $pos2 = $old->[$i]{pos};
		if ($pos1->{x} != $pos2->{x} && $pos1->{y} != $pos2->{y}) {
			$self->{needUpdate} = 1;
			$self->{npcs} = $npcs;
			return;
		}
	}
}

sub setSlaves {
	my $self = shift;
	my $slaves = shift;
	my $old = $self->{slaves};

	if (!$old || @{$slaves} != @{$old}) {
		$self->{needUpdate} = 1;
		$self->{slaves} = $slaves;
		return;
	}

	for (my $i = 0; $i < @{$slaves}; $i++) {
		my $pos1 = $slaves->[$i]{pos_to};
		my $pos2 = $old->[$i]{pos_to};
		if ($pos1->{x} != $pos2->{x} && $pos1->{y} != $pos2->{y}) {
			$self->{needUpdate} = 1;
			$self->{slaves} = $slaves;
			return;
		}
	}
}

sub indicator {
	my ($self, $show, $x, $y, $r, $g, $b, $a) = @_;
	
	if ($show) {
		$self->{indicators}{$self->{field}{name}}{"$x $y"} = {
			x => $x, y => $y, color => [$r, $g, $b, $a],
		};
	} elsif ($self->{indicators}{$self->{field}{name}}) {
		delete $self->{indicators}{$self->{field}{name}}{"$x $y"};
	}
	
	$self->{needUpdate} = 1;
}

sub update {
	my $self = shift;
	if ($self->{needUpdate}) {
		$self->{needUpdate} = 0;
		$self->Refresh;
	}
}

sub mapSize {
	my $self = shift;
	if ($self->{bitmap}) {
		return ($self->{bitmap}->GetWidth, $self->{bitmap}->GetHeight);
	} else {
		return (50, 50);
	}
}

sub setMapDir {
	my $self = shift;
	$self->{mapDir} = shift;
}

sub parsePortals {
	my $self = shift;
	my $file = shift;
	return unless (-r $file);
	open FILE, "< $file";
	$self->{portals} = {};
	while (my $line = <FILE>) {
		next if $line =~ /^#/;
		$line =~ s/\cM|\cJ//g;
		$line =~ s/\s+/ /g;
		$line =~ s/^\s+|\s+$//g;
		my @args = split /\s/, $line, 8;
		if (@args > 5) {
			$self->{portals}->{$args[0]} = [] unless defined $self->{portals}->{$args[0]};
			push (@{$self->{portals}->{$args[0]}}, {
				x => $args[1],
				y => $args[2],
				destination => {
					field => $args[3],
					x => $args[4],
					y => $args[5],
				},
				zeny => $args[7],
			});
		}
	}
	close FILE;
}

#### Private ####

sub _onResize {
	my $self = shift;
	$self->{needUpdate} = 1;
}

sub _onClick {
	my ($self, $event) = @_;
	if ($self->{clickCb} && $self->{field}{width} && $self->{field}{height}) {
		$self->{clickCb}->($self->{clickData}, $self->_viewToPosXY ($event->GetX, $event->GetY));
	}
}

sub _onRightClick {
	my ($self, $event) = @_;
	if ($self->{clickCb} && $self->{field}{width} && $self->{field}{height}) {
		my ($x, $y) = $self->_viewToPosXY ($event->GetX, $event->GetY);
		
		my $map = $field{name};
		AI::clear(qw/move route mapRoute/);
		message TF("Walking to waypoint: $x, $y\n"), "success";
		main::ai_route($map, $x, $y,
		attackOnRoute => 2,
		noSitAuto => 1,
		notifyUponArrival => 1);
	}
}

sub _onMotion {
	my ($self, $event) = @_;
	
	if ($self->{field}{width} && $self->{field}{height}) {
		my ($x, $y) = $self->_viewToPosXY ($event->GetX, $event->GetY);
		if ($x >= 0 && $y >= 0 && $field->isWalkable($x, $y)) {
			Plugins::callHook('interface/helpcontext', {
				message => TF("Mouse over: %d, %d", $x, $y)
			});
		} else {
			Plugins::callHook('interface/helpcontext', {});
		}
	}
}

sub _onWheel {
	my ($self, $event) = @_;
	
	$self->{zoom} *= 2 ** ($event->GetWheelRotation <=> 0);
	$self->{zoom} = 8 if $self->{zoom} > 8;
	$self->{zoom} = 0.5 if $self->{zoom} < 0.5;
	$self->_updateBitmap;
	$self->{needUpdate} = 1;
}

sub _onErase {
	my ($self, $event) = @_;
	if ($self->{bitmap}) {
		# Do nothing; prevent flickering when drawing
	} else {
		$event->Skip;
	}
}

sub _updateBitmap {
	my ($self) = @_;
	
	undef $self->{bitmap};
	$self->{bitmap} = $self->_loadMapImage ($self->{field}{object});
	return unless $self->{bitmap};
	
	my ($w, $h) = ($self->{bitmap}->GetWidth, $self->{bitmap}->GetHeight);
	my $maxAutoSize = $config{wx_map_maxAutoSize} || 300;
	$w = $maxAutoSize if $w > $maxAutoSize;
	$h = $maxAutoSize if $h > $maxAutoSize;
	
	$self->SetSizeHints ($w, $h);
	
	## introduces problems with AUI
	#if ($self->GetParent && $self->GetParent->GetSizer) {
	#	my $sizer = $self->GetParent->GetSizer;
	#	$sizer->SetItemMinSize ($self, $w, $h);
	#}
	
	($self->{view}{xscale}, $self->{view}{yscale}) = (
		$self->{bitmap}->GetWidth / $self->{field}{width},
		$self->{bitmap}->GetHeight / $self->{field}{height},
	);
	
	return 1;
}

sub _loadImage {
	my ($file, $scale) = @_;
	
	my ($ext) = $file =~ /.*(\..*?)$/;
	my ($handler, $mime);
	
	my $image = Wx::Image->newNameType($file, wxBITMAP_TYPE_ANY);
	
	if (defined $scale && $scale != 1) {
		$image->Rescale ($image->GetWidth * $scale, $image->GetHeight * $scale);
	}
	
	my $bitmap = new Wx::Bitmap($image);
	return ($bitmap && $bitmap->Ok()) ? $bitmap : undef;
}

sub _map {
	my $self = shift;
	return File::Spec->catfile($self->{mapDir}, @_);
}

sub _f {
	return File::Spec->catfile(@_);
}

sub _loadMapImage {
	my $self = shift;
	my $field = shift;
	my $name = $field->{baseName};

	if (-f $self->_map("$name.jpg")) {
		return _loadImage($self->_map("$name.jpg"), $self->{zoom});
	} elsif (-f $self->_map("$name.png")) {
		return _loadImage($self->_map("$name.png"), $self->{zoom});
	} elsif (-f $self->_map("$name.bmp")) {
		return _loadImage($self->_map("$name.bmp"), $self->{zoom});

	} else {
		my $file = _f(File::Spec->tmpdir(), "map.xpm");
		return unless (open(F, ">", $file));
		binmode F;
		print F Utils::xpmmake($field->width(), $field->height(), $field->{rawMap});
		close F;
		my $bitmap = _loadImage($file, $self->{zoom});
		unlink $file;
		return $bitmap;
	}
}

sub _drawArrow {
	my ($self, $dc, $x1, $y1, $x2, $y2, $size) = @_;
	
	my $a = atan2 $y2 - $y1, $x2 - $x1;
	my ($a1, $a2) = ($a - PI / 8, $a + PI / 8);
	
	$dc->DrawLine ($x1, $y1, $x2, $y2);
	$dc->DrawLine ($x2, $y2, $x2 - $size * cos $a1, $y2 - $size * sin $a1);
	$dc->DrawLine ($x2, $y2, $x2 - $size * cos $a2, $y2 - $size * sin $a2);
}

sub _drawText {
	my ($self, $dc, $text, $x, $y) = @_;
	
	my ($w, $h, $descent, $externalLeading) = $dc->GetTextExtent ($text);
	
	my $brush = $dc->GetBrush;
	$dc->SetBrush ($self->{brush}{text});
	$dc->DrawText ($text, $x - $w / 2, $y);
	$dc->SetBrush ($brush);
}

sub _drawGauge {
	my ($self, $dc, $value, $x, $y) = @_;
	
	my ($pen, $brush) = ($dc->GetPen, $dc->GetBrush);
	
	my ($cx, $cy, $cw, $ch) = (
		$x - $self->{size}{gauge}{w},
		$y - $self->{size}{gauge}{h} * 3,
		2 * $self->{size}{gauge}{w},
		2 * $self->{size}{gauge}{h}
	);
	
	$dc->SetPen (wxBLACK_PEN);
	$dc->SetBrush ($self->{brush}{gaugeBg});
	$dc->DrawRectangle ($cx, $cy, $cw, $ch);
	$dc->SetPen (wxTRANSPARENT_PEN);
	$dc->SetBrush ($self->{brush}{gaugeFg});
	$dc->DrawRectangle ($cx + 1, $cy + 1, ($cw - 2) * $value, $ch - 2);
	
	$dc->SetPen ($pen); $dc->SetBrush ($brush);
}

sub _drawLook {
	my ($self, $dc, $look, $x, $y, $r) = @_;
	
	return unless defined $look->{body};
	
	my $ar = PI / 4 * ($look->{body} + 2);
	
	$dc->DrawPolygon ([
		[$x - $r * (sin $ar), $y - $r * cos $ar],
		[$x + $r * (sin $ar), $y + $r * cos $ar],
		[$x + 2 * $r * (cos $ar), $y - 2 * $r * sin $ar],
	], 0, 0, wxODDEVEN_RULE);
}

sub _posXYToView {
	my ($self, $x, $y) = @_;
	return (
		$x * $self->{view}{xscale} - $self->{view}{x},
		($self->{field}{height} - $y) * $self->{view}{yscale} - $self->{view}{y},
	);
}

sub _viewToPosXY {
	my ($self, $x, $y) = @_;
	return (
		int (($x + $self->{view}{x}) / $self->{view}{xscale}),
		int ($self->{field}{height} - ($y + $self->{view}{y}) / $self->{view}{yscale}),
	);
}

sub _viewCharacter {
	my ($self) = @_;
	($self->{view}{x}, $self->{view}{y}) = (
		$self->{field}{x} * $self->{view}{xscale} - $self->{view}{width} / 2,
		($self->{field}{height} - $self->{field}{y}) * $self->{view}{yscale} - $self->{view}{height} / 2,
	);
}

sub _viewFix {
	my ($self) = @_;
	
	$self->{view}{x} = $self->{field}{width} * $self->{view}{xscale} - $self->{view}{width}
	if $self->{view}{x} + $self->{view}{width} > $self->{field}{width} * $self->{view}{xscale};
	
	$self->{view}{x} = 0 if $self->{view}{x} < 0;
	
	$self->{view}{y} = $self->{field}{height} * $self->{view}{yscale} - $self->{view}{height}
	if $self->{view}{y} + $self->{view}{height} > $self->{field}{height} * $self->{view}{yscale};
	
	$self->{view}{y} = 0 if $self->{view}{y} < 0;
}

# vcl code sub _handlePaintEvent {
sub _onPaint {
	my $self = shift;
	
	# must be before return
	my $paintDC = new Wx::PaintDC ($self);
	
	return unless $self->{bitmap};
	
	my $dc = new Wx::MemoryDC ();
	$dc->SelectObject (new Wx::Bitmap ($paintDC->GetSizeWH));
	
	my ($portal_r, $actor_r) = ($self->{portalSize}, $self->{actorSize});
	my ($portal_d, $actor_d) = map {$_ * 2} ($portal_r, $actor_r);
	
	# viewport
	
	($self->{view}{width}, $self->{view}{height}) = ($self->GetSize->GetWidth, $self->GetSize->GetHeight);
	$self->_viewCharacter;
	$self->_viewFix;
	
	# field
	
	$dc->SetPen(wxBLACK_PEN);
	$dc->SetBrush(wxBLACK_BRUSH);
	
	my ($x, $y) = $self->_posXYToView(0, $self->{field}{height});
	my ($h, $w) = ($self->{bitmap}->GetHeight, $self->{bitmap}->GetWidth);
	
	$dc->DrawRectangle (0, 0, $x, $self->{view}{height}) if $x > 0;
	$dc->DrawRectangle ($x + $w, 0, $self->{view}{width}, $self->{view}{height}) if $x + $w < $self->{view}{width};
	$dc->DrawRectangle (0, 0, $self->{view}{width}, $y) if $y > 0;
	$dc->DrawRectangle (0, $y + $h, $self->{view}{width}, $self->{view}{height}) if $y + $h < $self->{view}{height};
	$dc->DrawBitmap ($self->{bitmap}, $x, $y, 1);
	
	if ($self->{indicators}{$self->{field}{name}}) {
		foreach my $item (values %{$self->{indicators}{$self->{field}{name}}}) {
			my $color = new Wx::Colour (@{$item->{color}});
			$dc->SetBrush (new Wx::Brush ($color, wxSOLID));
			($x, $y) = $self->_posXYToView($item->{x}, $item->{y});
			$dc->DrawPolygon ([
				[$x - 2, $y - 2],
				[$x - 2, $y - 6],
				[$x + 2, $y - 6],
				[$x + 2, $y - 2],
				[$x + 6, $y - 2],
				[$x + 6, $y + 2],
				[$x + 2, $y + 2],
				[$x + 2, $y + 6],
				[$x - 2, $y + 6],
				[$x - 2, $y + 2],
				[$x - 6, $y + 2],
				[$x - 6, $y - 2],
			], 0, 0, wxODDEVEN_RULE);
		}
	}
	
	# portals
	
	if ($self->{portals} && $self->{portals}->{$self->{field}{name}} && @{$self->{portals}->{$self->{field}{name}}}) {
		if ($config{wx_map_portalDestinations}) {
			$dc->SetPen(wxRED_PEN);
			foreach my $pos (@{$self->{portals}->{$self->{field}{name}}}) {
				if ($self->{field}{name} eq $pos->{destination}{field}) {
#					if (
#						(abs $pos->{x} - $self->{field}{x}) <= $config{clientSight}
#						and (abs $pos->{y} - $self->{field}{y}) <= $config{clientSight}
#					) {
						($x, $y) = $self->_posXYToView($pos->{x}, $pos->{y});
						my ($dest_x, $dest_y) = $self->_posXYToView($pos->{destination}{x}, $pos->{destination}{y});
						$self->_drawArrow($dc, $x, $y, $dest_x, $dest_y, 8);
#					}
				}
			}
			$dc->SetPen(wxBLACK_PEN);
		}
		
		$dc->SetBrush($self->{brush}{portal});
		$dc->SetTextForeground ($self->{textColor}{portal});
		foreach my $pos (@{$self->{portals}->{$self->{field}{name}}}) {
			($x, $y) = $self->_posXYToView($pos->{x}, $pos->{y});
			$dc->DrawEllipse($x - $portal_r, $y - $portal_r, $portal_d, $portal_d);
			if ($self->{zoom} >= ($config{wx_map_namesDetail} || 8)) {
				$self->_drawText (
					$dc,
					$self->{field}{name} ne $pos->{destination}{field} ? $pos->{destination}{field} : "($pos->{destination}{x}, $pos->{destination}{y})",
					$x, $y
				);
			}
		}
	}
	
	# players
	
	$dc->SetTextForeground ($self->{textColor}{player});
	if ($self->{players} && @{$self->{players}}) {
		$dc->SetBrush($self->{brush}{player});
		foreach my $pos (@{$self->{players}}) {
			($x, $y) = $self->_posXYToView($pos->{pos_to}{x}, $pos->{pos_to}{y});
			$self->_drawLook ($dc, $pos->{look}, $x, $y, $actor_r);
			$dc->DrawEllipse($x - $actor_r, $y - $actor_r, $actor_d, $actor_d);
			if ($self->{zoom} >= ($config{wx_map_playerNameZoom} || 8)) {
				$self->_drawText ($dc, $pos->name, $x, $y);
			}
		}
	}
	
	# party
	
	if ($self->{party} && @{$self->{party}}) {
		$dc->SetBrush($self->{brush}{party});
		$dc->SetTextForeground ($self->{textColor}{party});
		foreach my $pos (@{$self->{party}}) {
			next unless $pos->{ID} ne $accountID && $pos->{map} eq $self->{field}{name}.'.gat' && $pos->{online} && $pos->{pos}{x};
			
			($x, $y) = $self->_posXYToView($pos->{pos}{x}, $pos->{pos}{y});
			$dc->DrawEllipse($x - $actor_r, $y - $actor_r, $actor_d, $actor_d);
			if ($self->{zoom} >= ($config{wx_map_partyNameZoom} || 1)) {
				$self->_drawText ($dc, $pos->{name}, $x, $y);
				$self->_drawGauge ($dc, $pos->{hp} / $pos->{hp_max}, $x, $y) if $pos->{hp_max};
			}
		}
	}
	
	# monsters
	
	$dc->SetTextForeground ($self->{textColor}{monster});
	if ($self->{monsters} && @{$self->{monsters}}) {
		$dc->SetBrush($self->{brush}{monster});
		foreach my $pos (@{$self->{monsters}}) {
			($x, $y) = $self->_posXYToView($pos->{pos_to}{x}, $pos->{pos_to}{y});
			$self->_drawLook ($dc, $pos->{look}, $x, $y, $actor_r);
			$dc->DrawEllipse($x - $actor_r, $y - $actor_r, $actor_d, $actor_d);
			if ($self->{zoom} >= ($config{wx_map_namesDetail} || 8)) {
				$self->_drawText ($dc, $pos->name, $x, $y);
			}
		}
	}
	
	$dc->SetTextForeground ($self->{textColor}{npc});
	if ($self->{npcs} && @{$self->{npcs}}) {
		$dc->SetBrush($self->{brush}{npc});
		foreach my $pos (@{$self->{npcs}}) {
			($x, $y) = $self->_posXYToView($pos->{pos}{x}, $pos->{pos}{y});
			$dc->DrawEllipse($x - $actor_r, $y - $actor_r, $actor_d, $actor_d);
			if ($self->{zoom} >= ($config{wx_map_namesDetail} || 8)) {
				my $name = $pos->name; $name =~ s/#.*$//;
				$self->_drawText ($dc, $name, $x, $y);
			}
		}
	}
	
	if ($self->{slaves} && @{$self->{slaves}}) {
		$dc->SetBrush($self->{brush}{slave});
		foreach my $pos (@{$self->{slaves}}) {
			($x, $y) = $self->_posXYToView($pos->{pos_to}{x}, $pos->{pos_to}{y});
			$dc->DrawEllipse($x - $actor_r, $y - $actor_r, $actor_d, $actor_d);
		}
	}
	
	if ($self->{route} && @{$self->{route}}) {
		$dc->SetPen(wxWHITE_PEN);
		$dc->SetBrush($self->{brush}{dest});
		
		if ($config{wx_map_route}) {
			my $i = 0;
			for (grep {not $i++ % ($portal_d * 2)} reverse @{$self->{route}}) {
				($x, $y) = $self->_posXYToView ($_->{x}, $_->{y});
				$dc->DrawEllipse($x - $portal_r, $y - $portal_r, $portal_d, $portal_d);
			}
		} else {
			($x, $y) = $self->_posXYToView ($self->{route}[-1]{x}, $self->{route}[-1]{y});
			$dc->DrawEllipse($x - $portal_r, $y - $portal_r, $portal_d, $portal_d);
		}
		
		$dc->SetPen(wxBLACK_PEN);
	}
	
	if (!$self->{selfDot}) {
		my $file = $self->_map("kore.png");
		$self->{selfDot} = _loadImage($file) if (-f $file);
	}
	
	($x, $y) = $self->_posXYToView($self->{field}{x}, $self->{field}{y});
	if ($self->{selfDot}) {
		$dc->DrawBitmap($self->{selfDot},
			$x - ($self->{selfDot}->GetHeight() / 2),
			$y - ($self->{selfDot}->GetHeight() / 2),
			1);
	} else {
		$dc->SetBrush(wxCYAN_BRUSH);
		$self->_drawLook ($dc, $self->{field}{look}, $x, $y, 5);
		$dc->DrawEllipse($x - 5, $y - 5, 10, 10);
	}
	
	$paintDC->Blit (0, 0, $paintDC->GetSizeWH, $dc, 0, 0);
}

1;
