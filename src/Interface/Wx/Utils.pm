package Interface::Wx::Utils;

use strict;
use FindBin qw($RealBin);
use File::Spec;
use Encode ();
use Exporter;
use base qw(Exporter);

use Wx ':everything';
use Wx::Event qw(EVT_BUTTON);

our @EXPORT = qw(loadDialog loadPNG setupDialog dataFile wxFilePath);
our @EXPORT_OK = qw(disablePageCompositing);
our %files;
our @searchPath;
our $pngAdded;

sub loadDialog {
	my ($file, $parent, $name) = @_;
	my $realfile = dataFile($file);
	my $xml;

	if (!$files{$realfile}) {
		require Wx::XRC;
		$xml = new Wx::XmlResource;
		$xml->InitAllHandlers;
		$xml->Load($realfile);
		$files{$realfile} = $xml;
	} else {
		$xml = $files{$realfile};
	}

	return $xml->LoadDialog($parent, $name);
}

sub loadPNG {
	my $file = shift;

	if (!$pngAdded) {
		Wx::Image::AddHandler(new Wx::PNGHandler);
		$pngAdded = 1;
	}
	my $image = Wx::Image->newNameType(dataFile($file), wxBITMAP_TYPE_PNG);
	return new Wx::Bitmap($image);
}

sub setupDialog {
	my $dialog = shift;
	my $ok_name = (shift || 'ok');
	my $cancel_name = (shift || 'cancel');
	EVT_BUTTON($dialog, $dialog->FindWindow($ok_name)->GetId, sub {
		$_[0]->EndModal(wxID_OK);
	});
	EVT_BUTTON($dialog, $dialog->FindWindow($cancel_name)->GetId, sub {
		$_[0]->EndModal(wxID_CANCEL);
	});
}

sub wxFilePath {
	my ($path) = @_;
	if ($^O eq 'MSWin32' && defined $path && !utf8::is_utf8($path)) {
		require Translation;
		my $encoding = Translation::getLocaleCharset();
		$encoding = 'UTF-8' if uc($encoding) eq 'CP65001';
		return Encode::decode($encoding, $path) if Encode::find_encoding($encoding);
	}
	return $path;
}

sub disablePageCompositing {
	my ($page, $window) = @_;
	local $@;
	eval {
		require Config;
		require Win32::API;
		my $handle = $Config::Config{ptrsize} == 8 ? 'q' : 'N';
		my $getDpiContext = Win32::API->new('user32', 'GetWindowDpiAwarenessContext', $handle, $handle);
		my $sameDpiContext = Win32::API->new('user32', 'AreDpiAwarenessContextsEqual', $handle x 2, 'I');
		my $hwnd = $page->GetHandle;
		my $gdiScaled = -5;
		return unless $getDpiContext && $sameDpiContext && $sameDpiContext->Call($getDpiContext->Call($hwnd), $gdiScaled);

		my $getStyle = Win32::API->new('user32', 'GetWindowLongW', "${handle}I", 'N');
		my $setStyle = Win32::API->new('user32', 'SetWindowLongW', "${handle}IN", 'N');
		my $setPosition = Win32::API->new('user32', 'SetWindowPos', ($handle x 2) . 'IIIIN', 'I');
		return unless $getStyle && $setStyle && $setPosition;
		my $extendedStyle = -20;
		my $composited = 0x02000000;
		my $style = $getStyle->Call($hwnd, $extendedStyle);
		if (($style & $composited) && $setStyle->Call($hwnd, $extendedStyle, $style & ~$composited)) {
			my $frameChanged = 0x37;
			$setPosition->Call($hwnd, 0, 0, 0, 0, 0, $frameChanged);
			$window->Refresh;
			$window->Update;
		}
	};
}

sub dataFile {
	my $default = File::Spec->catfile($RealBin, 'src', 'Interface', 'Wx');
	foreach my $dir (@searchPath, $default) {
		my $file = File::Spec->catfile($dir, $_[0]);
		return wxFilePath($file) if (-f $file);
	}
}


package Wx::Window;

sub W {
	return $_[0]->FindWindow($_[1]);
}

sub WS {
	my $self = shift;
	my @ret;
	foreach (@_) {
		push @ret, $self->FindWindow($_);
	}
	return @ret;
}

1;
