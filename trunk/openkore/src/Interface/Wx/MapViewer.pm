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
use Wx::Event qw(EVT_PAINT EVT_LEFT_DOWN EVT_MOTION);
use File::Spec;
use base qw(Wx::Panel);

our %addedHandlers;

sub new {
	my $class = shift;
	my $self = $class->SUPER::new(@_);
	$self->{points} = [];
	$self->SetBackgroundColour(new Wx::Colour(0, 0, 0));
	EVT_PAINT($self, \&_onPaint);
	EVT_LEFT_DOWN($self, \&_onClick);
	EVT_MOTION($self, \&_onMotion);
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

	$self->{field}{width} = $field->{width} if ($field && $field->{width});
	$self->{field}{height} = $field->{height} if ($field && $field->{height});

	if ($map && $map ne $self->{field}{name}) {
		# Map changed
		undef $self->{bitmap};
		$self->{field}{name} = $map;
		$self->{field}{x} = $x;
		$self->{field}{y} = $y;

		my $bitmap = $self->{bitmap} = $self->_loadMapImage($field);
		return unless $bitmap;
		$self->SetSizeHints($bitmap->GetWidth, $bitmap->GetHeight);
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

sub update {
	my $self = shift;
	if ($self->{needUpdate}) {
		$self->{needUpdate} = 0;
		$self->Refresh;
	}
}


#### Private ####

sub _onClick {
	my $self = shift;
	my $event = shift;
	if ($self->{clickCb} && $self->{field}{width} && $self->{field}{height}) {
		my ($x, $y, $xscale, $yscale);
		$xscale = $self->{field}{width} / $self->{bitmap}->GetWidth();
		$yscale = $self->{field}{height} / $self->{bitmap}->GetHeight();
		$x = $event->GetX * $xscale;
		$y = $self->{field}{height} - ($event->GetY * $yscale);

		$self->{clickCb}->($self->{clickData}, int $x, int $y);
	}
}

sub _onMotion {
	my $self = shift;
	my $event = shift;
	if ($self->{mouseMoveCb} && $self->{field}{width} && $self->{field}{height}) {
		my ($x, $y, $xscale, $yscale);
		$xscale = $self->{field}{width} / $self->{bitmap}->GetWidth();
		$yscale = $self->{field}{height} / $self->{bitmap}->GetHeight();
		$x = $event->GetX * $xscale;
		$y = $self->{field}{height} - ($event->GetY * $yscale);

		$self->{mouseMoveCb}->($self->{mouseMoveData}, int $x, int $y);
	}
}


sub _xpmmake {
	my $field = shift;
	my $data = "/* XPM */\n" .
		"static char * my_xpm[] = {\n" .
		"\"$field->{width} $field->{height} 3 1\",\n" .
		"\" \tc #000000\",\n" .
		"\"A\tc #6666FF\",\n" .
		"\".\tc #FFFFFF\",\n";
	for (my $y = $field->{height} - 1; $y >= 0; $y--) {
		$data .= "\"";
		for (my $x = 0; $x < $field->{width}; $x++) {
			my $char = substr($field->{rawMap}, $y * $field->{width} + $x, 1);
			if ($char eq "\0") {
				$data .= '.';
			} elsif ($char eq "\1") {
				$data .= ' ';
			} else {
				$data .= 'A';
			}
		}
		$data .= "\",\n";
	}
	$data .= "};\n";
	return $data;
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

sub _f {
	return File::Spec->catfile(@_);
}

sub _loadMapImage {
	my $self = shift;
	my $field = shift;
	my $name = $field->{name};

	if (-f _f("map", "$name.jpg")) {
		return _loadImage(_f("map", "$name.jpg"));
	} elsif (-f _f("map", "$name.png")) {
		return _loadImage(_f("map", "$name.png"));
	} elsif (-f _f("map", "$name.bmp")) {
		return _loadImage(_f("map", "$name.bmp"));

	} else {
		my $file = _f(File::Spec->tmpdir(), "map.xpm");
		return unless (open(F, ">", $file));
		binmode F;
		print F _xpmmake($field);
		close F;
		my $bitmap = _loadImage($file);
		unlink $file;
		return $bitmap;
	}
}

sub _posXYToView {
	my ($self, $x, $y) = @_;
	my ($xscale, $yscale);
	$xscale = $self->{bitmap}->GetWidth() / $self->{field}{width};
	$yscale = $self->{bitmap}->GetHeight() / $self->{field}{height};
	$x *= $xscale;
	$y = ($self->{field}{height} - $y) * $yscale;
	return ($x, $y);
}

sub _onPaint {
	my $self = shift;
	my $dc = new Wx::PaintDC($self);
	return unless ($self->{bitmap});

	my ($x, $y);
	$dc->BeginDrawing();
	$dc->DrawBitmap($self->{bitmap}, 0, 0, 1);

	if ($self->{dest}) {
		$dc->SetPen(wxWHITE_PEN);
		$dc->SetBrush(new Wx::Brush(new Wx::Colour(255, 110, 245), wxSOLID));
		($x, $y) = $self->_posXYToView($self->{dest}{x}, $self->{dest}{y});
		$dc->DrawEllipse($x - 3, $y - 3, 6, 6);
	}


	if (!$self->{selfDot}) {
		my $file = _f("map", "kore.png");
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

	$dc->EndDrawing();
}

return 1;
