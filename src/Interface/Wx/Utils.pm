package Interface::Wx::Utils;

use strict;
use FindBin qw($RealBin);
use File::Spec;
use Exporter;
use base qw(Exporter);

use Wx ':everything';
use Wx::Event qw(EVT_BUTTON);

our @EXPORT = qw(loadDialog loadPNG setupDialog dataFile);
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

sub dataFile {
	my $default = File::Spec->catfile($RealBin, 'src', 'Interface', 'Wx');
	foreach my $dir (@searchPath, $default) {
		my $file = File::Spec->catfile($dir, $_[0]);
		return $file if (-f $file);
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
