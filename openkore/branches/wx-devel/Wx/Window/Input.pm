package Interface::Wx::Window::Input;
use strict;

use base 'Wx::Panel';

use Wx ':everything';
use Wx::Event ':everything';

use Translation qw/T TF/;

use Interface::Wx::Input;

sub new {
	my ($class, $parent, $id) = @_;
	
	my $self = $class->SUPER::new($parent, $id);
	
	$self->SetSizer(my $sizer = new Wx::BoxSizer(wxHORIZONTAL));
	
	# player name combobox for private chat
	$sizer->Add(my $targetBox = new Wx::ComboBox(
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
	$sizer->Add(my $inputBox = new Interface::Wx::Input($self), 1, wxGROW);
	
	$inputBox->onEnter($self, sub {
		my ($self, $text) = @_;
		
		Plugins::callHook('interface/writeOutput', ['input', "$text\n"]);
		$inputBox->Remove(0, -1);
		$Globals::interface->{input} = $text;
	});
	
	# command / chat type field
	# TODO: add battleground chat
	$sizer->Add(my $choice = new Wx::Choice($self, wxID_ANY, wxDefaultPosition, wxDefaultSize, [
		T('Command'), T('Public chat'), T('Party chat'), T('Guild chat'),
	]), 0, wxGROW);
	
	$choice->SetSelection(0);
	EVT_CHOICE($self, $choice->GetId, sub { $inputBox->SetFocus });
	
	$self->{hooks} = Plugins::addHooks(
		# call this hook after clicking on buttons etc to change focus to input field
		['interface/defaultFocus', sub {
			my (undef, $args) = @_;
			
			$inputBox->SetFocus, $args->{return} = 1 unless $args->{return};
		}, undef]
	);
	
	# For some reason the input box doesn't get focus even if
	# I call SetFocus(), so do it in 100 msec.
	EVT_TIMER($self, (my $timer = new Wx::Timer($self, wxID_ANY))->GetId, sub {
		$inputBox->SetFocus;
	});
	$timer->Start(500, 1);
	
	return $self;
}

sub DESTROY {
	my ($self) = @_;
	
	Plugins::delHooks($self->{hooks});
}

1;
