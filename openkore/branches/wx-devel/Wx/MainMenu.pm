package Interface::Wx::MainMenu;
use strict;

use Wx ':everything';
use Wx::Event ':everything';

use FindBin qw($RealBin);

use Globals qw/$AI $conState $char @chars %jobs_lut %config/;
use Misc qw/configModify launchURL/;
use Translation qw/T TF/;

sub new {
	my ($class, $frame) = @_;
	
	my $self = bless {
		frame => $frame,
	}, $class;
	
	$self->{frame}->SetMenuBar($self->{menuBar} = new Wx::MenuBar);
	
	$self->{hooks} = Plugins::addHooks(
		['interface/addMenuItem', \&onAddMenuItem, $self],
		['interface/removeMenuItem', \&onRemoveMenuItem, $self],
	);
	
	$self->{menuBar}->Append($self->createMenu([
		{
			title => T('&Pause botting'), key => 'ai_0', command => 'ai off', type => 'radio',
			help => T('Pause all automated botting activity'),
		},
		{
			title => T('&Manual Botting'), key => 'ai_1', command => 'ai manual', type => 'radio',
			help => T('Pause automated botting and allow manual control'),
		},
		{
			title => T('&Automatic Botting'), key => 'ai_2', command => 'ai auto', type => 'radio',
			help => T('Resume all automated botting activity'),
		},
		{},
		{
			title => T('Minimize to &Tray'), sub => sub { $self->onMinimizeToTray },
			help => T('Minimize to a small task bar tray icon'),
		},
		{},
		{
			title => T('Respawn'), command => 'respawn',
			help => T('Teleport to save point'),
		},
		{
			title => T('&Relog'), command => 'relog',
			help => T('Disconnect and reconnect'),
		},
		{
			title => T('&Character Select'), key => 'charselect', submenu => [[], 'charselect'],
		},
		{},
		{wxID => wxID_EXIT, command => 'quit'},
	], 'program'), T('P&rogram'));
	
	$self->{menuBar}->Append($self->createMenu([
		{title => T('&Status'), command => 's'},
		{title => T('S&tats'), command => 'st'},
		{title => T('S&kills'), command => 'skills'},
		{},
		{title => T('&Inventory'), command => 'i'},
		{title => T('E&quipment'), command => 'eq'},
		{title => T('Storage'), command => 'storage'},
		{title => T('Cart'), command => 'cart'},
		{title => T('Loot'), command => 'il'},
		{title => T('Store'), command => 'store'},
		{title => T('Deal'), command => 'dl'},
		{},
		{title => T('&Players'), command => 'pl'},
		{title => T('&Monsters'), command => 'ml'},
		{title => T('&NPCs'), command => 'nl'},
		{},
		{title => T('&Experience report'), command => 'exp'},
		{title => T('Monster killed report'), command => 'exp monster'},
		{title => T('Damage taken report'), command => 'damage'},
		{title => T('Item change report'), command => 'exp item'},
		{title => T('Chat log'), command => 'chist'},
		{title => T('Item log'), command => 'ihist'},
		{},
		{title => T('Account information'), command => 'whoami'},
	], 'info'), T('I&nfo'));
	
	$self->{menuBar}->Append($self->createMenu([
		{
			key => 'toggleWindow_chatLog', title => T('Chat &log'), type => 'check',
			sub => sub { $self->{frame}->toggleWindow('chatLog', T('Chat log'), 'Interface::Wx::Window::ChatLog', 'notebook') },
		},
		{},
		{
			key => 'toggleWindow_character', title => T('Character'), type => 'check',
			sub => sub { $self->{frame}->toggleWindow('character', T('Character'), 'Interface::Wx::Window::You', 'right') },
		},
		{
			key => 'toggleWindow_homunculus', title => T('Homunculus'), type => 'check',
			sub => sub { $self->{frame}->toggleWindow('homunculus', T('Homunculus'), 'Interface::Wx::Window::Homunculus', 'right') },
		},
		{
			key => 'toggleWindow_mercenary', title => T('Mercenary'), type => 'check',
			sub => sub { $self->{frame}->toggleWindow('mercenary', T('Mercenary'), 'Interface::Wx::Window::Mercenary', 'right') },
		},
		{
			key => 'toggleWindow_pet', title => T('Pet'), type => 'check',
			sub => sub { $self->{frame}->toggleWindow('pet', T('Pet'), 'Interface::Wx::Window::Pet', 'right') },
		},
		{},
		{
			key => 'toggleWindow_inventory', title => T('Inventory'), type => 'check',
			sub => sub { $self->{frame}->toggleWindow('inventory', T('Inventory'), 'Interface::Wx::Window::Inventory', 'right') },
		},
		{
			key => 'toggleWindow_cart', title => T('Cart'), type => 'check',
			sub => sub { $self->{frame}->toggleWindow('cart', T('Cart'), 'Interface::Wx::Window::Cart', 'right') },
		},
		{
			key => 'toggleWindow_storage', title => T('Storage'), type => 'check',
			sub => sub { $self->{frame}->toggleWindow('storage', T('Storage'), 'Interface::Wx::Window::Storage', 'right') },
		},
		{},
		{
			key => 'toggleWindow_skills', title => T('Skills'), type => 'check',
			sub => sub { $self->{frame}->toggleWindow('skills', T('Skills'), 'Interface::Wx::Window::Skills', 'right') },
		},
		{},
		{
			key => 'toggleWindow_emotion', title => T('Emotions'), type => 'check',
			sub => sub { $self->{frame}->toggleWindow('emotion', T('Emotions'), 'Interface::Wx::Window::Emotion', 'right') },
		},
		{},
		{
			key => 'toggleWindow_exp', title => T('Experience report'), type => 'check',
			sub => sub { $self->{frame}->toggleWindow('exp', T('Experience report'), 'Interface::Wx::Window::Exp', 'right') },
		},
	], 'view'), T('&View'));
	
	$self->{menuBar}->Append($self->createMenu([
		{
			key => 'toggleWindow_configEditor', title => T('&Advanced...'), type => 'check',
			sub => sub { $self->{frame}->toggleWindow('configEditor', T('Advanced configuration'), 'Interface::Wx::Window::ConfigEditor', 'notebook') },
			help => T('Edit advanced configuration options.'),
		},
	], 'settings'), T('&Settings'));
	
	$self->{menuBar}->Append($self->createMenu([
		{title => T('Website'), sub => sub { launchURL($Settings::WEBSITE) }, help => $Settings::WEBSITE},
		{title => T('&Manual'), sub => sub { launchURL('http://wiki.openkore.com/index.php?title=Manual') }, help => 'Read the manual'},
		{title => T('&Wiki'), sub => sub { launchURL('http://wiki.openkore.com/') }},
		{title => T('&Forum'), sub => sub { launchURL('http://forums.openkore.com/') }, help => 'Visit the forum'},
		{},
		{wxID => wxID_ABOUT, sub => \&onAbout},
	], 'help'), T('&Help'));
	
	EVT_MENU_OPEN($self->{frame}, sub { $self->onMenuOpen });
	
	return $self;
}

sub DESTROY {
	my ($self) = @_;
	
	Plugins::delHooks($self->{hooks});
}

sub createMenu {
	my ($self, $data, $key) = @_;
	
	my $menu = new Wx::Menu;
	
	for my $i (@$data) {
		if (scalar %$i) {
			onAddMenuItem(undef, {%$i, menu => $menu}, $self);
		} else {
			$menu->AppendSeparator;
		}
	}
	
	$self->{menus}{$key} = {menu => $menu} if $key;
	
	return $menu;
}

sub onAddMenuItem {
	my (undef, $args, $self) = @_;
	
	return unless $args->{menu};
	
	my $menu;
	unless (($menu = $args->{menu})->isa('Wx::Menu')) {
		$menu = $self->{menus}{$args->{menu}} or return;
		unless ($menu->{separator}) {
			$menu->{menu}->AppendSeparator;
			$menu->{separator} = 1;
		}
		$menu = $menu->{menu};
	}
	
	$menu->Append(my $item = new Wx::MenuItem(undef, $args->{wxID} || wxID_ANY, $args->{title}, $args->{help},
		$args->{type} eq 'check' ? wxITEM_CHECK : $args->{type} eq 'radio' ? wxITEM_RADIO : undef,
		$args->{submenu} ? $self->createMenu(@{$args->{submenu}}) : undef
	));
	if ($args->{command}) {
		EVT_MENU($self->{frame}, $item->GetId, sub { Commands::run($args->{command}) });
	} elsif ($args->{sub}) {
		EVT_MENU($self->{frame}, $item->GetId, $args->{sub});
	}
	
	$self->{items}{$args->{key}} = $item if $args->{key};
}

sub onRemoveMenuItem {
	my (undef, $args, $self) = @_;
	
	if ($args->{key} and my $item = $self->{items}{$args->{key}}) {
		if ($item->isa('Wx::MenuItem') and my $menu = $item->GetMenu) {
			$menu->Remove($item);
			delete $self->{items}{$args->{key}};
		}
	}
}

sub onMenuOpen {
	my ($self) = @_;
	
	$self->{items}{"ai_" . ($AI || 0)} && $self->{items}{"ai_" . ($AI || 0)}->Check(1);
	
	# Wx::MenuItem->SetSubMenu does not work
	
	onRemoveMenuItem(undef, {key => $_}, $self)
	for grep /^charselect_/, keys %{$self->{items}};
	
	onAddMenuItem(undef, {key => "charselect_undef", title => T('Exit to the character selection screen'), command => 'conf char none;;charselect', type => 'radio', menu => $self->{menus}{charselect}{menu}}, $self);
	onAddMenuItem(undef, {key => "charselect_$_", title => (
		sprintf '%d: %s %d/%d %s', $_, $chars[$_]{name}, $chars[$_]{lv}, $chars[$_]{lv_job}, $jobs_lut{$chars[$_]{jobID}}
	), command => "conf char $_;;charselect", type => 'radio', menu => $self->{menus}{charselect}{menu}}, $self)
	for grep {$chars[$_]} (0 .. @chars-1);
	
	if (defined $config{char} && $self->{items}{"charselect_$config{char}"}) {
		$self->{items}{"charselect_$config{char}"}->Check(1);
	} else {
		$self->{items}{charselect_undef}->Check(1);
	}
	
	$self->{items}{"toggleWindow_$_"}->Check(!!$self->{frame}{windows}{$_})
	for map /^toggleWindow_(.+)$/, keys %{$self->{items}};
	
=pod
	$self->{infoBarToggle}->Check($self->{infoPanel}->IsShown);
	
	while (my ($setting, $menu) = each (%{$self->{mBooleanSetting}})) {
		$menu->Check ($config{$setting} ? 1 : 0);
	}
	
	my $menu;
	while ($menu = $self->{aliasMenu}->FindItemByPosition (0)) {
		$self->{aliasMenu}->Delete ($menu);
	}
	
	for $menu (sort map {/^alias_(.+)$/} keys %config) {
		$self->addMenu ($self->{aliasMenu}, $menu, sub { Commands::run ($menu) });
	}
=cut
}

sub onMinimizeToTray {
	my ($self) = @_;
	
	my $tray = new Wx::TaskBarIcon;
	$tray->SetIcon($self->{frame}->GetIcon, $char ? "$char->{name} - $Settings::NAME" : "$Settings::NAME");
	EVT_TASKBAR_LEFT_DOWN($tray, sub {
		$tray->RemoveIcon;
		undef $tray;
		$self->{frame}->Show(1);
	});
	EVT_TASKBAR_RIGHT_DOWN($tray, sub {
		my $menu = new Wx::Menu(); #($Settings::NAME);
		EVT_MENU($tray, $menu->Append(wxID_ANY, T('E&xit'))->GetId, sub { Commands::run('quit') });
		$_[0]->PopupMenu($menu);
	});
	$self->{frame}->Show(0);
}

sub onAbout {
	Wx::AboutBox(do {
		local $_ = Wx::AboutDialogInfo->new;
		$_->SetVersion($Settings::VERSION . $Settings::SVN);
		$_->SetDescription(T('Custom Ragnarok Online client'));
		$_->SetCopyright(T('(C) OpenKore developers'));
		$_->SetWebSite($Settings::WEBSITE);
		
=pod
		$_->SetDevelopers([
			'',
			'',
		]);
		
		$_->SetDocWriters([
			'',
			'',
		]);
		
		$_->SetTranslators([
			'',
			'',
		]);
=cut
		
		if (-f (my $license = "$RealBin/LICENSE.TXT")) {
			$_->SetLicense(do { open my $f, $license; local $/; <$f> });
		}
		
	$_ });
}

1;

__END__

	# View menu
	my $viewMenu = $self->{viewMenu} = new Wx::Menu;
	$self->addMenu (
		$viewMenu, T('&Map') . "\tCtrl-M", \&onMapToggle, T('Show where you are on the current map')
	);
	$self->{infoBarToggle} = $self->addCheckMenu (
		$viewMenu, T('&Info Bar'), \&onInfoBarToggle, T('Show or hide the information bar.')
	);
	
	$menu->Append($viewMenu, T('&View'));
	
	$self->{aliasMenu} = new Wx::Menu;
	$menu->Append ($self->{aliasMenu}, T('&Alias'));
}

sub createSettingsMenu {
	my ($self, $parentMenu) = @_;
	
	$self->{mBooleanSetting}{'wx_npcTalk'} = $self->addCheckMenu (
		$parentMenu, T('Use Wx NPC Talk'), sub { $self->onBooleanSetting ('wx_npcTalk'); },
		T('Open a dialog when talking with NPCs')
	);
	
	$self->{mBooleanSetting}{'wx_map_route'} = $self->addCheckMenu (
		$parentMenu, T('Show route on map'), sub { $self->onBooleanSetting ('wx_map_route'); },
		T('Show route solution steps')
	);
	
	$parentMenu->AppendSeparator;
}