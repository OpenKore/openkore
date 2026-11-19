package Interface::Wx::NpcTalk;

use strict;
use Wx ':everything';
use Wx::Event qw/EVT_BUTTON EVT_LISTBOX EVT_LISTBOX_DCLICK EVT_TEXT EVT_TEXT_ENTER EVT_LEFT_DOWN EVT_LEFT_DCLICK EVT_LEFT_UP EVT_MOTION/;
use base 'Wx::Panel';

use Globals;
use Misc qw/configModify/;
use Translation qw/T TF/;
use Interface::Wx::Utils qw(wxFilePath disablePageCompositing);

sub new {
	my ($class, $parent, $id) = @_;
	
	my $self = $class->SUPER::new ($parent, $id);
	
	$self->{illustDir} = 'bitmaps/illust/';
	
	my $sizer = new Wx::BoxSizer (wxVERTICAL);
	$self->SetSizer ($sizer);
	
	my $hsizer3 = new Wx::BoxSizer (wxHORIZONTAL);
	$sizer->Add ($hsizer3, 0, wxGROW);
	
	$self->{nameLabel} = new Wx::StaticText ($self, wxID_ANY, '');
	$hsizer3->Add ($self->{nameLabel}, 1, wxGROW | wxALL, 4);
	
	$self->{mapLabel} = new Wx::StaticText ($self, wxID_ANY, '');
	$hsizer3->Add ($self->{mapLabel}, 0, wxGROW | wxALL, 4);
	
	my $hsizer2 = new Wx::BoxSizer (wxHORIZONTAL);
	$sizer->Add ($hsizer2, 1, wxGROW);
	
	my $vsizer = new Wx::BoxSizer (wxVERTICAL);
	$hsizer2->Add ($vsizer, 1, wxGROW);
	
	$self->{chatLog} = new Interface::Wx::LogView ($self);
	$self->{chatLog}->SetMinSize ([0, $self->{chatLog}->GetCharHeight * 2 + 4]);
	$self->{chatLog}->setDefaultColor;
	if ($^O eq 'MSWin32' && Wx::wxVERSION() == 3.003) {
		my ($trackDrag, $dragAnchor);
		my $startDrag = sub {
			my (undef, $event) = @_;
			$dragAnchor = undef;
			$trackDrag = !$event->ShiftDown && !$event->ControlDown && !$event->AltDown;
			$event->Skip;
		};
		EVT_LEFT_DOWN ($self->{chatLog}, $startDrag);
		EVT_LEFT_DCLICK ($self->{chatLog}, $startDrag);
		EVT_MOTION ($self->{chatLog}, sub {
			my (undef, $event) = @_;
			$event->Skip;
			return unless $trackDrag && $event->Dragging && $event->LeftIsDown;
			$trackDrag = 0;
			my $log = $event->GetEventObject;
			my ($from, $to) = $log->GetSelection;
			$dragAnchor = $from if $from == $to || ($from == $log->GetLastPosition && $to == $from + 1);
		});
		EVT_LEFT_UP ($self->{chatLog}, sub {
			my (undef, $event) = @_;
			my $anchor = $dragAnchor;
			$trackDrag = 0;
			$dragAnchor = undef;
			$event->Skip;
			return unless defined $anchor && !$event->ShiftDown && !$event->ControlDown && !$event->AltDown;
			my $log = $event->GetEventObject;
			my ($from, $to) = $log->GetSelection;
			return unless $from > 0 && $from < $to;
			return unless $to == $anchor || ($anchor == $log->GetLastPosition && $to == $anchor + 1);
			my ($where, $column, $line) = $log->HitTest($event->GetPosition);
			return unless $where == wxTE_HT_ON_TEXT;
			my $end = $log->XYToPosition($column, $line);
			$log->SetSelection($end, $to) if $end >= 0 && $end < $to && $end != $from;
		});
	}
	$vsizer->Add ($self->{chatLog}, 1, wxGROW | wxALL, 4);
	
	$self->{hintLabel} = new Wx::StaticText ($self, wxID_ANY, '');
	$vsizer->Add ($self->{hintLabel}, 0, wxGROW | wxALL, 4);
	
	$self->{listResponses} = new Wx::ListBox ($self, wxID_ANY,
		wxDefaultPosition, wxDefaultSize, [], wxLB_HSCROLL);
	if ($^O eq 'MSWin32' && Wx::wxVERSION() == 3.003 && Wx::SystemSettings->can('GetAppearance')
		&& Wx::SystemSettings::GetAppearance()->IsUsingDarkBackground) {
		local $@;
		eval {
			require Win32;
			require Win32::API;
			my $setTheme = Win32::API->new('uxtheme', 'SetWindowTheme', 'NPP', 'I');
			$setTheme->Call($self->{listResponses}->GetHandle,
				map { pack('v*', unpack('C*', "$_\0")) } 'Explorer', 'ScrollBar')
				if $setTheme && (Win32::GetOSVersion())[3] >= 26200;
		};
	}
	$self->{listResponses}->SetMinSize ([0, $self->{listResponses}->GetCharHeight * 2 + 4]);
	$self->{listResponses}->Show (0);
	my $checkPageCompositing = $^O eq 'MSWin32' && Wx::wxVERSION() == 3.003;
	EVT_LISTBOX ($self, $self->{listResponses}->GetId, sub {
		$self->{value} = $self->{listResponses}->GetSelection;
		if ($checkPageCompositing) {
			$checkPageCompositing = 0;
			disablePageCompositing($self->GetParent, $self->{listResponses});
		}
	});
	EVT_LISTBOX_DCLICK ($self, $self->{listResponses}->GetId, sub { $self->_onOk; });
	$vsizer->Add ($self->{listResponses}, 1, wxGROW | wxALL, 4);
	
	$self->{inputBox} = new Wx::TextCtrl ($self, wxID_ANY, '', wxDefaultPosition, wxDefaultSize, wxTE_PROCESS_ENTER);
	$self->{inputBox}->Show (0);
	EVT_TEXT ($self, $self->{inputBox}->GetId, sub { $self->{value} = $self->{inputBox}->GetValue; });
	EVT_TEXT_ENTER ($self, $self->{inputBox}->GetId, sub { $self->_onOk; });
	$vsizer->Add ($self->{inputBox}, 0, wxGROW | wxALL, 4);
	
	my $imagePane = $self->{imagePane} = new Wx::ScrolledWindow ($self, wxID_ANY);
	$imagePane->SetScrollRate (8, 8);
	$imagePane->SetMinSize ([0, 0]);
	$imagePane->Show (0);
	$hsizer2->Add ($imagePane, 1, wxGROW);
	my $vsizer2 = new Wx::BoxSizer (wxVERTICAL);
	$imagePane->SetSizer ($vsizer2);

	$self->{imageLabel} = new Wx::StaticText ($imagePane, wxID_ANY, '');
	$self->{imageLabel}->Show (0);
	$vsizer2->Add ($self->{imageLabel}, 0, wxGROW | wxALL, 4);
	
	$self->{imageView} = new Wx::StaticBitmap ($imagePane, wxID_ANY, new Wx::Bitmap (0, 0, -1));
	$self->{imageView}->Show (0);
	$vsizer2->Add ($self->{imageView}, 0, wxALL, 4);
	
	my $hsizer = new Wx::BoxSizer (wxHORIZONTAL);
	$sizer->Add ($hsizer, 0, wxGROW | wxALL, 4);
	
	$self->{okButton} = new Wx::Button ($self, wxID_ANY, T('&OK'));
	$self->{okButton}->SetToolTip (T('Continue talking / submit response'));
	$self->{okButton}->Enable (0);
	EVT_BUTTON ($self, $self->{okButton}->GetId, sub { $self->_onOk; });
	$hsizer->Add ($self->{okButton}, 0, wxRIGHT, 4);
	
	$self->{autoButton} = new Wx::Button ($self, wxID_ANY, T('&Auto'));
	$self->{autoButton}->SetToolTip (T('Auto-continuing talking'));
	$self->{autoButton}->Enable (0);
	EVT_BUTTON ($self, $self->{autoButton}->GetId, sub { $self->_onAuto; });
	$hsizer->Add ($self->{autoButton}, 0, wxRIGHT, 4);
	
	$hsizer->AddStretchSpacer;
	
	$self->{cancelButton} = new Wx::Button ($self, wxID_ANY, T('&Cancel'));
	$self->{cancelButton}->SetToolTip (T('Cancel talking'));
	$self->{cancelButton}->Enable (0);
	EVT_BUTTON ($self, $self->{cancelButton}->GetId, sub { $self->_onCancel; });
	$hsizer->Add ($self->{cancelButton}, 0);
	
	return $self;
}

sub _onOk {
	my ($self) = @_;
	
	if ($self->{callback}{$self->{action}}) {
		$self->{callback}{$self->{action}}->($self->{value});
	}
	
	$self->_onAction (undef);
}

sub _onAuto {
	my ($self) = @_;
	
	configModify ('autoTalkCont', 1, 1);
	$self->{auto} = 1;
	
	# assert: action eq 'continue'
	$self->_onOk;
}

sub _onCancel {
	my ($self) = @_;
	
	$self->{action} = 'cancel';
	$self->_onOk;
}

sub _onAction {
	my ($self, $action, $hint) = @_;
	
	$self->{action} = $action;
	
	if (defined $self->{action} && $self->{action} ne 'continue' && $self->{auto}) {
		configModify ('autoTalkCont', 0, 1);
		$self->{auto} = undef;
	}
	
	$self->Freeze;
	
	$self->{okButton}->Enable (defined $self->{action});
	$self->{autoButton}->Enable (defined $self->{action} && $self->{action} eq 'continue');
	$self->{cancelButton}->Enable (defined $self->{action} && $self->{action} ne 'continue');
	$self->{hintLabel}->SetLabel ($hint);
	$self->{hintLabel}->Show (defined $hint && $hint ne '');
	$self->{listResponses}->Show (defined $self->{action} && $self->{action} eq 'responses');
	if (defined $self->{action} && $self->{action} eq 'responses') {
		$self->{listResponses}->SetSelection (0);
		$self->{value} = 0;
	}
	
	$self->Layout;
	$self->Thaw;
}

sub _updateImage {
	my ($self) = @_;
	
	$self->Freeze;
	
	if ($self->{image}) {
		$self->{imageLabel}->SetLabel ($self->{image});
		$self->{imageLabel}->Show (1);
		
		my $imageFile = $self->{illustDir} . $self->{image} . '.png';
		if (-f $imageFile) {
			$self->{imageView}->SetBitmap (new Wx::Bitmap (new Wx::Image (wxFilePath($imageFile), wxBITMAP_TYPE_ANY)));
			$self->{imageView}->Show (1);
		} else {
			$self->{imageView}->Show (0);
		}
	} else {
		$self->{imageLabel}->Show (0);
		$self->{imageView}->Show (0);
	}
	
	$self->{imagePane}->Show (defined $self->{image});
	$self->Layout;
	$self->{imagePane}->FitInside;
	$self->{imagePane}->Scroll (0, 0);
	$self->Thaw;
}

sub _checkBefore {
	my ($self) = @_;
	
	if ($self->{closed}) {
		$self->{nameLabel}->SetLabel ('');
		$self->{nameLabel}->SetLabel ('');
		$self->{chatLog}->Clear;
		$self->{closed} = undef;
		if ($self->{image}) {
			$self->{image} = undef;
			$self->_updateImage;
		}
	}
}

sub npcImage {
	my ($self, $show, $image) = @_;
	
	if ($show) {
		$self->_checkBefore;
		
		$self->{image} = $image;
		$self->{image} =~ s/\.\w{3}$//;
		$self->_updateImage;
	}
}

sub npcName {
	my ($self, $ID, $name) = @_;
	
	$self->_checkBefore;
	
	my $nameDisplay = $self->_nameDisplay ($name);
	
	my $mapDisplay = '';
	if (my $npc = $npcsList->getByID ($ID)) {
		$mapDisplay = join ' ', $field->baseName, $npc->{pos}{x}, $npc->{pos}{y};
	}
	
	$self->{nameLabel}->SetLabel ($nameDisplay);
	$self->{mapLabel}->SetLabel ($mapDisplay);
}

sub npcTalk {
	my ($self, $msg) = @_;
	
	#$self->_checkBefore;
	
	return if $msg =~ /^\[(.+)\]$/;
	
	my @items = split /(?=\^[a-fA-F0-9]{6})/, $msg;
	
	my $style;
	for (@items) {
		if (s/^\^([a-fA-F0-9]{2})([a-fA-F0-9]{2})([a-fA-F0-9]{2})//) {
			my ($rgb, @color) = ("$1$2$3", hex($1), hex($2), hex($3));
			$style = $rgb eq '000000' ? undef : $rgb;
			if (defined $style && !$self->{chatLog}{styles}{$style}) {
				$self->{chatLog}->addColor ($style, $self->_readableTextColor(@color));
			}
		}
		$self->{chatLog}->add ($_, $style);
	}
	
	$self->{chatLog}->add ("\n");
}

sub _luminance {
	my @components = map {
		my $channel = $_ / 255;
		$channel <= 0.04045 ? $channel / 12.92 : (($channel + 0.055) / 1.055) ** 2.4;
	} @_;
	return 0.2126 * $components[0] + 0.7152 * $components[1] + 0.0722 * $components[2];
}

sub _readableTextColor {
	my ($self, @color) = @_;
	my $background = $self->{chatLog}->GetBackgroundColour;
	my $text = Wx::SystemSettings::GetColour(wxSYS_COLOUR_WINDOWTEXT);
	my $backgroundLuminance = _luminance($background->Red, $background->Green, $background->Blue);
	my @foreground = ($text->Red, $text->Green, $text->Blue);
	return @color if $backgroundLuminance >= _luminance(@foreground);

	my @result = @color;
	for my $step (1..4) {
		last if (_luminance(@result) + 0.05) / ($backgroundLuminance + 0.05) >= 4.5;
		@result = map { int(($color[$_] * (4 - $step) + $foreground[$_] * $step) / 4) } 0..2;
	}
	return @result;
}

sub npcContinue {
	$_[0]->_onAction ('continue', T('Continue talking'));
}

sub npcResponses {
	my ($self, $responses) = @_;
	
	$self->{listResponses}->Clear;
	$self->{listResponses}->Append ($_) foreach $responses;
	
	$self->_onAction ('responses', T('Choose a response'));
}

sub npcNumber {
	$_[0]->_onAction ('number', T('Input a number'));
}

sub npcText {
	$_[0]->_onAction ('number', T('Respond to NPC'));
}

sub npcClose {
	my ($self) = @_;
	
	$self->_onAction (undef, T('Done talking'));
	$self->{closed} = 1;
}

sub onContinue  { $_[0]->{callback}{continue}  = $_[1]; }
sub onResponses { $_[0]->{callback}{responses} = $_[1]; }
sub onNumber    { $_[0]->{callback}{number}    = $_[1]; }
sub onText      { $_[0]->{callback}{text}      = $_[1]; }
sub onCancel    { $_[0]->{callback}{cancel}    = $_[1]; }

sub _nameDisplay {
	my (undef, $s) = @_;
	$s =~ s/#.+$//;
	return $s;
}

1;
