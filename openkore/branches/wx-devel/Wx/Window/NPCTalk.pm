package Interface::Wx::Window::NPCTalk;

use strict;
use Wx ':everything';
use Wx::Event ':everything';
use base 'Wx::Panel';

use Globals qw(%config $field $npcsList);
use I18N qw(bytesToString);
use Misc qw(configModify);
use Translation qw(T TF);

{
	my $hooks;
	
	sub new {
		my ($class, $parent, $id) = @_;
		
		Scalar::Util::weaken(my $weak = my $self = $class->SUPER::new ($parent, $id));
		
		$self->{title} = T('NPC Talk');
		
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
		
		$self->{chatLog} = new Interface::Wx::Base::LogView ($self);
		$vsizer->Add ($self->{chatLog}, 1, wxGROW | wxALL, 4);
		
		$self->{hintLabel} = new Wx::StaticText ($self, wxID_ANY, '');
		$vsizer->Add ($self->{hintLabel}, 0, wxGROW | wxALL, 4);
		
		$self->{listResponses} = new Wx::ListBox ($self, wxID_ANY);
		$self->{listResponses}->Show (0);
		EVT_LISTBOX ($self, $self->{listResponses}->GetId, sub { $self->{value} = $self->{listResponses}->GetSelection; });
		EVT_LISTBOX_DCLICK ($self, $self->{listResponses}->GetId, sub { $self->_onOk; });
		$vsizer->Add ($self->{listResponses}, 0, wxGROW | wxALL, 4);
		
		$self->{inputBox} = new Wx::TextCtrl ($self, wxID_ANY, '', wxDefaultPosition, wxDefaultSize, wxTE_PROCESS_ENTER);
		$self->{inputBox}->Show (0);
		EVT_TEXT ($self, $self->{inputBox}->GetId, sub { $self->{value} = $self->{inputBox}->GetValue; });
		EVT_TEXT_ENTER ($self, $self->{inputBox}->GetId, sub { $self->_onOk; });
		$vsizer->Add ($self->{inputBox}, 0, wxGROW | wxALL, 4);
		
		my $vsizer2 = new Wx::BoxSizer (wxVERTICAL);
		$hsizer2->Add ($vsizer2, 0, wxGROW);
		
		$self->{imageLabel} = new Wx::StaticText ($self, wxID_ANY, '');
		$self->{imageLabel}->Show (0);
		$vsizer2->Add ($self->{imageLabel}, 0, wxGROW | wxALL, 4);
		
		$self->{imageView} = new Wx::StaticBitmap ($self, wxID_ANY, new Wx::Bitmap (0, 0, -1));
		$self->{imageView}->Show (0);
		$vsizer2->Add ($self->{imageView}, 0, wxGROW | wxALL, 4);
		
		$vsizer2->AddStretchSpacer;
		
		my $hsizer = new Wx::BoxSizer (wxHORIZONTAL);
		$sizer->Add ($hsizer, 0, wxGROW | wxALL, 4);
		
		$self->{okButton} = new Wx::Button ($self, wxID_ANY, '&OK');
		$self->{okButton}->SetToolTip ('Continue talking / submit response');
		$self->{okButton}->Enable (0);
		EVT_BUTTON ($self, $self->{okButton}->GetId, sub { $self->_onOk; });
		$hsizer->Add ($self->{okButton}, 0, wxRIGHT, 4);
		
		$self->{autoButton} = new Wx::Button ($self, wxID_ANY, '&Auto');
		$self->{autoButton}->SetToolTip ('Auto-continuing talking');
		$self->{autoButton}->Enable (0);
		EVT_BUTTON ($self, $self->{autoButton}->GetId, sub { $self->_onAuto; });
		$hsizer->Add ($self->{autoButton}, 0, wxRIGHT, 4);
		
		$hsizer->AddStretchSpacer;
		
		$self->{cancelButton} = new Wx::Button ($self, wxID_ANY, '&Cancel');
		$self->{cancelButton}->SetToolTip ('Cancel talking');
		$self->{cancelButton}->Enable (0);
		EVT_BUTTON ($self, $self->{cancelButton}->GetId, sub { $self->_onCancel; });
		$hsizer->Add ($self->{cancelButton}, 0);
		
		$hooks = Plugins::addHooks(
			['packet/npc_image', sub { $weak->npcImage($_[1]->{type} == 2, bytesToString($_[1]->{npc_image})) }],
			['npc_talk', sub { $weak->npcName(@{$_[1]}{qw(ID name)}) }],
			['packet/npc_talk', sub { $weak->npcTalk(bytesToString($_[1]{msg})) }],
			['packet/npc_talk_continue', sub { $weak->npcContinue unless $config{autoTalkCont} }],
			['npc_talk_responses', sub { $weak->npcResponses($_[1]{responses}) }],
			['packet/npc_talk_number', sub { $weak->npcNumber }],
			['packet/npc_talk_text', sub { $weak->npcText }],
			['npc_talk_done', sub { $weak->npcClose }],
		);
		
		return $self;
	}
	
	sub DESTROY { Plugins::delHooks($hooks) }
}

sub _onOk {
	my ($self) = @_;
	
	Commands::run({
		continue => "talk cont",
		responses => "talk resp $self->{value}",
		number => "talk num $self->{value}",
		text => "talk text $self->{value}",
		cancel => "talk no",
	}->{$self->{action}});
	
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
	$self->{cancelButton}->Enable (defined $self->{action} && !{continue => 1, number => 1, text => 1}->{$self->{action}});
	$self->{hintLabel}->SetLabel ($hint);
	$self->{hintLabel}->Show (defined $hint && $hint ne '');
	$self->{inputBox}->Show (defined $self->{action} && {number => 1, text => 1}->{$self->{action}});
	$self->{listResponses}->Show (defined $self->{action} && $self->{action} eq 'responses');
	if (defined $self->{action} && $self->{action} eq 'responses') {
		$self->{listResponses}->SetSelection (0);
		$self->{value} = 0;
	}
	
	$self->GetSizer->Layout;
	$self->{chatLog}->AppendText ('');
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
			$self->{imageView}->SetBitmap (new Wx::Bitmap (new Wx::Image ($imageFile, wxBITMAP_TYPE_ANY)));
			$self->{imageView}->Show (1);
		} else {
			$self->{imageView}->Show (0);
		}
	} else {
		$self->{imageLabel}->Show (0);
		$self->{imageView}->Show (0);
	}
	
	$self->GetSizer->Layout;
	$self->{chatLog}->AppendText ('');
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
		$mapDisplay = join ' ', $field->name, $npc->{pos}{x}, $npc->{pos}{y};
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
			$style = "$1$2$3";
			$self->{chatLog}->addColor ($style, (hex $1), (hex $2), (hex $3)) unless $self->{chatLog}{styles}{$style};
		}
		$self->{chatLog}->add ($_, $style);
	}
	
	$self->{chatLog}->add ("\n");
}

sub npcContinue {
	$_[0]->_onAction ('continue', 'Continue talking');
}

sub npcResponses {
	my ($self, $responses) = @_;
	
	$self->{listResponses}->Clear;
	$self->{listResponses}->Append ($_) foreach $responses;
	
	$self->_onAction ('responses', 'Choose a response');
}

sub npcNumber {
	$_[0]->_onAction ('number', 'Input number');
}

sub npcText {
	$_[0]->_onAction ('text', 'Input text');
}

sub npcClose {
	my ($self) = @_;
	
	$self->_onAction (undef, 'Done talking');
	$self->{closed} = 1;
}

sub _nameDisplay {
	my (undef, $s) = @_;
	$s =~ s/#.+$//;
	return $s;
}

1;
