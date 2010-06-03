package Interface::Wx::ToolBar;
use strict;

use Wx ':everything';
use Wx::Event ':everything';
use base 'Wx::ToolBar';

use Globals qw(%config $AI);
use Misc qw(configModify);
use Translation qw(T TF);

{
	my $hooks;
	
	sub new {
		my $class = shift;
		
		Scalar::Util::weaken(my $weak = my $self = $class->SUPER::new(@_));
		
		my @hooks;
		
		for (
			[command => 'take first', T('Take')],
			[command => 'move stop;;as', T('Stop')],
			[command => 'tele', T('Tele')],
			[],
			[text => undef, T('AI: ')],
			[radiogroup => 'ai auto', T('Auto')],
			[radio => 'ai manual', T('Manual')],
			[radio => 'ai off', T('Off'), sub { !$AI }],
			[],
			[text => undef, T('Atk: ')],
			[radiogroup => 'conf attackAuto 2', T('Aggro')],
			[radio => 'conf attackAuto 1', T('On')],
			[radio => 'conf attackAuto 0', T('Off'), sub { !$AI }],
			[],
			[text => undef, T('Idle: ')],
			[config => 'route_randomWalk', T('Walk')],
			[config => 'teleportAuto_idle', T('Tele')],
			[],
			[text => undef, T('Log: ')],
			[config => 'showDomain', T('Domains')],
			[config => 'verbose', T('Verbose')],
			[],
			[command => 'reload all', T('Reload')],
		) {
			my ($mode, $key, $title) = @$_;
			if ($mode eq 'text') {
				$self->AddControl(new Wx::StaticText($self, wxID_ANY, $title));
			} elsif ($mode eq 'config') {
				$self->AddControl($self->{config}{$key} = new Wx::CheckBox($self, wxID_ANY, $title));
				$self->{config}{$key}->SetValue($config{$key});
				EVT_CHECKBOX($self, $self->{config}{$key}->GetId, sub {
					Plugins::callHook('interface/defaultFocus');
					configModify($key, $weak->{config}{$key}->GetValue, 1);
				});
				push @hooks, ['configModify', sub {
					$_[1]{key} eq $key && $weak->{config}{$key}->SetValue($_[1]{val});
				}];
			} elsif ($mode eq 'command') {
				$self->AddControl($self->{command}{$key} = new Wx::Button(
					$self, wxID_ANY, $title, wxDefaultPosition, wxDefaultSize, wxBU_EXACTFIT | wxNO_BORDER
				));
				EVT_BUTTON($self, $self->{command}{$key}->GetId, sub {
					Plugins::callHook('interface/defaultFocus');
					Commands::run($key);
				});
			} elsif ($mode =~ /^radio/) {
				$self->AddControl($self->{radio}{$key} = new Wx::RadioButton(
					$self, wxID_ANY, $title, wxDefaultPosition, wxDefaultSize, $mode eq 'radiogroup' && wxRB_GROUP
				));
				EVT_RADIOBUTTON($self, $self->{radio}{$key}->GetId, sub {
					Plugins::callHook('interface/defaultFocus');
					Commands::run($key);
				});
			} else {
				$self->AddSeparator;
			}
		}
		
		push @hooks, ['postloadfiles', sub {
			$weak->{config}{$_}->SetValue($config{$_}) for keys %{$weak->{config}};
			$weak->{radio}{('conf attackAuto 0', 'conf attackAuto 1', 'conf attackAuto 2')[$config{attackAuto}]}->SetValue(1);
		}];
		push @hooks, ['mainLoop_post', sub {
			$weak->{radio}{('ai off', 'ai manual', 'ai auto')[$AI]}->SetValue(1);
		}];
		push @hooks, ['configModify', sub {
			$_[1]{key} eq 'attackAuto' && $weak->{radio}{('conf attackAuto 0', 'conf attackAuto 1', 'conf attackAuto 2')[$_[1]{val}]}->SetValue(1);
		}];
		
		$hooks = Plugins::addHooks(@hooks);
		
		return $self;
	}
	
	sub DESTROY { Plugins::delHooks($hooks) }
}

1;
