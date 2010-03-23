package Interface::Wx::Window::Emotion;

use strict;
use Wx ':everything';
use Wx::Event qw/EVT_SIZE EVT_BUTTON/;
use base 'Wx::Panel';

use Globals qw/%emotions_lut/;

use constant {
	BUTTON_SIZE => 26,
	BUTTON_BORDER => 2,
};

sub new {
	my ($class, $parent, $id) = @_;
	
	my $self = $class->SUPER::new ($parent, $id);
	
	$self->{bitmapDir} = 'bitmaps/emotion/';
	
	Scalar::Util::weaken(my $weak = $self);

	$self->{hooks} = Plugins::addHooks (
		['loadfiles',
			sub {
				my (undef, $args) = @_;
				if ($args->{files}->[$args->{current} - 1]->{name} eq 'emotions.txt') {
					$weak->setEmotions(\%emotions_lut);
				}
			}
		],
	);

	EVT_SIZE ($self, \&_onSize);

	$self->SetSizer (my $sizer = new Wx::BoxSizer (wxVERTICAL));
	$sizer->Add ($self->{grid} = new Wx::GridSizer (0, 0, BUTTON_BORDER, BUTTON_BORDER), 0);
	$sizer->AddStretchSpacer;
	
	$self->setEmotions(\%emotions_lut) if scalar keys %emotions_lut;
	
	$self->onEmotion (sub {
		Commands::run ('e ' . shift);
		#$self->{inputBox}->SetFocus; # TODO: plugin hook setfocus on inputbox?
	});
	
	return $self;
}

sub DESTROY {
	my ($self) = @_;
	
	Plugins::delHooks ($self->{hooks});
}

sub _onSize {
	my ($self) = @_;
	
	my $cols = int (($self->GetSize->GetWidth + BUTTON_BORDER) / (BUTTON_SIZE + BUTTON_BORDER));
	
	unless (defined $self->{cols} && $self->{cols} == $cols) {
		$self->{grid}->SetCols ($self->{cols} = $cols);
		$self->GetSizer->Layout;
	}
}

sub _createButtons {
	my ($self) = @_;
	
	return unless $self->{emotions};
	
	$self->Freeze;
	$self->{grid}->Clear (1);
	
	if (my $total = keys %{$self->{emotions}}) {		
		my $button;
		for (my ($i, $e) = (0, 0); $i < $total; $e++) {
			next unless defined $self->{emotions}{$e};
			
			my $imageFile = $self->{bitmapDir} . "$e.gif";
			if (-f $imageFile) {
				$button = new Wx::BitmapButton (
					$self, wxID_ANY, new Wx::Bitmap (new Wx::Image ($imageFile, wxBITMAP_TYPE_ANY)),
					wxDefaultPosition, [BUTTON_SIZE, BUTTON_SIZE], wxBU_AUTODRAW
				);
			} else {
				$button = new Wx::Button (
					$self, wxID_ANY, $self->{emotions}{$e}{command}, wxDefaultPosition, [BUTTON_SIZE, BUTTON_SIZE]
				);
			}
			$button->SetToolTip (sprintf '%s: %s', $self->{emotions}{$e}{command}, $self->{emotions}{$e}{display});
			{
				my $cmd = $self->{emotions}{$e}{command};
				EVT_BUTTON ($self, $button->GetId, sub {$self->_onEmotion ($cmd)});
			}
			
 			$self->{grid}->Add ($button);
			$i++;
		};
	} else {
		$self->{grid}->Add (my $sizer = new Wx::BoxSizer (wxVERTICAL));
		$sizer->Add (
			new Wx::StaticText ($self, wxID_ANY, 'No emotions (emotions.txt is empty or not loaded yet?)'), 0, wxALL, BUTTON_BORDER
		);
		$sizer->Add (
			my $refreshButton = new Wx::Button ($self, wxID_ANY, 'Refresh'), 0, wxALL, BUTTON_BORDER
		);
		EVT_BUTTON ($self, $refreshButton->GetId, sub { $self->_createButtons; });
	}
	
	$self->GetSizer->Layout;
	$self->Thaw;
}

sub _onEmotion {
	my ($self, $key) = @_;
	
	$self->{callback}{emotion}->($key) if $self->{callback}{emotion};
}

sub setEmotions {
	my ($self, $emotions) = @_;
	
	$self->{emotions} = $emotions;
	foreach (values %{$self->{emotions}}) {
		$_->{command} =~ s/^.+,//;
	}
	$self->_createButtons;
}

sub onEmotion  { $_[0]->{callback}{emotion}  = $_[1]; }

1;
