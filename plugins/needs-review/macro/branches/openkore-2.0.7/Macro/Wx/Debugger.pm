# macro plugin debugger by EternalHarvest
# requires Wx interface
#
# $Revision: 6983 $
# $Id: Wx.pm 6983 2009-12-16 14:46:48Z eternalharvest $

package Macro::Wx::Debugger;

use strict;
use base 'Wx::Panel';
use Wx ':everything';
use Wx::Event qw/EVT_TOOL EVT_MENU EVT_LIST_ITEM_ACTIVATED/;

use Translation qw/T TF/;

use Macro::Data;

sub imageFile {
	return $macro::plugin_folder . '/Macro/Wx/' . $_[0];
}

sub new {
	my ($class, $parent, $id) = @_;
	
	my $self = $class->SUPER::new ($parent, $id);
	
	my %bitmap = (
		reload => new Wx::Bitmap (new Wx::Image (imageFile ('reload.png'), wxBITMAP_TYPE_ANY)),
		watch => new Wx::Bitmap (new Wx::Image (imageFile ('watch.png'), wxBITMAP_TYPE_ANY)),
		go => new Wx::Bitmap (new Wx::Image (imageFile ('go.png'), wxBITMAP_TYPE_ANY)),
		break => new Wx::Bitmap (new Wx::Image (imageFile ('break.png'), wxBITMAP_TYPE_ANY)),
		stop => new Wx::Bitmap (new Wx::Image (imageFile ('stop.png'), wxBITMAP_TYPE_ANY)),
		step => new Wx::Bitmap (new Wx::Image (imageFile ('step.png'), wxBITMAP_TYPE_ANY)),
	);
	
	$self->SetSizer (my $vsizer = new Wx::BoxSizer (wxVERTICAL));
	
	$vsizer->Add ($self->{toolbar} = new Wx::ToolBar (
		$self, wxID_ANY, wxDefaultPosition, wxDefaultSize,
		wxTB_HORIZONTAL | wxNO_BORDER | wxTB_3DBUTTONS | wxTB_FLAT | wxTB_TEXT
	), 0, wxGROW);
	$self->{toolbar}->SetToolBitmapSize (new Wx::Size (12, 12));
	EVT_TOOL ($self->{toolbar}, $self->{tool}{reload} = $self->{toolbar}->AddTool (wxID_ANY, T('Reload'), $bitmap{reload})->GetId, sub { $self->_onReload });
	$self->{toolbar}->AddSeparator;
	EVT_TOOL ($self->{toolbar}, $self->{tool}{watch} = $self->{toolbar}->AddTool (wxID_ANY, T('Variables'), $bitmap{watch}, '', wxITEM_CHECK)->GetId, sub { $self->_onWatch });
	$self->{toolbar}->AddSeparator;
	EVT_TOOL ($self->{toolbar}, $self->{tool}{go} = $self->{toolbar}->AddTool (wxID_ANY, T('Go'), $bitmap{go})->GetId, sub { $self->_onGo });
	EVT_TOOL ($self->{toolbar}, $self->{tool}{break} = $self->{toolbar}->AddTool (wxID_ANY, T('Break'), $bitmap{break})->GetId, sub { $self->_onBreak });
	EVT_TOOL ($self->{toolbar}, $self->{tool}{stop} = $self->{toolbar}->AddTool (wxID_ANY, T('Stop'), $bitmap{stop})->GetId, sub { $self->_onStop });
	$self->{toolbar}->AddSeparator;
	EVT_TOOL ($self->{toolbar}, $self->{tool}{stepInto} = $self->{toolbar}->AddTool (wxID_ANY, T('Step into'), $bitmap{step})->GetId, sub { $self->_onStepInto });
	EVT_TOOL ($self->{toolbar}, $self->{tool}{stepOver} = $self->{toolbar}->AddTool (wxID_ANY, T('Step over'), $bitmap{step})->GetId, sub { $self->_onStepOver });
	EVT_TOOL ($self->{toolbar}, $self->{tool}{stepOut} = $self->{toolbar}->AddTool (wxID_ANY, T('Step out'), $bitmap{step})->GetId, sub { $self->_onStepOut });
	$self->{toolbar}->Realize;
	
	$vsizer->Add (my $hsizer = new Wx::BoxSizer (wxHORIZONTAL), 1, wxGROW);
	
	$hsizer->Add ($self->{source} = new Wx::ListCtrl (
		$self, wxID_ANY, wxDefaultPosition, wxDefaultSize, wxLC_REPORT | wxLC_NO_HEADER | wxLC_HRULES | wxLC_SINGLE_SEL
	), 1, wxGROW);
	
	$self->{source}->InsertColumn (0, '');
	$self->{source}->InsertColumn (1, '');
	$self->{source}->InsertColumn (2, '');
	$self->{source}->SetColumnWidth (0, 38);
	$self->{source}->SetColumnWidth (1, 38);
	$self->{source}->SetColumnWidth (2, 320);
	EVT_LIST_ITEM_ACTIVATED ($self, $self->{source}->GetId, sub { $self->_onSourceActivate });
	
	$hsizer->Add ($self->{watch} = new Wx::ListCtrl (
		$self, wxID_ANY, wxDefaultPosition, wxDefaultSize, wxLC_REPORT | wxLC_NO_HEADER | wxLC_HRULES | wxLC_SINGLE_SEL
	), 1, wxGROW);
	$self->{watch}->Show (0);
	
	$self->{watch}->InsertColumn (0, '');
	$self->{watch}->InsertColumn (1, '');
	$self->{watch}->SetColumnWidth (0, 76);
	$self->{watch}->SetColumnWidth (1, 320);
	EVT_LIST_ITEM_ACTIVATED ($self, $self->{watch}->GetId, sub { $self->_onWatchActivate });
	
	$vsizer->Add ($self->{status} = new Wx::StatusBar ($self), 0, wxGROW);
	$self->{status}->SetFieldsCount (3);
	$self->{status}->SetStatusWidths (-1, 65, 175);
	
	$self->{hooks} = Plugins::addHooks (
		['macro/error', sub { $self->macroError (@_) }],
		['macro/parseAndHook', sub { $self->parseAndHook (@_) }],
		['macro/callMacro/process', sub { $self->process (@_) }],
	);
	
	$self->update;
	
	return $self;	
}

sub unload {
	my ($self) = @_;
	
	Plugins::delHooks ($self->{hooks});
}

sub updateTool {
	my ($self) = @_;
	
	$self->{toolbar}->EnableTool ($self->{tool}{go}, $onHold && defined $queue);
	$self->{toolbar}->EnableTool ($self->{tool}{break}, !$onHold && defined $queue);
	$self->{toolbar}->EnableTool ($self->{tool}{stop}, defined $queue);
	$self->{toolbar}->EnableTool ($self->{tool}{stepInto}, $onHold && defined $queue);
	$self->{toolbar}->EnableTool ($self->{tool}{stepOver}, $onHold && defined $queue);
	$self->{toolbar}->EnableTool ($self->{tool}{stepOut}, $onHold && defined $queue);
}

sub updateStatus {
	my ($self) = @_;
	
	if (defined $queue) {
		$self->{status}->SetStatusText ($onHold ? T('PAUSE') : T('RUN'), 1);
	} else {
		$self->{status}->SetStatusText (T('STOP'), 1);
	}
}

sub updateSource {
	my ($self) = @_;
	
	my $script = $queue or return;
	my @callStack;
	do {
		unshift @callStack, $script->name . ':' . $script->line;
	} while $script->{subcall} and $script = $script->{subcall};
	
	$self->{status}->SetStatusText ("@callStack", 2);
	
	my $name = $script->name;
	if (!defined $self->{sourceName} or $name ne $self->{sourceName}) {
		$self->{source}->DeleteAllItems;
		$self->{sourceName} = $name;
		
		my $i;
		for ($i = 0; $i < @{$macro{$name}}; $i++) {
			$self->{source}->InsertStringItem ($i, '');
			$self->{source}->SetItem ($i, 1, $i);
			$self->{source}->SetItem ($i, 2, ${$macro{$name}}[$i]);
		}
		
		$self->{source}->InsertStringItem ($i, '');
		$self->{source}->SetItem ($i, 1, '');
		$self->{source}->SetItem ($i, 2, '__END__');
	}
	
	my $line = $script->line;
	if (!defined $self->{sourceLine} or $line != $self->{sourceLine}) {
		$self->{source}->SetItemText ($self->{sourceLine}, '') if defined $self->{sourceLine};
		$self->{sourceLine} = $line;
		$self->{source}->SetItemText ($self->{sourceLine}, '-->');
	}
}

sub updateWatch {
	my ($self) = @_;
	
	my $i;
	for (keys %varStack) {
		if (-1 == ($i = $self->{watch}->FindItem (-1, $_))) {
			$i = $self->{watch}->InsertItem (new Wx::ListItem);
			$self->{watch}->SetItemText ($i, $_);
		}
		
		if ($varStack{$_} ne $self->{watch}->GetItem ($i, 1)->GetText) {
			$self->{watch}->SetItem ($i, 1, $varStack{$_});
		}
		
		delete $self->{watchStack}{$_};
	}
	
	for (keys %{$self->{watchStack}}) {
		$self->{watch}->DeleteItem ($self->{watch}->FindItem (-1, $_));
	}
	
	$self->{watchStack} = {%varStack};
}

sub update {
	my ($self) = @_;
	
	$self->updateTool;
	$self->updateStatus;
	$self->updateSource;
	$self->updateWatch;
}

sub cleanup {
	my ($self) = @_;
	
	undef $self->{step};
	undef $self->{stepLevel};
	$onHold = 0;
}

sub macroError {
	my ($self, undef, $args) = @_;
	
	$onHold = 1;
	
	$self->updateTool;
	$self->updateStatus;
	$self->{status}->SetStatusText ($args->{error}, 0);
	
	my $script = $queue;
	do {
		undef $script->{error};
		$script->{macro_block} = 0;
	} while $script = $script->{subcall};
	
	$args->{return} = 1;
	$args->{continue} = 0;
}

sub parseAndHook {
	my ($self) = @_;
	
	undef $self->{sourceName};
	undef $self->{sourceLine};
	$self->updateSource;
}

sub process {
	my ($self) = @_;
	
	$self->{status}->SetStatusText ('', 0);
	
	unless (defined $queue) {
		$self->cleanup;
	} elsif ($self->{step}) {
		my $level = $self->subCallNesting;
		if (
			$self->{step} eq 'into'
			or $self->{step} eq 'over' && $level <= $self->{stepLevel}
			or $self->{step} eq 'out' && $level < $self->{stepLevel}
		) {
			undef $self->{step};
			undef $self->{stepLevel};
			$onHold = 1;
		}
	}
	
	$self->update;
}

sub _onReload {
	$_ = $Globals::config{macro_file} || 'macros.txt';
	s/\.\w{3}$//;
	Commands::run ("reload $_");
}

sub _onWatch {
	my ($self) = @_;
	
	$self->{watch}->Show ($self->{toolbar}->GetToolState ($self->{tool}{watch}));
	$self->GetSizer->Layout;
}

sub _onGo {
	my ($self) = @_;
	
	if (defined $queue) {
		$onHold = 0;
		
		$self->updateTool;
		$self->updateStatus;
	}
}

sub _onBreak {
	my ($self) = @_;
	
	if (defined $queue) {
		$onHold = 1;
		
		$self->updateTool;
		$self->updateStatus;
	}
}

sub _onStop {
	my ($self) = @_;
	
	if (defined $queue) {
		undef $queue;
		$self->cleanup;
		
		$self->updateTool;
		$self->updateStatus;
	}
}

sub _onStepInto {
	my ($self) = @_;
	
	if (defined $queue) {
		$self->{step} = 'into';
		$onHold = 0;
		
		$self->updateTool;
		$self->updateStatus;
	}
}

sub _onStepOver {
	my ($self) = @_;
	
	if (defined $queue) {
		$self->{step} = 'over';
		$self->{stepLevel} = $self->subCallNesting;
		$onHold = 0;
		
		$self->updateTool;
		$self->updateStatus;
	}
}

sub _onStepOut {
	my ($self) = @_;
	
	if (defined $queue) {
		$self->{step} = 'out';
		$self->{stepLevel} = $self->subCallNesting;
		$onHold = 0;
		
		$self->updateTool;
		$self->updateStatus;
	}
}

sub _onSourceActivate {
	my ($self) = @_;
	
	my $i;
	last if -1 == ($i = $self->{source}->GetNextItem (-1, wxLIST_NEXT_ALL, wxLIST_STATE_SELECTED));
	$self->changeLine ($i);
}

sub _onWatchActivate {
	my ($self) = @_;
	
	my $i;
	last if -1 == ($i = $self->{watch}->GetNextItem (-1, wxLIST_NEXT_ALL, wxLIST_STATE_SELECTED));
	my $key = $self->{watch}->GetItemText ($i);
	
	my $value = $Globals::interface->query (TF('Enter new value for variable %s.', $key),
		title => T('Macro')
	);
	
	return unless defined $value;
	
	$varStack{$key} = $value;
	$self->updateWatch;
}

sub changeLine {
	my ($self, $value) = @_;
	
	if (defined $queue) {
		$self->subCalledScript->{line} = $value;
		
		$self->updateSource;
	}
}

sub subCalledScript {
	my $script = $queue or return;
	$script = $script->{subcall} while $script->{subcall};
	return $script;
}

sub subCallNesting {
	my $script = $queue or return 0;
	my $i = 1;
	while ($script->{subcall}) {
		$script = $script->{subcall};
		$i++;
	}
	return $i;
}

1;
