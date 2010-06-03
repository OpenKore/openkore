package Interface::Wx::Utils;

use strict;
use Carp::Assert;
use FindBin qw($RealBin);
use File::Spec;
use Exporter;
use base qw(Exporter);

use Wx ':everything';
use Wx::Event ':everything';

# for all modules
use Scalar::Util;
use List::Util;

use Globals qw($char %config $quit $interface);
use Log qw(debug);
use Translation qw(T TF);

our @EXPORT = qw(
	loadDialog loadPNG setupDialog dataFile
	startMainLoop stopMainLoop
	isUsable isEquip isCard
	skillListMenuList
);
our %files;
our @searchPath;
our $pngAdded;

Wx::InitAllImageHandlers;

# TODO: move item type detection to Actor::Item?
sub isUsable { $_[-1]{type} <= 2 }
sub isEquip { (0, 0, 0, 0, 1, 1, 0, 0, 1, 1, 1, 1, 0, 1, 1, 1, 1, 1) [$_[-1]{type}] }
sub isCard { $_[-1]{type} == 6 }

# Not related to Wx

sub skillListMenuList {
	my ($filter, $item) = @_;
	
	map {{ title => TF("%s [%d]", $_->getName, $_->getLevel), $item->($_) }}
	sort { $a->getName cmp $b->getName }
	grep { $filter->($_) }
	map { new Skill(handle => $_, level => $char->{skills}{$_}{lv}) }
	keys %{$char->{skills}}
}


# Wx MainLoop

{
	my ($app, $timer, $inside, $quitting);
	
	sub startMainLoop {
		($app) = @_;
		
		return if $inside;
		$inside = 1;
		
		$app->SetAppName($Settings::NAME);
		
		debug "startMainLoop\n", __PACKAGE__ if DEBUG;
		
		# Start the real main loop in 100 msec, so that the UI has
		# the chance to layout correctly.
		$timer = new Wx::Timer($app->GetTopWindow);
		EVT_TIMER($app->GetTopWindow, $timer->GetId, sub { # realMainLoop
			debug "realMainLoop\n", __PACKAGE__ if DEBUG;
			
			EVT_TIMER($app->GetTopWindow, $timer->GetId, sub {
				return if $quitting || $app->{iterating};
				&stopMainLoop, return if $quit;
				
				$app->{iterating}++;
				$interface->iterate unless $interface->isa('Interface::Wx');
				&main::mainLoop;
				$app->{iterating}--;
			});
			$timer->Start($config{sleepTime} / 1000 || 10);
		});
		$timer->Start(100, wxTIMER_ONE_SHOT);
		
		debug "startMainLoop: passing control to wx\n", __PACKAGE__ if DEBUG;
		$app->MainLoop;
		debug "startMainLoop: regained control from wx\n", __PACKAGE__ if DEBUG;
		($app, $timer, $inside, $quitting) = ();
	}
	
	sub stopMainLoop {
		return unless $inside;
		
		debug "stopMainLoop\n", __PACKAGE__ if DEBUG;
		
		$quitting = 1;
		$app->ExitMainLoop;
		$timer->Stop;
	}
}

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
