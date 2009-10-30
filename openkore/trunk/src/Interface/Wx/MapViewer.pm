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
package Interface::Wx::MapViewer;

use strict;
use Wx ':everything';
# vcl code use Wx::Event qw(EVT_PAINT EVT_LEFT_DOWN EVT_MOTION EVT_ERASE_BACKGROUND);
use Wx::Event qw(EVT_SIZE EVT_PAINT EVT_LEFT_DOWN EVT_RIGHT_DOWN EVT_MOTION EVT_MOUSEWHEEL EVT_ERASE_BACKGROUND);
use File::Spec;
use base qw(Wx::Panel);
use FastUtils;
# vcl code use Utils::CallbackList;
use Log qw(message);
use Globals;
use Translation qw(TF);

use constant PI => 3.14;

our %addedHandlers;

sub new {
	my $class = shift;
	my $self = $class->SUPER::new(@_);
	$self->{mapDir} = 'map';
	$self->{points} = [];
	$self->SetBackgroundColour(new Wx::Colour(0, 0, 0));
	
	$self->{destBrush}    = new Wx::Brush(new Wx::Colour(255, 110, 245), wxSOLID);
	$self->{playerBrush}  = new Wx::Brush(new Wx::Colour(0, 200, 0), wxSOLID);
	$self->{monsterBrush} = new Wx::Brush(new Wx::Colour(215, 0, 0), wxSOLID);
	$self->{npcBrush}     = new Wx::Brush(new Wx::Colour(180, 0, 255), wxSOLID);
	$self->{portalBrush}  = new Wx::Brush(new Wx::Colour(255, 128, 64), wxSOLID);
	$self->{slaveBrush}     = new Wx::Brush(new Wx::Colour(0, 0, 215), wxSOLID);
	
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
	
	return $self;
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
	my ($self, $map, $x, $y, $field) = @_;

	$self->{field}{width} = $field->width() if ($field && $field->width());
	$self->{field}{height} = $field->height() if ($field && $field->height());

	if ($map && $map ne $self->{field}{name}) {
		# Map changed
		$self->{field}{name} = $map;
		$self->{field}{x} = $x;
		$self->{field}{y} = $y;
		
		$self->{field}{object} = $field;
		return unless $self->_updateBitmap;
		
		$self->{mapChangeCb}->($self->{mapChangeData}) if ($self->{mapChangeCb});
		$self->{needUpdate} = 1;
		
	} elsif ($x ne $self->{field}{x} || $y ne $self->{field}{y}) {
		# Position changed
		$self->{field}{x} = $x;
		$self->{field}{y} = $y;
		$self->{needUpdate} = 1;
	}
}

sub setDest {
	my ($self, $x, $y) = @_;
	if (defined $x) {
		if ($self->{dest}{x} ne $x && $self->{dest}{y} ne $y) {
			$self->{dest}{x} = $x;
			$self->{dest}{y} = $y;
			$self->{needUpdate} = 1;
		}
	} elsif (defined $self->{dest}) {
		undef $self->{dest};
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

sub setPortals {
	my $self = shift;
	$self->{portals} = shift;
	$self->{needUpdate} = 1;
}

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
		
		my $coord = "$x $y";
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
	if ($self->{mouseMoveCb} && $self->{field}{width} && $self->{field}{height}) {
		$self->{mouseMoveCb}->($self->{mouseMoveData}, $self->_viewToPosXY ($event->GetX, $event->GetY));
	}
}

sub _onWheel {
	my ($self, $event) = @_;
	
	$self->{zoom} *= 2 ** ($event->GetWheelRotation <=> 0);
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
	
	if ($self->GetParent && $self->GetParent->GetSizer) {
		my $sizer = $self->GetParent->GetSizer;
		$sizer->SetItemMinSize ($self, $w, $h);
	}
	
	($self->{view}{xscale}, $self->{view}{yscale}) = (
		$self->{bitmap}->GetWidth / $self->{field}{width},
		$self->{bitmap}->GetHeight / $self->{field}{height},
	);
	
	return 1;
}

sub _loadImage {
	my $file = shift;
	my $scale = shift;
	my ($ext) = $file =~ /.*(\..*?)$/;
	my ($handler, $mime);

	# Initialize required image handler
	if (!$addedHandlers{$ext}) {
		$ext = lc $ext;
		if ($ext eq '.png') {
			$handler = new Wx::PNGHandler();
		} elsif ($ext eq '.jpg' || $ext eq '.jpeg') {
			$handler = new Wx::JPEGHandler();
		} elsif ($ext eq '.bmp') {
			$handler = new Wx::BMPHandler();
		} elsif ($ext eq '.xpm') {
			$handler = new Wx::XPMHandler();
		}

		return unless $handler;
		Wx::Image::AddHandler($handler);
		$addedHandlers{$ext} = 1;
	}

	my $image = Wx::Image->newNameType($file, wxBITMAP_TYPE_ANY);
	
	if ($scale && $scale != 1) {
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
	
	$dc->DrawText ($text, $x - $w / 2, $y);
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
	return unless ($self->{bitmap});
	
	my $dc = new Wx::PaintDC ($self);
	
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
		
		$dc->SetBrush($self->{portalBrush});
		foreach my $pos (@{$self->{portals}->{$self->{field}{name}}}) {
			($x, $y) = $self->_posXYToView($pos->{x}, $pos->{y});
			$dc->DrawEllipse($x - $portal_r, $y - $portal_r, $portal_d, $portal_d);
		}
	}
	
	$dc->SetTextForeground (new Wx::Colour (0, 127, 0));
	if ($self->{players} && @{$self->{players}}) {
		$dc->SetBrush($self->{playerBrush});
		foreach my $pos (@{$self->{players}}) {
			($x, $y) = $self->_posXYToView($pos->{pos_to}{x}, $pos->{pos_to}{y});
			$dc->DrawEllipse($x - $actor_r, $y - $actor_r, $actor_d, $actor_d);
			if ($self->{zoom} >= ($config{wx_map_namesDetail} || 8)) {
				$self->_drawText ($dc, $pos->name, $x, $y);
			}
		}
	}

	$dc->SetTextForeground (new Wx::Colour (127, 0, 0));
	if ($self->{monsters} && @{$self->{monsters}}) {
		$dc->SetBrush($self->{monsterBrush});
		foreach my $pos (@{$self->{monsters}}) {
			($x, $y) = $self->_posXYToView($pos->{pos_to}{x}, $pos->{pos_to}{y});
			$dc->DrawEllipse($x - $actor_r, $y - $actor_r, $actor_d, $actor_d);
			if ($self->{zoom} >= ($config{wx_map_namesDetail} || 8)) {
				$self->_drawText ($dc, $pos->name, $x, $y);
			}
		}
	}

	$dc->SetTextForeground (new Wx::Colour (127, 0, 127));
	if ($self->{npcs} && @{$self->{npcs}}) {
		$dc->SetBrush($self->{npcBrush});
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
		$dc->SetBrush($self->{slaveBrush});
		foreach my $pos (@{$self->{slaves}}) {
			($x, $y) = $self->_posXYToView($pos->{pos_to}{x}, $pos->{pos_to}{y});
			$dc->DrawEllipse($x - $actor_r, $y - $actor_r, $actor_d, $actor_d);
		}
	}
	
	if ($self->{dest}) {
		$dc->SetPen(wxWHITE_PEN);
		$dc->SetBrush($self->{destBrush});
		($x, $y) = $self->_posXYToView($self->{dest}{x}, $self->{dest}{y});
		$dc->DrawEllipse($x - $portal_r, $y - $portal_r, $portal_d, $portal_d);
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
		$dc->DrawEllipse($x - 5, $y - 5, 10, 10);
	}
}

1;
