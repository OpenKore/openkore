#########################################################################
#  Win32::GUI Interface for OpenKore
#  by: amacc_boy (koreadvance@yahoo.com)
#
#########################################################################

package Interface::Win32;
use strict;
use warnings;

use Interface;
use base qw/Interface/;
use Time::HiRes qw/time usleep/;
use Settings qw(%sys);
use Plugins;
use Globals;
use Settings;
use Misc;

use Win32::GUI;
use Win32::GUI::Constants qw(WS_CHILD WS_VISIBLE WS_VSCROLL ES_LEFT ES_MULTILINE ES_READONLY ES_AUTOVSCROLL MB_OK MB_ICONERROR);

use Interface::Win32::Map; #Map Viewer


our ($currentHP, $currentSP, $currentLvl, $currentJob, $currentStatus);
our ($statText, $xyText, $aiText) = ('', '', '');
our $map;

our @input_que;
our @input_list;

our %fgcolors;
our %bgcolors;

our $line_limit_chat = 500; #chat window line limit
our $line_limit_console = 500; #console window line limit
our ($updateUITime);

sub new {
	my $class = shift;
	my $self = {
		mw => undef,
		default_font=>"MS Sans Serif",
		r_field => undef,
	};

	$map = new Interface::Win32::Map();
	
	bless $self, $class;
	$self->initGUI;

	$self->{hooks} = Plugins::addHooks(
		['mainLoop_pre',		\&updateHook,	$self],
		['parseMsg/addPrivMsgUser', sub { $self->addPM(@_); }],
	);
		
	return $self;
}

sub DESTROY {
	my $self = shift;

	Plugins::delHooks($self->{hooks});
}

######################
## METHODS
######################

sub getInput {
	my $self = shift;
	my $timeout = shift;
	my $msg;

	if ($timeout < 0) {
		until (defined $msg) {
			$self->update();
			if (@input_que) {
				$msg = shift @input_que; 
			}
		}
	} elsif ($timeout > 0) {
		my $end = time + $timeout;
		until ($end < time || defined $msg) {
			$self->update();
			if (@input_que) { 
				$msg = shift @input_que; 
			} 
		}
	} else {		
		if (@input_que) {
			$msg = shift @input_que;
		}
	}
	
	$self->update();
	$msg =~ s/\n// if defined $msg;

	return $msg;
}

sub writeOutput {
	my $self = shift;
	my $type = shift || '';
	my $message = shift || '';
	my $domain = shift || '';
	my ($color,$fgcode);

	$color = $consoleColors{$type}{$domain} if (defined $type && defined $domain && defined $consoleColors{$type});
	$color = $consoleColors{$type}{'default'} if (!defined $color && defined $type);
	$color = 'default' unless defined $color;
	$fgcode = $fgcolors{$color};
	
	#Chat Window
	if ($domain eq "pm" || $domain eq "pm/sent" || $domain eq "publicchat" || $domain eq "guildchat" || $domain eq "selfchat" || $domain eq "schat") {
		$self->{chat}->Select(999999,999999);
		$self->{chat}->SetCharFormat (-color => $fgcode); #no backcolor =(
    	$self->{chat}->ReplaceSel("$message", 1);
	    select(undef, undef, undef, 0);

		#remove extra lines
		while ($self->{chat}->GetLineCount() > $line_limit_chat + 1) {
		    $self->{chat}->Select(0, $self->{chat}->LineLength(0) + 1);
		    $self->{chat}->ReplaceSel("", 1);
		    select(undef, undef, undef, 0);
		}
	    	
	  	$self->{chat}->SendMessage (0x115, 7, 0);   # scroll to bottom
	  	$self->{chat}->SendMessage (0x115, 1, 0);   # scroll one line down
	  	
	#Console Window
	} else {
		$self->{console}->Select(999999,999999);
		$self->{console}->SetCharFormat (-color => $fgcode);
    	$self->{console}->ReplaceSel("$message", 1);
	    select(undef, undef, undef, 0);

		#remove extra lines
		while ($self->{console}->GetLineCount() >= $line_limit_console) {
		    $self->{console}->Select(0, $self->{console}->LineLength(0) + 1);
		    $self->{console}->ReplaceSel("", 1);
		    select(undef, undef, undef, 0);
		}
	   	
	  	$self->{console}->SendMessage (0x115, 7, 0);   # scroll to bottom
	  	$self->{console}->SendMessage (0x115, 1, 0);   # scroll one line down
	  	
	}
  	
    Win32::GUI::PeekMessage(0,0,0);
    $self->update();
}

sub updateHook {
	my $hookname = shift;
	my $r_args = shift;
	my $self = shift;
	return unless defined $self->{mw};
	$self->update();
}

sub update {
	my $self = shift;
	if (Utils::timeOut($updateUITime, 0.5)) {
		$self->UpdateCharacter();
		$self->updateStatusBar();
		if ($map->mapIsShown()) {
			$map->paintMap() unless ($field->baseName eq $map->currentMap());
			$map->Repaint();
			$map->paintPlayers();
			$map->paintMonsters();
			$map->paintNPCs();
			$map->paintPos();
		}
		$updateUITime = time;
	}
    Win32::GUI::DoEvents();	
}

sub title {
	my $self = shift;
	my $title = shift;

	if (defined $title) {
		if (!defined $self->{currentTitle} || $self->{currentTitle} ne $title) {
			$self->{mw}->Caption($title);
			$self->{currentTitle} = $title;
		}
	} else {
		return $self->{title};
	}
}

sub updateStatus {
	my $self = shift;
	my $text = shift;
	$self->{status_gen}->Text($text);
}

sub setAiText {
	my $self = shift;
	my ($text) = shift;
	$self->{status_ai}->configure(-text => $text);
}

################################################################
# init
################################################################

sub initGUI {
	my $self = shift;
	
	my $consoleFont = Win32::GUI::Font->new( '-name' => "Courier New", '-size' => 10);

	$self->{AccTable} = new Win32::GUI::AcceleratorTable (
	 				# Windows commands
					"Return"			=> \&inputEnter,
	 				"Up"				=> \&inputUp,
	 				"Down"				=> \&inputDown,
 				    "Ctrl-W"			=> \&onExit,
					"Ctrl-F4"			=> \&menuMinimizeToTry,
					"Ctrl-M"			=> \&openMap,
 				    "Tab"				=> sub { $self->{input}->SetFocus(); },
					"F1"				=> \&menuWikiURL,
					"Shift+F1"			=> \&menuForumURL,
					
					# In-Game commands
					"Alt+V"				=> \&menuStatus,
					"Alt+A"				=> \&menuStat,
					"Alt+S"				=> \&menuSkills,
					"Alt+E"				=> \&menuInventory,
					"Alt+Z"				=> \&menuPartyInfo,
					"Alt+Q"				=> \&menuEquipWindow,
					"Alt+U"				=> \&menuQuestWindow,
					"Alt+H"				=> \&menuFriendList,
					"Alt+W"				=> \&menuCart,
					"Alt+G"				=> \&menuGuildInfo,
					"Alt+J"				=> \&menuPetInfo,
					"Alt+R"				=> \&menuHomunculusInfo,
					"Ctrl-R"			=> \&menuMercenaryInfo,
					"Ctrl-G"			=> \&menuClanInfo,
					"Ctrl-B"			=> \&menuBank,
					"Ctrl-T"			=> \&menuRodex,

					# Custom commands
					"Alt+P"				=> \&menuPlayerList,
					"Alt+M"				=> \&menuMonsterList,
					"Alt+N"				=> \&menuNPCList,
					"Alt+X"				=> \&menuFullReport,
 				 );

	$self->{Menu} = Win32::GUI::MakeMenu (
		# Program Menu
	    "Open&Kore" => "Kore",
		"	> &Automatic Botting" => { -name => "AI_Auto", -onClick => \&menuAIAuto },
	    "	> &Manual Botting" => { -name => "AI_Manual", -onClick => \&menuAIManual },
		"   > &Pause Botting" => { -name => "AI_Off", -onClick => \&menuAIOff },
		"	> -" => { -name => "separator" },
		"   > Respa&wn" => { -name => "Respawn", -onClick => \&menuRespawn },
		"	> &Character Select" => { -name => "CharSelect", -onClick => \&menuCharSelect },
	    "	> &Relog" => { -name => "Relog", -onClick => \&menuRelog },
		"	> -" => { -name => "separator" },
	    "   > Minimize to Tray		Ctrl-F4" 	=> { -name => "Minimize_Tray", -onClick => \&menuMinimizeToTry },
		"	> -" => { -name => "separator" },
		"   > E&xit					Ctrl-W" 	=> { -name => "Exit", -onClick => \&onExit },
		
		# Info Menu
		"&Info" => "Info",
	    "	> &Status				Alt+V"	=> { -name => "Status", -onClick => \&menuStatus },
	    "   > S&tat					Alt+A"	=> { -name => "Statistics", -onClick => \&menuStat },
		"	> -" => { -name => "separator" },
	    "	> Inventory				Alt+E"	=> { -name => "Inventory", -onClick => \&menuInventory },
		"   > Cart					Alt+W"	=> { -name => "Skills", -onClick => \&menuCart },
		"   > Equip Window			Alt+Q"	=> { -name => "Skills", -onClick => \&menuEquipWindow },
		"   > Storage				Alt+T"	=> { -name => "Skills", -onClick => \&menuStorageInfo },
		"	> -" => { -name => "separator" },
	    "   > Skills				Alt+S"	=> { -name => "Skills", -onClick => \&menuSkills },
		"   > Quests				Alt+U"	=> { -name => "Skills", -onClick => \&menuQuestWindow },
		"	> -" => { -name => "separator" },
		"   > Party					Alt+Z"	=> { -name => "Skills", -onClick => \&menuPartyInfo },
		"   > Friends				Alt+H"	=> { -name => "Skills", -onClick => \&menuFriendList },
		"   > Guild					Alt+G"	=> { -name => "Skills", -onClick => \&menuGuildInfo },
		"   > Clan					Ctrl-G"	=> { -name => "Skills", -onClick => \&menuClanInfo },
		"	> -" => { -name => "separator" },
		"   > Pet					Alt+J"	=> { -name => "Skills", -onClick => \&menuPetInfo },
		"   > Homunculus			Alt+R"	=> { -name => "Skills", -onClick => \&menuHomunculusInfo },
		"   > Mercenary				Ctrl-R"	=> { -name => "Skills", -onClick => \&menuMercenaryInfo },
		"   > Bank					Ctrl-B"	=> { -name => "Skills", -onClick => \&menuBank },
		"   > Rodex					Ctrl-T"	=> { -name => "Skills", -onClick => \&menuRodex },		
		"	> -" => { -name => "separator" },
		"   > Player List			Alt+P"	=> { -name => "Player_List", -onClick => \&menuPlayerList },
		"   > Monster List			Alt+M"	=> { -name => "Monster_List", -onClick => \&menuMonsterList },
		"   > NPC List				Alt+N"	=> { -name => "NPC_List", -onClick => \&menuNPCList },
		"	> -" => { -name => "separator" },
		"   > Experience Report	"	=> { -name => "Experience_Report", -onClick => \&menuExpReport },
		"   > Item Report			"	=> { -name => "Item_Report", -onClick => \&menuItemReport },
		"   > Monster Report		"	=> { -name => "Monster_Report", -onClick => \&menuMonsterReport },
		"   > Full &Report			Alt+X"	=> { -name => "Full_Report", -onClick => \&menuFullReport },
	    
		# View Menu
		"&View" => "View",
	    "   > View &Map				Ctrl-M" 	=> { -name => "View_Map", -onClick => \&openMap },
		
		# Commands Menu
		"&Commands" => "Commands",
		"   > &Teleport" 	=> { -name => "Teleport", -onClick => \&menuTeleport },
		"   > &Memo Position" 	=> { -name => "Memo", -onClick => \&menuMemo },
		"   > &Respawn" 	=> { -name => "Respawn", -onClick => \&menuRespawn },
		"	> -" => { -name => "separator" },
		"   > Sit &Down" 	=> { -name => "Sit", -onClick => \&menuSit },
		"   > Stand &Up" 	=> { -name => "Stand", -onClick => \&menuStand },
		"	> -" => { -name => "separator" },
		"   > Aut&o Store" 	=> { -name => "Store", -onClick => \&menuAutoStore },
		"   > Auto &Sell" 	=> { -name => "Sell", -onClick => \&menuAutoSell },
		"   > Auto &Buy" 	=> { -name => "Buy", -onClick => \&menuAutoBuy },
		"	> -" => { -name => "separator" },
		"   > &Party" 	=> "Party",
		"   > &Guild" 	=> "Guild",
		"   > &Friend" 	=> "Friend",
		
		# Settings Menu
		"&Settings" => "Settings",
		"   > Reload &Config" 	=> { -name => "View_Map", -onClick => \&menuReloadConfig },
		"   > Reload &All Config" 	=> { -name => "View_Map", -onClick => \&menuReloadFiles },
		
		# Help Menu
		"&Help" => "Help",
		"	> &Forum				Shift+F1" => { -name => "resume", -onClick => \&menuForumURL },
	    "	> &Wiki					F1" => { -name => "manual", -onClick => \&menuWikiURL },
		"	> &Github" => { -name => "manual", -onClick => \&menuGithubURL },
		"	> -" => { -name => "separator" },
		"	> &Report Issue" => { -name => "manual", -onClick => \&menuGithubIssueURL },
);

	$self->{icon} = new Win32::GUI::Icon('SRC/BUILD/openkore.ICO');
	
	$self->{mw} = new Win32::GUI::Window(
	    -name     => "mw",
	    -title    => "Ragnarok Online Bot Client",
	    -pos      => [308, 220],
	    -size     => [900, 700],
		-minsize   => [450, 350],
	    -icon	=> $self->{icon},
	    -menu     => $self->{Menu},
	    -accel	 => $self->{AccTable},
	    -maximizebox => 1,
	    -resizable => 1,
		-onResize  => \&onResize,
	    -onTerminate => \&onExit,
		);

	$self->{status_bar} = $self->{mw}->AddStatusBar(
		-name => 'SB',
		-SizeGripStyle =>1,
	);
	
	$self->{status_bar}->Parts(225,450,680);

	$self->{mw}->ChangeIcon($self->{icon});

	# create the systray icon.
	$self->{systray_icon} = $self->{mw}->AddNotifyIcon( -name => "Systray",
		-id   => 1,
		-icon => $self->{icon},
		-tip  => 'OpenKore',
		-onClick => \&tray_Click,
	);

	$self->{name} = $self->{mw}->AddLabel(
	       -text    => "Name",
	       -name    => "name",
	       -left    => 4,
	       -top     => 2, #2,
	       -width   => 115,
	       -height  => 13,
	       -foreground    => 0,
	    );
	
	$self->{class} = $self->{mw}->AddLabel(
	       -text    => "Job",
	       -name    => "class",
	       -left    => 4,
	       -top     => 17, #16,
	       -width   => 100,
	       -height  => 13,
	       -foreground    => 0,
	      );
	
	$self->{gender} = $self->{mw}->AddLabel(
	       -text    => "Gender",
	       -name    => "gender",
	       -left    => 4,
	       -top     => 31, #30,
	       -width   => 40,
	       -height  => 13,
	       -foreground    => 0,
	      );
	
	$self->{weight} = $self->{mw}->AddLabel(
	       -text    => "Weight: 0/0",
	       -name    => "weight",
	       -left    => 4,
	       -top     => 44, #30,
	       -width   => 115,
	       -height  => 13,
	       -foreground    => 0,
	      );
	
	$self->{hp_bar} = $self->{mw}->AddProgressBar(
	       -text    => "",
	       -name    => "hp_bar",
	       -left    => 140,
	       -top     => 4, #4,
	       -width   => 185,
	       -height  => 10,
	       -smooth   => 1,
	      );
	
	$self->{mw}->AddLabel(
	       -text    => "HP",
	       -name    => "hp_label",
	       -left    => 120,
	       -top     => 17, #17,
	       -width   => 15,
	       -height  => 13,
	       -foreground    => 0,
	      );
	
	$self->{sp_bar} = $self->{mw}->AddProgressBar(
	       -text    => "",
	       -name    => "sp_bar",
	       -left    => 140,
	       -top     => 32, #32,
	       -width   => 185,
	       -height  => 10,
	       -smooth   => 1,
	      );
	
	$self->{mw}->AddLabel(
	       -text    => "SP",
	       -name    => "sp_label",
	       -left    => 120,
	       -top     => 45, #45,
	       -width   => 14,
	       -height  => 13,
	       -foreground    => 0,
	      );
	
	$self->{hp_val} = $self->{mw}->AddLabel(
	       -text    => "0 / 0",
	       -name    => "hp_val",
	       -left    => 140,
	       -top     => 17, #17,
	       -width   => 185,
	       -height  => 13,
	       -align    => "center",
	       -foreground    => 0,
	      );
	
	$self->{sp_val} = $self->{mw}->AddLabel(
	       -text    => "0 / 0",
	       -name    => "sp_val",
	       -left    => 140,
	       -top     => 45, #45,
	       -width   => 185,
	       -height  => 13,
	       -align    => "center",
	       -foreground    => 0,
	      );
	
	$self->{mw}->AddLabel(
	       -text    => "Base Lv.",
	       -name    => "b_label",
	       -left    => 7,
	       -top     => 70, #70,
	       -width   => 45,
	       -height  => 13,
	       -foreground    => 0,
	      );
	
	$self->{base} = $self->{mw}->AddLabel(
	       -text    => "1",
	       -name    => "base",
	       -left    => 50,
	       -top     => 70, #70,
	       -width   => 20,
	       -height  => 20,
	       -foreground    => 0,
	      );
	
	$self->{b_bar} = $self->{mw}->AddProgressBar(
	       -text    => "",
	       -name    => "b_bar",
	       -left    => 70,
	       -top     => 73, #73,
	       -width   => 235,
	       -height  => 10,
	       -smooth   => 1,
	      );
	
	$self->{b_percent} = $self->{mw}->AddLabel(
	       -text    => "0%",
	       -name    => "b_percent",
	       -left    => 307,
	       -top     => 70, #70,
	       -width   => 28,
	       -height  => 13,
	       -foreground    => 0,
	      );
	
	$self->{mw}->AddLabel(
	       -text    => "  Job Lv.",
	       -name    => "j_label",
	       -left    => 7,
	       -top     => 85, #85,
	       -width   => 45,
	       -height  => 13,
	       -foreground    => 0,
	      );
	
	$self->{job} = $self->{mw}->AddLabel(
	       -text    => "1",
	       -name    => "job",
	       -left    => 50,
	       -top     => 85, #85,
	       -width   => 20,
	       -height  => 13,
	       -foreground    => 0,
	      );
	
	$self->{j_bar} = $self->{mw}->AddProgressBar(
	       -text    => "",
	       -name    => "j_bar",
	       -left    => 70,
	       -top     => 88, #88,
	       -width   => 235,
	       -height  => 10,
	       -smooth   => 1,
	      );
	
	$self->{j_percent} = $self->{mw}->AddLabel(
	       -text    => "0%",
	       -name    => "j_percent",
	       -left    => 307,
	       -top     => 85, #85,
	       -width   => 28,
	       -height  => 13,
	       -foreground    => 0,
	      );
	
	$self->{mw}->AddButton(
	       -text    => "Exp",
	       -name    => "exp_group",
	       -left    => 4,
	       -top     => 58, #58,
	       -width   => 335,
	       -height  => 48,
	       -style   => WS_CHILD | WS_VISIBLE | 7,  # GroupBox
	       -align    => "center",
	      );
	
	$self->{mw}->AddLabel(
	       -text    => "Status:",
	       -name    => "status_label",
	       -left    => 4,
	       -top     => 108, #108,
	       -width   => 32,
	       -height  => 13,
	       -foreground    => 0,
	      );
	
	$self->{status} = $self->{mw}->AddLabel(
	       -text    => "None",
	       -name    => "status",
	       -left    => 40,
	       -top     => 108, #108,
	       -width   => 300,
	       -height  => 13,
	       -foreground    => 0,
	      );
	
	$self->{console} = $self->{mw}->AddRichEdit(
	       -text    => "",
	       -name    => "console",
	       -font	=> $consoleFont,
	       -left    => 4,
	       -top     => 125, #125,
	       -width   => 836,
	       -height  => 460,
           -style   => WS_CHILD | WS_VISIBLE | ES_LEFT
                       | ES_MULTILINE | ES_AUTOVSCROLL | WS_VSCROLL | ES_READONLY,
	      );
	
	$self->{chat} = $self->{mw}->AddRichEdit(
	       -text    => "",
	       -name    => "chat",
		   -font	=> $consoleFont,
	       -left    => 350,
	       -top     => 2, #250,
	       -width   => 490,
	       -height  => 105,
           -style   => WS_CHILD | WS_VISIBLE | ES_LEFT
                       | ES_MULTILINE | ES_AUTOVSCROLL | WS_VSCROLL | ES_READONLY,
	      );
	
	$self->{pm_list} = $self->{mw}->AddCombobox(
	       -text    => "",
	       -name    => "pm_list",
	       -left    => 4,
	       -top     => 585, #325,
	       -width   => 95,
	       -height  => 150,
	       -dropdown => 1,
#	       -style   => WS_VISIBLE | 2,  # Dropdown Style
	      );
	
	$self->{input} = $self->{mw}->AddTextfield(
	       -text    => "",
	       -name    => "input",
	       -left    => 100,
	       -top     => 585, #324,
	       -width   => 657,
	       -height  => 21,
	      );

	$self->{say_type} = $self->{mw}->AddCombobox(
	       -text    => "",
	       -name    => "say_type",
	       -left    => 758,
	       -top     => 585, #325,
	       -width   => 80,
	       -height  => 150,
	       -dropdownlist => 1,
#	       -style   => WS_VISIBLE | 2,  # Dropdown Style
	      );
	$self->{splitter} = $self->{mw}->AddSplitter(
			-name      => 'SP',
			-top       => 0,
			-left      => $self->{mw}->{console}->Width() + 4,
			-height    => $self->{mw}->ScaleHeight() - $self->{mw}->{SB}->Height() - $self->{mw}->{input}->Height(),
			-width     => 3,
			-onRelease => \&splitterRelease,
		);


	$self->{say_type}->Add("Command","Public","Party","Guild");
	$self->{say_type}->Select(0);
	
	$self->{console}->BackColor([0,0,0]);
	$self->{chat}->BackColor([0,0,0]);
	
	$self->{console}->AutoURLDetect(1);
	$self->{chat}->AutoURLDetect(1);
	
	$self->{hp_bar}->SetRange(0,100);
	$self->{sp_bar}->SetRange(0,100);
		
	$self->{b_bar}->SetRange(0,100);
	$self->{j_bar}->SetRange(0,100);
	
	$self->{hp_bar}->SetBarColor([30,100,190]);
	$self->{sp_bar}->SetBarColor([30,100,190]);

	$self->{b_bar}->SetBarColor([30,100,190]);
	$self->{j_bar}->SetBarColor([30,100,190]);
	
	$self->{input}->SetFocus();
	$self->{mw}->Show();
	$self->{mw}->Center;
	
	# Hide console #
	my ($DOS) = Win32::GUI::GetPerlWindow(); 
    Win32::GUI::Hide($DOS);
	################
    
#	Win32::GUI::Dialog();
}

sub inputEnter {
	my $self = shift;
	my ($line,$type);

	$line = $self->{input}->Text;
	$self->{input}->Text("");
	
	$type = $self->{say_type}->Text;
	
	if ($self->{pm_list}->Text eq "") {
		if ($type eq 'Public') {
			$line = 'c '.$line;
		} elsif ($type eq 'Party') {
			$line = 'p '.$line;
		} elsif ($type eq 'Guild') {
			$line = 'g '.$line;
		}
	} else {
		$self->{pm_list}->AddString($self->{pm_list}->Text);
		$line = "pm ".$self->{pm_list}->Text." $line";
	}
	
	return unless defined $line;
	push @input_que, $line;
	push @input_list, $line;	
}

sub addPM {
	my $self = shift;
	my $param = $_[1];
	$self->{pm_list}->AddString($param->{user});
}

sub inputUp {
	my $self = shift;

	my $line;
}

sub inputDown {
	my $self = shift;

}

sub tray_Click {
	my $self = shift;
	$self->Enable();
    $self->Show();
}

sub errorDialog {
	my $self = shift;
	my $msg = shift;

	Win32::GUI::MessageBox(undef, $msg,"Error - ". $Settings::NAME, MB_ICONERROR | MB_OK);
}

sub onResize {
    my $self = shift;
	return if (!defined($self->{SB}));

    my $h = $self->ScaleHeight();
    my $w = $self->ScaleWidth();

    # Move the Status bar
    $self->{SB}->Top($h - $self->{SB}->Height());
    $self->{SB}->Width($w);

	# Move Inputs
	$self->{input}->Top($h - $self->{SB}->Height() - $self->{input}->Height());
	$self->{input}->Width($w - $self->{say_type}->Width() - $self->{pm_list}->Width() - 7);
	$self->{say_type}->Left($self->{input}->Width() + $self->{pm_list}->Width() + 5);
	$self->{say_type}->Top($h - $self->{SB}->Height() - $self->{input}->Height());
	$self->{pm_list}->Top($h - $self->{SB}->Height() - $self->{input}->Height());

    # Adjust Height of console and splitter
    $self->{console}->Height($h - $self->{SB}->Height() - $self->{console}->Top() - $self->{input}->Height());
	$self->{console}->Width($w - 10);
	$self->{chat}->Width($w - $self->{chat}->Left() - 10);
	$self->{SP}->Left($w - 5);
	$self->{SP}->Height($h - $self->{SB}->Height() - $self->{input}->Height()) ;

    return 1;
}

sub onExit {
	my $self = shift;
	if ($conState) {
		push @input_que, "\n";
		$quit = 1;
	}
}

sub splitterRelease {
	return;
}

sub openMap {
	return unless defined $field && defined $field->baseName;
	$map->initMapGUI();
	$map->paintMap();
	$map->paintPlayers();
	$map->paintMonsters();
	$map->paintNPCs();
	$map->paintPos();
}

#######
#
# Menu onClick Handlers
#
#######
sub menuAIAuto {
	AI::state(AI::AUTO);
}

sub menuAIManual {
	AI::state(AI::MANUAL);
}

sub menuAIOff {
	AI::state(AI::OFF);
}

sub menuRespawn {
	Commands::run ("respawn");
}

sub menuCharSelect {
	configModify ('char', undef, 1);
	Commands::run ("charselect");
}

sub menuRelog {
	Commands::run ("relog");
}

sub menuMinimizeToTry {
	my $self = shift;
	$self->Disable();
	$self->Hide();
}

sub menuStatus {
	Commands::run("s"); 
}

sub menuStat {
	Commands::run("st"); 
}

sub menuInventory {
	Commands::run("i");
}

sub menuSkills {
	Commands::run("skills");
}

sub menuPartyInfo {
	Commands::run("party");
}

sub menuEquipWindow {
	Commands::run("eq");
}

sub menuQuestWindow {
	Commands::run("quest list");
}

sub menuFriendList {
	Commands::run("friend");
}

sub menuCart {
	Commands::run("cart");
}

sub menuGuildInfo {
	Commands::run("guild info");
}

sub menuPetInfo {
	Commands::run("pet s");
}

sub menuHomunculusInfo {
	Commands::run("homun s");
}

sub menuMercenaryInfo {
	Commands::run("merc s");
}

sub menuClanInfo {
	Commands::run("clan info");
}

sub menuBank {
	Commands::run("bank open");
}

sub menuRodex {
	Commands::run("rodex open");
	Commands::run("rodex list");
}

sub menuPlayerList {
	Commands::run("pl");
}

sub menuMonsterList {
	Commands::run("ml");
}

sub menuNPCList {
	Commands::run("nl");
}

sub menuExpReport {
	Commands::run("exp");
}

sub menuItemReport {
	Commands::run("exp item");
}

sub menuMonsterReport {
	Commands::run("exp monster");
}

sub menuFullReport {
	Commands::run("exp report");
}

sub menuTeleport {
	Commands::run("tele");
}

sub menuMemo {
	Commands::run("memo");
}

sub menuSit {
	Commands::run("sit");
}

sub menuStand {
	Commands::run("stand");
}

sub menuAutoStore {
	Commands::run("autostorage");
}

sub menuAutoSell {
	Commands::run("autobuy");
}

sub menuAutoBuy {
	Commands::run("autosell");
}

sub menuReloadConfig {
	Commands::run("reload config.txt");
}

sub menuReloadFiles {
	Commands::run("reload all");
}

sub menuForumURL {
	my $url;
	if ($config{'forumURL'}) {
		$url = $config{'forumURL'};
	} else {
		$url = 'http://forums.openkore.com';
	}
	launchURL($url);
}

sub menuWikiURL {
	my $url;
	if ($config{'manualURL'}) {
		$url = $config{'manualURL'};
	} else {
		$url = 'http://wiki.openkore.com/index.php?title=Manual';
	}
	launchURL($url);
}

sub menuGithubURL {
	my $url;
	if ($config{'githubURL'}) {
		$url = $config{'githubURL'};
	} else {
		$url = 'https://github.com/OpenKore/openkore/';
	}
	launchURL($url);
}

sub menuGithubIssueURL {
	my $self = shift;
	my $url;
	if ($config{'githubIssueURL'}) {
		$url = $config{'githubIssueURL'};
	} else {
		$url = 'https://github.com/OpenKore/openkore/issues/new';
	}
	launchURL($url);
}

sub updateStatusBar {
	my $self = shift;
	my ($old_statText, $old_xyText, $old_aiText) = ($statText, $xyText, $aiText);
	if (!$conState) {
		$statText = "Initializing...";
	} elsif ($conState == 1) {
		$statText = "Not connected";
	} elsif ($conState > 1 && $conState < 5) {
		$statText = "Connecting...";
	} else {
		$statText = "Connected.";
	}
	
	if (defined $conState && $conState == 5) {
		if(defined $char && defined $char->{pos}{x}) {
			$xyText = $field->baseName . " $char->{pos}{x}, $char->{pos}{y}";
		}

		if (AI::state) {
			if (@ai_seq) {
				my @seqs = @ai_seq;
				foreach (@seqs) {
					s/^route_//;
					s/_/ /g;
					s/([a-z])([A-Z])/$1 $2/g;
					$_ = lc $_;
				}
				substr($seqs[0], 0, 1) = uc substr($seqs[0], 0, 1);
				$aiText = join(', ', @seqs);
			} else {
				$aiText = "";
			}
		} else {
			$aiText = T("Paused");
		}
	}

	$self->{status_bar}->PartText(0, $statText, 0) unless ($old_statText eq $statText);
	$self->{status_bar}->PartText(1, $xyText, 0) unless ($old_xyText eq $xyText);
	$self->{status_bar}->PartText(2, $aiText, 0) unless ($old_aiText eq $aiText);
}

sub UpdateCharacter {
	my $self = shift;
	return if (!$char || !$char->{'hp_max'} || !$char->{'sp_max'} || !$char->{'weight_max'});
	return if (defined $currentHP && $currentStatus eq $char->statusesString && $char->{'hp'} == $currentHP && $char->{'sp'} == $currentSP && $char->{'exp'} == $currentLvl && $char->{'exp_job'} == $currentJob);

	$self->{name}->Text($char->{'name'});
	$self->{gender}->Text($sex_lut{$char->{'sex'}});
	$self->{class}->Text($jobs_lut{$char->{'jobID'}});
	$self->{status}->Text($char->statusesString);

	$self->{weight}->Text("Weight: $char->{'weight'} / $char->{'weight_max'}");

	$self->{base}->Text($char->{'lv'});
	$self->{job}->Text($char->{'lv_job'});
	
	my $percent_hp = sprintf("%i", $char->{'hp'} * 100 / $char->{'hp_max'});	
	my $percent_sp = sprintf("%i", $char->{'sp'} * 100 / $char->{'sp_max'});

	$self->{hp_bar}->SetPos($percent_hp);
	$self->{sp_bar}->SetPos($percent_sp);
	
	$self->{hp_val}->Text("$char->{'hp'} / $char->{'hp_max'} ($percent_hp %)");
	$self->{sp_val}->Text("$char->{'sp'} / $char->{'sp_max'} ($percent_sp %)");
	
	if ($percent_hp < 20) {
		$self->{hp_bar}->SetBarColor([255,89,89]);
		$self->{hp_val}->Change(-foreground =>[255,89,89]);
	} elsif ($percent_hp < 50) {
		$self->{hp_bar}->SetBarColor([223,223,0]);
		$self->{hp_val}->Change(-foreground =>[223,223,0]);
	} else {
		$self->{hp_bar}->SetBarColor([30,100,190]);
		$self->{hp_val}->Change(-foreground =>[30,100,190]);
	}

	$self->{hp_val}->Redraw(1);

	if ($percent_sp < 20) {
		$self->{sp_bar}->SetBarColor([255,89,89]);
		$self->{sp_val}->Change(-foreground =>[255,89,89]);
	} elsif ($percent_sp < 50) {
		$self->{sp_bar}->SetBarColor([223,223,0]);
		$self->{sp_val}->Change(-foreground =>[223,223,0]);
	} else {
		$self->{sp_bar}->SetBarColor([30,100,190]);
		$self->{sp_val}->Change(-foreground =>[30,100,190]);
	}
	$self->{sp_val}->Redraw(1);

	my $percent_base_lv;

	if (!$char->{'exp_max'}) {
		$percent_base_lv = 0;
	} else {
		$percent_base_lv = sprintf("%i", $char->{'exp'} * 100 / $char->{'exp_max'});
	}
	$self->{b_bar}->SetPos($percent_base_lv);	
	$self->{b_percent}->Text($percent_base_lv."%");
	
	my $percent_job_lv;

	if (!$char->{'exp_job_max'}) {
		$percent_job_lv = 0;
	} else {
		$percent_job_lv = sprintf("%i", $char->{'exp_job'} * 100 / $char->{'exp_job_max'});
	}
	$self->{j_bar}->SetPos($percent_job_lv);
	$self->{j_percent}->Text($percent_job_lv."%");
	
	$currentHP = $char->{'hp'};
	$currentSP = $char->{'sp'};
	$currentLvl = $char->{'exp'};
	$currentJob = $char->{'exp_job'};
	$currentStatus = $char->statusesString;
}

%fgcolors = (
	'reset'		=> [192,192,192],
	'default'	=> [192,192,192],

	'black'		=> [0,0,0],
	'darkgray'	=> [175,175,175],
	'darkgrey'	=> [175,175,175],

	'darkred'	=> [180,0,0],
	'red'		=> [255,0,0],

	'darkgreen'	=> [0,180,0],
	'green'		=> [0,255,0],

	'brown'		=> [128,0,0],
	'yellow'	=> [255,255,0],
	
	'darkblue'	=> [0,0,180],
	'blue'		=> [0,0,255],

	'darkmagenta'	=> [180,0,180],
	'magenta'		=> [255,0,255],
	
	'darkcyan'	=> [0,180,180],
	'cyan'		=> [0,255,255],

	'gray'		=> [192,192,192],
	'grey'		=> [192,192,192],
	'white'		=> [192,192,192],
);


1;
