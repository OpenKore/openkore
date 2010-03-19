package Interface::Wx::MainMenu;
use strict;

use Wx ':everything';
use Wx::Event ':everything';

use FindBin qw($RealBin);

use Globals qw/$AI $conState $char/;
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
			title => T('&Character Select'), key => 'charselect', sub => sub {
				configModify('char', undef, 1);
				Commands::run('charselect');
			},
			help => T('Exit to the character selection screen'),
		},
		{},
		{
			title => T('E&xit'), command => 'quit',
			help => T('Exit this program'),
		},
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
	
	$self->{menuBar}->Append($self->createMenu([], 'view'), T('&View'));
	
	$self->{menuBar}->Append($self->createMenu([], 'settings'), T('&Settings'));
	
	$self->{menuBar}->Append($self->createMenu([
		{title => T('Website'), sub => sub { launchURL($Settings::WEBSITE) }, help => $Settings::WEBSITE},
		{title => T('&Manual'), sub => sub { launchURL('http://wiki.openkore.com/index.php?title=Manual') }, help => 'Read the manual'},
		{title => T('&Wiki'), sub => sub { launchURL('http://wiki.openkore.com/') }},
		{title => T('&Forum'), sub => sub { launchURL('http://forums.openkore.com/') }, help => 'Visit the forum'},
		{},
		{title => T('&About'), sub => \&onAbout},
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
	
	$menu->Append(my $item = new Wx::MenuItem(undef, wxID_ANY, $args->{title}, $args->{help},
		$args->{type} eq 'check' ? wxITEM_CHECK : $args->{type} eq 'radio' ? wxITEM_RADIO : wxITEM_NORMAL
	));
	EVT_MENU($self->{frame}, $item->GetId,
		$args->{command} ? sub { Commands::run($args->{command}) }
		: $args->{sub} ? $args->{sub}
		: sub {}
	);
	
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
	
	$self->{items}{"ai_$_"}->Check($AI == $_) for (0 .. 2);
	$self->{items}{charselect}->Enable($conState == Network::IN_GAME);
	
=pod
	$self->{infoBarToggle}->Check($self->{infoPanel}->IsShown);
	$self->{chatLogToggle}->Check(defined $self->{notebook}->hasPage('Chat Log') ? 1 : 0);
	
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
	$self->{frame}->Show(0);
}

sub onAbout {
	Wx::AboutBox(do {
		local $_ = Wx::AboutDialogInfo->new;
		$_->SetVersion($Settings::VERSION . $Settings::SVN);
		$_->SetDescription(T('Custom Ragnarok Online client'));
		$_->SetCopyright(T('(C) OpenKore developers'));
		$_->SetWebSite($Settings::WEBSITE);
		$_->SetLicence('test');
		
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
	$self->{chatLogToggle} = $self->addCheckMenu (
		$viewMenu, T('Chat &Log'), \&onChatLogToggle, T('Show or hide the chat log.')
	);
	$self->addMenu ($viewMenu, T('Status') . "\tAlt+A", sub { $self->openStats (1) });
	$self->addMenu ($viewMenu, T('Homunculus') . "\tAlt+R", sub { $self->openHomunculus (1) });
	$self->addMenu ($viewMenu, T('Mercenary') . "\tCtrl+R", sub { $self->openMercenary (1) });
	$self->addMenu ($viewMenu, T('Pet') . "\tAlt+J", sub { $self->openPet (1) });
	
	$viewMenu->AppendSeparator;
	
	$self->addMenu ($viewMenu, T('Inventory') . "\tAlt+E", sub { $self->openInventory (1) });
	$self->addMenu ($viewMenu, T('Cart') . "\tAlt+W", sub { $self->openCart (1) });
	$self->addMenu ($viewMenu, T('Storage'), sub { $self->openStorage (1) });
	
	$viewMenu->AppendSeparator;
	
	$self->addMenu ($viewMenu, T('Emotions'). "\tAlt+L", sub { $self->openEmotions (1) });
	
	$viewMenu->AppendSeparator;
	
	$self->addMenu($viewMenu, T('&Experience Report') . "\tCtrl+E", sub {
		$self->openWindow ('Report', 'Interface::Wx::StatView::Exp', 1) 
	});
	
	$viewMenu->AppendSeparator;
	
	$self->addMenu ($viewMenu, T('&Font...'), \&onFontChange, T('Change console font'));
	$self->addMenu($viewMenu, T('Clear Console'), sub {my $self = shift; $self->{console}->Remove(0, 40000)}, T('Clear content of console'));
	
	$menu->Append($viewMenu, T('&View'));
	
	$self->{aliasMenu} = new Wx::Menu;
	$menu->Append ($self->{aliasMenu}, T('&Alias'));
	
	# Settings menu
	my $settingsMenu = new Wx::Menu;
	$self->createSettingsMenu($settingsMenu) if ($self->can('createSettingsMenu'));
	$self->addMenu($settingsMenu, T('&Advanced...'), \&onAdvancedConfig, T('Edit advanced configuration options.'));
	$menu->Append($settingsMenu, T('&Settings'));
	$self->createSettingsMenu2($settingsMenu) if ($self->can('createSettingsMenu2'));
}

sub createSettingsMenu {
	my ($self, $parentMenu) = @_;
	
	$self->{mBooleanSetting}{'wx_npcTalk'} = $self->addCheckMenu (
		$parentMenu, T('Use Wx NPC Talk'), sub { $self->onBooleanSetting ('wx_npcTalk'); },
		T('Open a dialog when talking with NPCs')
	);
	
	$self->{mBooleanSetting}{'wx_captcha'} = $self->addCheckMenu (
		$parentMenu, T('Use Wx captcha'), sub { $self->onBooleanSetting ('wx_captcha'); },
		T('Open a dialog when receiving a captcha')
	);
	
	$self->{mBooleanSetting}{'wx_map_route'} = $self->addCheckMenu (
		$parentMenu, T('Show route on map'), sub { $self->onBooleanSetting ('wx_map_route'); },
		T('Show route solution steps')
	);
	
	$parentMenu->AppendSeparator;
}