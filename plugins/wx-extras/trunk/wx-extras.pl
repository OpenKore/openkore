package Interface::Wx::Extras;

use Globals qw/$interface/;
use Log qw/message warning/;

BEGIN {
	eval "require Interface::Wx::Utils";
	if ($@) {
		warning "wx-extras can't load Wx Utils (Wx Interface or wxPerl is not present, or incompatible)\n";
		return;
	}
}

use Wx ':everything';
use Wx::Event ':everything';

our $app;

my %windows = (
	map => 'Interface::Wx::Window::Map',
	chatlog => 'Interface::Wx::Window::ChatLog',
	character => 'Interface::Wx::Window::Character',
	homunculus => 'Interface::Wx::Window::Homunculus',
	mercenary => 'Interface::Wx::Window::Mercenary',
	pet => 'Interface::Wx::Window::Pet',
	inventory => 'Interface::Wx::Window::Inventory',
	cart => 'Interface::Wx::Window::Cart',
	storage => 'Interface::Wx::Window::Storage',
	skills => 'Interface::Wx::Window::Skills',
	emotion => 'Interface::Wx::Window::Emotion',
	exp => 'Interface::Wx::Window::Exp',
);

my $commands = Commands::register(
	['wx', 'additional wx features', sub {
		my (undef, $args) = @_;
		
		if ($interface->isa('Interface::Wx')) {
			warning "Not available\n";
			return;
		}
		
		if ($args eq 'switch') {
			message "*** INTERFACE INACTIVE ***\nClose Wx interface to get back\n";
			my $oldInterface = $interface;
			$interface = Interface->loadInterface('Wx');
			$interface->mainLoop;
			$interface = $oldInterface;
			message "\n*** INTERFACE ACTIVE ***\n";
		} elsif ($args eq 'start') {
			unless ($app) {
				$app = new Wx::SimpleApp;
				(new Wx::Frame(undef, wxID_ANY, 'Wx Event Handler'));
				Interface::Wx::Utils::startMainLoop($app);
			} else {
				warning "wxApp is already defined\n";
			}
		} elsif ($args eq 'stop') {
			if ($app) {
				# TODO: close all frames first
				
				&Interface::Wx::Utils::stopMainLoop;
				undef $app;
			} else {
				warning "wxApp is undefined\n";
			}
		} elsif (my $window = $windows{$args}) {
			if ($app) {
				eval "require $window";
				if ($@) {
					warning TF("Unable to load %s\n%s", $class, $@), 'interface';
					return;
				}
				unless ($window->can('new')) {
					warning TF("Unable to create instance of %s\n", $class), 'interface';
					return;
				}
				
				my $frame = new Wx::Frame(undef, wxID_ANY, $args, wxDefaultPosition, wxDefaultSize,
					wxFRAME_TOOL_WINDOW | wxRESIZE_BORDER | wxSYSTEM_MENU | wxCAPTION | wxCLOSE_BOX
				);
				$window = $window->new($frame);
				(my $sizer = new Wx::BoxSizer(wxVERTICAL))
				->Add($window, 1, wxGROW);
				$frame->SetSizer($sizer);
				$frame->Show;
			} else {
				warning "Use 'wx start' before opening any windows\n";
			}
		} else {
			warning "Unknown args: '$args'\nAvailable args: start stop @{[keys %windows]}\n";
		}
	}],
);

Plugins::register ('wx-extras', 'additional wx features', sub {
	Commands::unregister($commands);
});
