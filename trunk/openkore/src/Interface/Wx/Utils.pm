package Interface::Wx::Utils;

use strict;
use FindBin qw($RealBin);
use File::Spec;
use Exporter;
use base qw(Exporter);

use Wx ':everything';
use Wx::Event qw(EVT_BUTTON);
use Wx::XRC;

our @EXPORT = qw(loadDialog setupDialog dataFile);
our %files;
our @searchPath;

sub loadDialog {
	my ($file, $parent, $name) = @_;
	my $realfile = dataFile($file);
	my $xml;

	if (!$files{$realfile}) {
		$xml = new Wx::XmlResource;
		$xml->InitAllHandlers;
		$xml->Load($realfile);
		$files{$realfile} = $xml;
	} else {
		$xml = $files{$realfile};
	}

	return $xml->LoadDialog($parent, $name);
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

1;
