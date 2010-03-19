package Interface::Wx::Window::Input;
use strict;

use base 'Wx::Panel';

use Wx ':everything';
use Wx::Event ':everything';

use Globals qw/$conState $messageSender/;
use Misc qw/sendMessage/;
use Translation qw/T TF/;

use Interface::Wx::Input;

sub new {
	my ($class, $parent, $id) = @_;
	
	my $self = $class->SUPER::new($parent, $id);
	
	$self->SetSizer(my $sizer = new Wx::BoxSizer(wxHORIZONTAL));
	
	# player name combobox for private chat
	$sizer->Add($self->{targetBox} = new Wx::ComboBox(
		$self, wxID_ANY, '', wxDefaultPosition, [155, 0], [], 0, wxDefaultValidator, 'targetBox'
	), 0, wxGROW);
	
	EVT_KEY_DOWN($self, sub {
		my ($self, $event) = @_;
		
		if ($event->GetKeyCode == WXK_TAB && !$event->ShiftDown) {
			$self->{inputBox}->SetFocus;
		} else {
			$event->Skip;
		}
	});
	
	# input field
	$sizer->Add($self->{inputBox} = new Interface::Wx::Input($self), 1, wxGROW);
	
	$self->{inputBox}->onEnter($self, \&onInputEnter);
	
	# command / chat type field
	$sizer->Add($self->{inputType} = new Wx::Choice($self), 0, wxGROW);
	
	$self->{inputType}->Append(@$_) for (
		[T('Command'), ''],
		[T('Public chat'), 'c'],
		[T('Party chat'), 'p'],
		[T('Guild chat'), 'g'],
		[T('Battleground chat'), 'bg'],
	);
	
	$self->{inputType}->SetSelection(0);
	EVT_CHOICE($self, $self->{inputType}->GetId, sub {
		my ($self) = @_;
		
		$self->{inputBox}->SetFocus 
	});
	
	$self->{hooks} = Plugins::addHooks(
		['parseMsg/addPrivMsgUser', sub { $_[2]->{targetBox}->Append($_[1]->{user}) }, $self],
		
		# call this hook after clicking on buttons etc to change focus to input field
		['interface/defaultFocus', sub {
			my (undef, $args, $self) = @_;
			
			$self->{inputBox}->SetFocus, $args->{return} = 1 unless $args->{return};
		}, $self]
	);
	
	# For some reason the input box doesn't get focus even if
	# I call SetFocus(), so do it in 100 msec.
	EVT_TIMER($self, (my $timer = new Wx::Timer($self, wxID_ANY))->GetId, sub {
		my ($self) = @_;
		
		$self->{inputBox}->SetFocus 
	});
	$timer->Start(500, 1);
	
	return $self;
}

sub DESTROY {
	my ($self) = @_;
	
	Plugins::delHooks($self->{hooks});
}

sub onInputEnter {
	my ($self, $text) = @_;
	
	my $n = $self->{inputType}->GetSelection;
	if ($n == 0 || $text =~ /^\/(.*)/) {
		my $text = ($n == 0) ? $text : $1;
		$self->{inputBox}->Remove(0, -1);
		Plugins::callHook('interface/output', ['input', "$text\n"]);
		Plugins::callHook('interface/input', {text => $text});
		return;
	}
	
	if ($conState != Network::IN_GAME) {
		Plugins::callHook('interface/output', ['error', T("You're not logged in.\n")]);
		return;
	}
	
	if ($self->{targetBox}->GetValue ne "") {
		sendMessage($messageSender, "pm", $text, $self->{targetBox}->GetValue);
	} else {
		sendMessage($messageSender, $self->{inputType}->GetClientData($n), $text);
	}
}

1;
