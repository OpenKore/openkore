package Interface::Wx::NpcTalk;

use strict;
use Wx ':everything';
use Wx::Event qw/EVT_BUTTON EVT_LISTBOX EVT_LISTBOX_DCLICK EVT_TEXT EVT_TEXT_ENTER/;
use base 'Wx::Panel';

use Globals;
use Log qw/message/;
use Utils qw/binFind/;

sub new {
	my ($class, $parent, $id) = @_;
	
	my $self = $class->SUPER::new ($parent, $id);
	
	my $sizer = new Wx::BoxSizer (wxVERTICAL);
	$self->SetSizer ($sizer);
	
	$self->{nameLabel} = new Wx::StaticText ($self, -1, 'NPC');
	$sizer->Add ($self->{nameLabel}, 0, wxGROW | wxALL, 4);
	
	$self->{chatLog} = new Interface::Wx::LogView ($self);
	$sizer->Add ($self->{chatLog}, 1, wxGROW | wxALL, 4);
	
	$self->{hintLabel} = new Wx::StaticText ($self, -1, '');
	$sizer->Add ($self->{hintLabel}, 0, wxGROW | wxALL, 4);
	
	$self->{listResponses} = new Wx::ListBox ($self, 2211);
	$self->{listResponses}->Show (0);
	EVT_LISTBOX ($self, 2211, sub { $self->{value} = $self->{listResponses}->GetSelection; });
	EVT_LISTBOX_DCLICK ($self, 2211, sub { $self->_onOk; });
	$sizer->Add ($self->{listResponses}, 0, wxGROW | wxALL, 4);
	
	$self->{inputBox} = new Wx::TextCtrl ($self, 2213, '', wxDefaultPosition, wxDefaultSize, wxTE_PROCESS_ENTER);
	$self->{inputBox}->Show (0);
	EVT_TEXT ($self, 2213, sub { $self->{value} = $self->{inputBox}->GetValue; });
	EVT_TEXT_ENTER ($self, 2213, sub { $self->_onOk; });
	$sizer->Add ($self->{inputBox}, 0, wxGROW | wxALL, 4);
	
	my $hsizer = new Wx::BoxSizer (wxHORIZONTAL);
	$sizer->Add ($hsizer, 0, wxGROW | wxALL, 4);
	
	$self->{okButton} = new Wx::Button ($self, 2212, '&OK');
	$self->{okButton}->SetToolTip ('Continue talking / submit response');
	$self->{okButton}->Enable (0);
	EVT_BUTTON ($self, 2212, sub { $self->_onOk; });
	$hsizer->Add ($self->{okButton}, 0);
	
	my $pad = new Wx::Window ($self, -1);
	$hsizer->Add ($pad, 1);
	
	$self->{cancelButton} = new Wx::Button ($self, 2213, '&Cancel');
	$self->{cancelButton}->SetToolTip ('Cancel talking');
	$self->{cancelButton}->Enable (0);
	EVT_BUTTON ($self, 2213, sub { $self->_onCancel; });
	$hsizer->Add ($self->{cancelButton}, 0);
	
	$self->{sizer} = $sizer;
	
	return $self;
}

sub _onOk {
	my ($self) = @_;
	
	if ($self->{callback}{$self->{action}}) {
		$self->{callback}{$self->{action}}->($self->{value});
	}
	
	$self->_onAction (undef);
}

sub _onCancel {
	my ($self) = @_;
	
	$self->{action} = 'cancel';
	$self->_onOk;
}

sub _onAction {
	my ($self, $action, $hint) = @_;
	
	$self->{action} = $action;
	
	$self->{okButton}->Enable (defined $self->{action});
	$self->{cancelButton}->Enable (defined $self->{action});# && $self->{action} eq 'responses');
	$self->{hintLabel}->SetLabel ($hint);
	$self->{hintLabel}->Show (defined $hint && $hint ne '');
	$self->{listResponses}->Show (defined $self->{action} && $self->{action} eq 'responses');
	
	$self->{sizer}->Layout;
	
	# scroll chat log to bottom
	$self->{chatLog}->AppendText ('');
}

sub npcImage {
	# TODO
}

sub npcTalk {
	my ($self, undef, $args) = @_;
	
	if ($self->{closed}) {
		$self->{chatLog}->Clear;
		$self->{closed} = undef;
	}
	
	my $nameDisplay = $self->_nameDisplay ($args->{name});
	return if $args->{msg} eq "[$nameDisplay]";
	
	$self->{nameLabel}->SetLabel ($nameDisplay);
	$self->{chatLog}->add ($args->{msg} . "\n");
}

sub npcContinue {
	$_[0]->_onAction ('continue', 'Continue talking') unless $config{autoTalkCont};
}

sub npcResponses {
	my ($self, undef, $args) = @_;
	
	$self->{listResponses}->Clear;
	$self->{listResponses}->Append ($_) foreach $args->{responses};
	
	$self->_onAction ('responses', 'Choose a response');
}

sub npcNumber {
	$_[0]->_onAction ('number', 'Input a number');
}

sub npcText {
	$_[0]->_onAction ('number', 'Respond to NPC');
}

sub npcClose {
	my ($self) = @_;
	
	$self->_onAction (undef, 'Done talking');
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
