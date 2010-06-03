package Interface::Wx::MainMenu;
use strict;

use Wx ':everything';
use Wx::Event ':everything';
use Wx::ArtProvider qw/:artid :clientid/;

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
			title => T('&Pause Botting'), key => 'ai_0', command => 'ai off', type => 'radio',
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
	], 'program'), T('Pr&ogram'));
	
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
		{title => T('Party')."\tAlt+Z", command => 'party'},
		{title => T('Friends')."\tAlt+H", command => 'friend'},
		{title => T('&Monsters'), command => 'ml'},
		{title => T('&NPCs'), command => 'nl'},
		{title => T('Chatrooms')."\tAlt+C", command => 'chat list'},
		{},
		{title => T('&Experience Report'), command => 'exp'},
		{title => T('Monster Killed Report'), command => 'exp monster'},
		{title => T('Damage Taken Report'), command => 'damage'},
		{title => T('Item Change Report'), command => 'exp item'},
		{title => T('Chat Log'), command => 'chist'},
		{title => T('Item Log'), command => 'ihist'},
		{},
		{title => T('Account Information'), command => 'whoami'},
	], 'info'), T('I&nfo'));
	
	$self->{menuBar}->Append($self->createMenu([
		{
			key => 'toggleWindow_map', title => T('&Map')."\tCtrl+M", type => 'check',
			sub => sub { $self->{frame}->toggleWindow('map', 'Interface::Wx::Window::Map', 'right') },
		},
		{
			key => 'toggleWindow_chatLog', title => T('Chat &Log'), type => 'check',
			sub => sub { $self->{frame}->toggleWindow('chatLog', 'Interface::Wx::Window::ChatLog', 'notebook') },
		},
		{},
		{
			key => 'toggleWindow_character', title => T('Status')."\tAlt+A", type => 'check',
			sub => sub { $self->{frame}->toggleWindow('character', 'Interface::Wx::Window::You', 'notebook') },
		},
		{
			key => 'toggleWindow_homunculus', title => T('Homunculus')."\tAlt+R", type => 'check',
			sub => sub { $self->{frame}->toggleWindow('homunculus', 'Interface::Wx::Window::Homunculus', 'right') },
		},
		{
			key => 'toggleWindow_mercenary', title => T('Mercenary')."\tCtrl+R", type => 'check',
			sub => sub { $self->{frame}->toggleWindow('mercenary', 'Interface::Wx::Window::Mercenary', 'right') },
		},
		{
			key => 'toggleWindow_pet', title => T('Pet')."\tAlt+J", type => 'check',
			sub => sub { $self->{frame}->toggleWindow('pet', 'Interface::Wx::Window::Pet', 'right') },
		},
		{},
		{
			key => 'toggleWindow_inventory', title => T('Inventory')."\tAlt+E", type => 'check',
			sub => sub { $self->{frame}->toggleWindow('inventory', 'Interface::Wx::Window::Inventory', 'right') },
		},
		{
			key => 'toggleWindow_cart', title => T('Cart')."\tAlt+W", type => 'check',
			sub => sub { $self->{frame}->toggleWindow('cart', 'Interface::Wx::Window::Cart', 'right') },
		},
		{
			key => 'toggleWindow_storage', title => T('Storage'), type => 'check',
			sub => sub { $self->{frame}->toggleWindow('storage', 'Interface::Wx::Window::Storage', 'right') },
		},
		{},
		{
			key => 'toggleWindow_skills', title => T('Skills')."\tAlt+S", type => 'check',
			sub => sub { $self->{frame}->toggleWindow('skills', 'Interface::Wx::Window::Skills', 'right') },
		},
		{},
		{
			key => 'toggleWindow_emotion', title => T('Emotions')."\tAlt+L", type => 'check',
			sub => sub { $self->{frame}->toggleWindow('emotion', 'Interface::Wx::Window::Emotion', 'right') },
		},
		{},
		{
			key => 'toggleWindow_npcTalk', title => T('NPC Talk'), type => 'check',
			sub => sub { $self->{frame}->toggleWindow('npcTalk', 'Interface::Wx::Window::NPCTalk', 'notebook') },
		},
		{
			key => 'toggleWindow_npcStore', title => T('NPC Store'), type => 'check',
			sub => sub { $self->{frame}->toggleWindow('npcStore', 'Interface::Wx::Window::NPCStore', 'notebook') },
		},
		{
			key => 'toggleWindow_playerStore', title => T('Player Store'), type => 'check',
			sub => sub { $self->{frame}->toggleWindow('playerStore', 'Interface::Wx::Window::PlayerStore', 'notebook') },
		},
		{
			key => 'toggleWindow_deal', title => T('Deal'), type => 'check',
			sub => sub { $self->{frame}->toggleWindow('deal', 'Interface::Wx::Window::Deal', 'notebook') },
		},
		{},
		{
			key => 'toggleWindow_exp', title => T('Experience Report')."\tCtrl+E", type => 'check',
			sub => sub { $self->{frame}->toggleWindow('exp', 'Interface::Wx::Window::Exp', 'right') },
		},
	], 'view'), T('V&iew'));
	
	$self->{menuBar}->Append($self->createMenu([
		{
			key => 'toggleWindow_configEditor', title => T('&Advanced...'), type => 'check',
			sub => sub { $self->{frame}->toggleWindow('configEditor', 'Interface::Wx::Window::ConfigEditor', 'notebook') },
			help => T('Edit advanced configuration options.'),
		},
	], 'settings'), T('Se&ttings'));
	
	$self->{menuBar}->Append($self->createMenu([
		{title => T('&Command List')."\tAlt+Y", command => 'help'},
		{},
		{title => T('Web&site'), url => $Settings::WEBSITE },
		{title => T('&Manual')."\tF1", url => 'http://wiki.openkore.com/index.php?title=Manual', art => wxART_HELP },
		{title => T('&Wiki'), url => 'http://wiki.openkore.com/' },
		{title => T('&Forum')."\tShift+F1", url => 'http://forums.openkore.com/' },
		{},
		{wxID => wxID_ABOUT, sub => \&onAbout},
	], 'help'), T('Hel&p'));
	
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
	
	my $item = new Wx::MenuItem(undef, $args->{wxID} || wxID_ANY, $args->{title}, $args->{help} || $args->{url},
		$args->{type} eq 'check' ? wxITEM_CHECK : $args->{type} eq 'radio' ? wxITEM_RADIO : wxITEM_NORMAL,
		$args->{submenu} ? $self->createMenu(@{$args->{submenu}}) : undef
	);
	
	$item->SetBitmap(Wx::ArtProvider::GetBitmap($args->{art}, wxART_MENU)) if $args->{art};
	
	$menu->Append($item);
	
	if ($args->{command}) {
		EVT_MENU($self->{frame}, $item->GetId, sub { Commands::run($args->{command}) });
	} elsif ($args->{url}) {
		EVT_MENU($self->{frame}, $item->GetId, sub { launchUrl($args->{url}) });
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
	
	onAddMenuItem(undef, {key => "charselect_$_", title => (
		$_ eq 'none' ? T('Exit to the character selection screen')
		: sprintf '%d: %s %d/%d %s', $_, $chars[$_]{name}, $chars[$_]{lv}, $chars[$_]{lv_job}, $jobs_lut{$chars[$_]{jobID}}
	), command => "conf char $_;;charselect", type => 'radio', menu => $self->{menus}{charselect}{menu}}, $self)
	for (($self->{items}{charselect_none} ? () : 'none'), grep {$chars[$_]} (0 .. @chars-1));
	
	$self->{items}{'charselect_' . (
		defined $config{char} && $self->{items}{"charselect_$config{char}"} ? $config{char} : 'none'
	)}->Check(1);
	
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