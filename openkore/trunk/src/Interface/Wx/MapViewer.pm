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
use Wx::Event qw(EVT_PAINT EVT_LEFT_DOWN EVT_RIGHT_DOWN EVT_MOTION EVT_ERASE_BACKGROUND);
use File::Spec;
use base qw(Wx::Panel);
use FastUtils;
# vcl code use Utils::CallbackList;
use Log qw(message);
use Globals;
use Translation qw(TF);


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
# vcl code 	EVT_PAINT($self, \&_handlePaintEvent);
# vcl code 	EVT_LEFT_DOWN($self, \&_handleLeftDownEvent);
# vcl code 	EVT_MOTION($self, \&_handleMotionEvent);
# vcl code 	EVT_ERASE_BACKGROUND($self, \&_handleEraseEvent);

	EVT_PAINT($self, \&_onPaint);
	EVT_LEFT_DOWN($self, \&_onClick);
	EVT_RIGHT_DOWN($self, \&_onRightClick);
	EVT_MOTION($self, \&_onMotion);
	EVT_ERASE_BACKGROUND($self, \&_onErase);


# vcl code 	$self->{onClick} = new CallbackList();
# vcl code 	$self->{onMouseMove} = new CallbackList();
# vcl code 	$self->{onMapChange} = new CallbackList();

	return $self;
}


#### Events ####

# vcl code sub onClick {
# vcl code 	return $_[0]->{onClick};
# vcl code }

# vcl code sub onMouseMove {
# vcl code 	return $_[0]->{onMouseMove};
# vcl code }

# vcl code sub onMapChange {
# vcl code 	return $_[0]->{onMapChange};
# vcl code }

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
		undef $self->{bitmap};
		$self->{field}{name} = $map;
		$self->{field}{x} = $x;
		$self->{field}{y} = $y;

		my $bitmap = $self->{bitmap} = $self->_loadMapImage($field);
		return unless $bitmap;
		$self->SetSizeHints($bitmap->GetWidth, $bitmap->GetHeight);
		if ($self->GetParent && $self->GetParent->GetSizer) {
			my $sizer = $self->GetParent->GetSizer;
			$sizer->SetItemMinSize($self, $bitmap->GetWidth, $bitmap->GetHeight);
		}

# vcl code 		$self->{onMapChange}->call($self);
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
			push (@{$self->{portals}->{$args[0]}},{x=>$args[1],y=>$args[2]});
		}
	}
	close FILE;
}


#### Private ####


# vcl code sub _handleLeftDownEvent {
sub _onClick {
	my $self = shift;
	my $event = shift;
# vcl code 	if (!$self->{onClick}->empty() && $self->{field}{width} && $self->{field}{height}) {
		if ($self->{clickCb} && $self->{field}{width} && $self->{field}{height}) {
		my ($x, $y, $xscale, $yscale);
		$xscale = $self->{field}{width} / $self->{bitmap}->GetWidth();
		$yscale = $self->{field}{height} / $self->{bitmap}->GetHeight();
		$x = $event->GetX * $xscale;
		$y = $self->{field}{height} - ($event->GetY * $yscale);

# vcl code 		$self->{onClick}->call($self, [int $x, int $y]);
		$self->{clickCb}->($self->{clickData}, int $x, int $y);
	}
}

# vcl code sub _handleMotionEvent {
sub _onRightClick {
	my $self = shift;
	my $event = shift;
# vcl code 	if (!$self->{onMouseMove}->empty() && $self->{field}{width} && $self->{field}{height}) {
	if ($self->{clickCb} && $self->{field}{width} && $self->{field}{height}) {
		my ($x, $y, $xscale, $yscale);
		$xscale = $self->{field}{width} / $self->{bitmap}->GetWidth();
		$yscale = $self->{field}{height} / $self->{bitmap}->GetHeight();
		$x = $event->GetX * $xscale;
		$y = $self->{field}{height} - ($event->GetY * $yscale);

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
	my $self = shift;
	my $event = shift;
	if ($self->{mouseMoveCb} && $self->{field}{width} && $self->{field}{height}) {
		my ($x, $y, $xscale, $yscale);
		$xscale = $self->{field}{width} / $self->{bitmap}->GetWidth;
		$yscale = $self->{field}{height} / $self->{bitmap}->GetHeight;
		$x = $event->GetX * $xscale;
		$y = $self->{field}{height} - ($event->GetY * $yscale);

# vcl code 			$self->{onMouseMove}->call($self, [int $x, int $y]);
		$self->{mouseMoveCb}->($self->{mouseMoveData}, int $x, int $y);
	}
}

# vcl code sub _handleEraseEvent {
sub _onErase {
	my $self = shift;
	if ($self->{bitmap}) {
		# Do nothing; prevent flickering when drawing
	} else {
		my $event = shift;
		$event->Skip;
	}
}

sub _loadImage {
	my $file = shift;
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
		return _loadImage($self->_map("$name.jpg"));
	} elsif (-f $self->_map("$name.png")) {
		return _loadImage($self->_map("$name.png"));
	} elsif (-f $self->_map("$name.bmp")) {
		return _loadImage($self->_map("$name.bmp"));

	} else {
		my $file = _f(File::Spec->tmpdir(), "map.xpm");
		return unless (open(F, ">", $file));
		binmode F;
		print F Utils::xpmmake($field->width(), $field->height(), $field->{rawMap});
		close F;
		my $bitmap = _loadImage($file);
		unlink $file;
		return $bitmap;
	}
}

sub _posXYToView {
	my ($self, $x, $y) = @_;
	my ($xscale, $yscale);
	$xscale = $self->{bitmap}->GetWidth / $self->{field}{width};
	$yscale = $self->{bitmap}->GetHeight / $self->{field}{height};
	$x *= $xscale;
	$y = ($self->{field}{height} - $y) * $yscale;
	return ($x, $y);
}

# vcl code sub _handlePaintEvent {
sub _onPaint {
	my $self = shift;
	my $dc = new Wx::PaintDC($self);
	return unless ($self->{bitmap});

	my ($x, $y);

	$dc->SetPen(wxBLACK_PEN);
	$dc->SetBrush(wxBLACK_BRUSH);

	my ($h, $w) = ($self->{bitmap}->GetHeight, $self->{bitmap}->GetWidth);
	$dc->DrawRectangle($w, 0,
		$self->GetSize->GetWidth - $w,
		$self->GetSize->GetHeight);
	$dc->DrawRectangle(0, $h,
		$w, $self->GetSize->GetHeight - $h);
	$dc->DrawBitmap($self->{bitmap}, 0, 0, 1);

	if ($self->{portals} && $self->{portals}->{$self->{field}{name}} && @{$self->{portals}->{$self->{field}{name}}}) {
		$dc->SetBrush($self->{portalBrush});
		foreach my $pos (@{$self->{portals}->{$self->{field}{name}}}) {
			($x, $y) = $self->_posXYToView($pos->{x}, $pos->{y});
			$dc->DrawEllipse($x - 3, $y - 3, 6, 6);
		}
	}

	if ($self->{players} && @{$self->{players}}) {
		$dc->SetBrush($self->{playerBrush});
		foreach my $pos (@{$self->{players}}) {
			($x, $y) = $self->_posXYToView($pos->{pos_to}{x}, $pos->{pos_to}{y});
			$dc->DrawEllipse($x - 2, $y - 2, 4, 4);
		}
	}

	if ($self->{monsters} && @{$self->{monsters}}) {
		$dc->SetBrush($self->{monsterBrush});
		foreach my $pos (@{$self->{monsters}}) {
			($x, $y) = $self->_posXYToView($pos->{pos_to}{x}, $pos->{pos_to}{y});
			$dc->DrawEllipse($x - 2, $y - 2, 4, 4);
		}
	}

	if ($self->{npcs} && @{$self->{npcs}}) {
		$dc->SetBrush($self->{npcBrush});
		foreach my $pos (@{$self->{npcs}}) {
			($x, $y) = $self->_posXYToView($pos->{pos}{x}, $pos->{pos}{y});
			$dc->DrawEllipse($x - 2, $y - 2, 4, 4);
		}
	}

	if ($self->{dest}) {
		$dc->SetPen(wxWHITE_PEN);
		$dc->SetBrush($self->{destBrush});
		($x, $y) = $self->_posXYToView($self->{dest}{x}, $self->{dest}{y});
		$dc->DrawEllipse($x - 3, $y - 3, 6, 6);
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
