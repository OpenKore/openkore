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

use Win32::GUI();
use Interface::Win32::Map; #Map Viewer


our ($currentHP, $currentSP, $currentLvl, $currentJob, $currentStatus);
our $map;

our @input_que;
our @input_list;

our %fgcolors;
our %bgcolors;

our $line_limit_chat = 500; #chat window line limit
our $line_limit_console = 500; #console window line limit

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
	
	$fgcode = $fgcolors{$color} || $fgcolors{'default'};
	
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
    $self->UpdateCharacter();
	if ($map->mapIsShown()) {
		$map->Repaint();
		$map->paintMiscPos();		
		$map->paintPos();
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
	
	my $nameFont = Win32::GUI::Font->new( -name => "Verdana",-size => 10, -bold =>1);
	my $consoleFont = Win32::GUI::Font->new( -name => "Verdana",-size => 7,);

	$self->{AccTable} = new Win32::GUI::AcceleratorTable (
	 				  "Return" 		=> \&inputEnter,
	 				  "Up" 		=> \&inputUp,
	 				  "Down" 		=> \&inputDown,
 				      "Ctrl-X" 		=> \&onExit,
 				      "Tab" 		=> sub { $self->{input}->SetFocus(); },
					"Alt+V"		=> \&comstatus,
					"Alt+A"		=> \&comstat,
					"Alt+I"		=> \&comitems,
					"Alt+S"		=> \&comskills,
					"Alt+E"		=> \&comstatus,
 				      );

	$self->{Menu} = Win32::GUI::MakeMenu (
	    "Open&Kore" => "Kore",
	    "   > &Pause" => { -name => "pause", -onClick => \&compause },
	    "	  > &Manual" => { -name => "manual", -onClick => \&commanual },
	    "	  > &Resume" => { -name => "resume", -onClick => \&comresume },
	    "   > E&xit" 	=> { -name => "Kore_Exit", -onClick => \&onExit },
	    "&View" => "View",
	    "   > View &Map" 	=> { -name => "View_Map", -onClick => \&openMap },
	    "&Info" => "Info",
	    "	  > &Status		Alt+V"	=> { -name => "Status", -onClick => \&comstatus },
	    "   > S&tatistics	Alt+A"	=> { -name => "Statistics", -onClick => \&comstat },
	    "	  > &Inventory	Alt+I"	=> { -name => "Inventory", -onClick => \&comitems },
	    "   > S&kills		Alt+S"	=> { -name => "Skills", -onClick => \&comskills },
	    "   > &Experience	Alt+E"	=> { -name => "Experience", -onClick => \&comerooo },
	    
);

	$self->{icon} = new Win32::GUI::Icon('SRC/BUILD/openkore.ICO');
	
	$self->{mw} = new Win32::GUI::Window(
	    -name     => "mw",
	    -title    => "Ragnarok Online Bot Client",
	    -pos      => [308, 220],
	    -size     => [950, 690],
	    -icon	=> $self->{icon},
	    -menu     => $self->{Menu},
	    -accel	 => $self->{AccTable},
	    -maximizebox => 1,
	    -resizable => 0,
		-onMinimize => \&OnMinimize,
	    -onTerminate => \&onExit, 
		);
		
	$self->{mw}->ChangeIcon($self->{icon});

	# create the systray icon.
	$self->{systray_icon} = $self->{mw}->AddNotifyIcon( -name => "Systray",
		-id   => 1,
		-icon => $self->{icon},
		-tip  => 'OpenKore',
		-onClick => \&tray_Click,
	);

	$self->{name} = $self->{mw}->AddLabel(
	       -text    => "name",
	       -name    => "name",
	       -font	=> $nameFont,
	       -left    => 4,
	       -top     => 102, #2,
	       -width   => 100,
	       -height  => 13,
	       -foreground    => 0,
	    );
	
	$self->{class} = $self->{mw}->AddLabel(
	       -text    => "job",
	       -name    => "class",
	       -left    => 4,
	       -top     => 116, #16,
	       -width   => 100,
	       -height  => 13,
	       -foreground    => 0,
	      );
	
	$self->{gender} = $self->{mw}->AddLabel(
	       -text    => "gender",
	       -name    => "gender",
	       -left    => 4,
	       -top     => 130, #30,
	       -width   => 40,
	       -height  => 13,
	       -foreground    => 0,
	      );
	
	$self->{hp_bar} = $self->{mw}->AddProgressBar(
	       -text    => "",
	       -name    => "hp_bar",
	       -left    => 140,
	       -top     => 104, #4,
	       -width   => 185,
	       -height  => 10,
	       -smooth   => 1,
	      );
	
	$self->{mw}->AddLabel(
	       -text    => "HP",
	       -name    => "hp_label",
	       -left    => 120,
	       -top     => 117, #17,
	       -width   => 15,
	       -height  => 13,
	       -foreground    => 0,
	      );
	
	$self->{sp_bar} = $self->{mw}->AddProgressBar(
	       -text    => "",
	       -name    => "sp_bar",
	       -left    => 140,
	       -top     => 132, #32,
	       -width   => 185,
	       -height  => 10,
	       -smooth   => 1,
	      );
	
	$self->{mw}->AddLabel(
	       -text    => "SP",
	       -name    => "sp_label",
	       -left    => 120,
	       -top     => 145, #45,
	       -width   => 14,
	       -height  => 13,
	       -foreground    => 0,
	      );
	
	$self->{hp_val} = $self->{mw}->AddLabel(
	       -text    => "0 / 0",
	       -name    => "hp_val",
	       -left    => 140,
	       -top     => 117, #17,
	       -width   => 185,
	       -height  => 13,
	       -align    => "center",
	       -foreground    => 0,
	      );
	
	$self->{sp_val} = $self->{mw}->AddLabel(
	       -text    => "0 / 0",
	       -name    => "sp_val",
	       -left    => 140,
	       -top     => 145, #45,
	       -width   => 185,
	       -height  => 13,
	       -align    => "center",
	       -foreground    => 0,
	      );
	
	$self->{mw}->AddLabel(
	       -text    => "Base Lv.",
	       -name    => "b_label",
	       -left    => 7,
	       -top     => 170, #70,
	       -width   => 45,
	       -height  => 13,
	       -foreground    => 0,
	      );
	
	$self->{base} = $self->{mw}->AddLabel(
	       -text    => "1",
	       -name    => "base",
	       -left    => 50,
	       -top     => 170, #70,
	       -width   => 20,
	       -height  => 20,
	       -foreground    => 0,
	      );
	
	$self->{b_bar} = $self->{mw}->AddProgressBar(
	       -text    => "",
	       -name    => "b_bar",
	       -left    => 70,
	       -top     => 173, #73,
	       -width   => 235,
	       -height  => 10,
	       -smooth   => 1,
	      );
	
	$self->{b_percent} = $self->{mw}->AddLabel(
	       -text    => "0%",
	       -name    => "b_percent",
	       -left    => 307,
	       -top     => 170, #70,
	       -width   => 28,
	       -height  => 13,
	       -foreground    => 0,
	      );
	
	$self->{mw}->AddLabel(
	       -text    => "  Job Lv.",
	       -name    => "j_label",
	       -left    => 7,
	       -top     => 185, #85,
	       -width   => 45,
	       -height  => 13,
	       -foreground    => 0,
	      );
	
	$self->{job} = $self->{mw}->AddLabel(
	       -text    => "1",
	       -name    => "job",
	       -left    => 50,
	       -top     => 185, #85,
	       -width   => 20,
	       -height  => 13,
	       -foreground    => 0,
	      );
	
	$self->{j_bar} = $self->{mw}->AddProgressBar(
	       -text    => "",
	       -name    => "j_bar",
	       -left    => 70,
	       -top     => 188, #88,
	       -width   => 235,
	       -height  => 10,
	       -smooth   => 1,
	      );
	
	$self->{j_percent} = $self->{mw}->AddLabel(
	       -text    => "0%",
	       -name    => "j_percent",
	       -left    => 307,
	       -top     => 185, #85,
	       -width   => 28,
	       -height  => 13,
	       -foreground    => 0,
	      );
	
	$self->{mw}->AddButton(
	       -text    => "Exp",
	       -name    => "exp_group",
	       -left    => 4,
	       -top     => 158, #58,
	       -width   => 335,
	       -height  => 48,
	       -style   => WS_CHILD | WS_VISIBLE | 7,  # GroupBox
	       -align    => "center",
	      );
	
	$self->{mw}->AddLabel(
	       -text    => "Status:",
	       -name    => "status_label",
	       -left    => 4,
	       -top     => 208, #108,
	       -width   => 32,
	       -height  => 13,
	       -foreground    => 0,
	      );
	
	$self->{status} = $self->{mw}->AddLabel(
	       -text    => "None",
	       -name    => "status",
	       -left    => 40,
	       -top     => 208, #108,
	       -width   => 300,
	       -height  => 13,
	       -foreground    => 0,
	      );
	
	$self->{console} = $self->{mw}->AddRichEdit(
	       -text    => "",
	       -name    => "console",
	       -font	=> $consoleFont,
	       -left    => 4,
	       -top     => 225, #125,
	       -width   => 419,
	       -height  => 361,
           -style   => WS_CHILD | WS_VISIBLE | ES_LEFT
                       | ES_MULTILINE | ES_AUTOVSCROLL | WS_VSCROLL | ES_READONLY,
	      );
	
	$self->{chat} = $self->{mw}->AddRichEdit(
	       -text    => "",
	       -name    => "chat",
	       -left    => 428,
	       -top     => 5, #250,
	       -width   => 419,
	       -height  => 591,
           -style   => WS_CHILD | WS_VISIBLE | ES_LEFT
                       | ES_MULTILINE | ES_AUTOVSCROLL | WS_VSCROLL | ES_READONLY,
	      );
	
	$self->{pm_list} = $self->{mw}->AddCombobox(
	       -text    => "",
	       -name    => "pm_list",
	       -left    => 417,
	       -top     => 596, #325,
	       -width   => 95,
	       -height  => 80,
	       -dropdown => 1,
#	       -style   => WS_VISIBLE | 2,  # Dropdown Style
	      );
	
	$self->{input} = $self->{mw}->AddTextfield(
	       -text    => "",
	       -name    => "input",
	       -left    => 512,
	       -top     => 596, #324,
	       -width   => 245,
	       -height  => 23,
	      );

	$self->{say_type} = $self->{mw}->AddCombobox(
	       -text    => "",
	       -name    => "say_type",
	       -left    => 758,
	       -top     => 596, #325,
	       -width   => 80,
	       -height  => 80,
	       -dropdownlist => 1,
#	       -style   => WS_VISIBLE | 2,  # Dropdown Style
	      );

	$self->{mw}->AddButton(
	       -text    => "View Map",
	       -name    => "btn_map",
	       -left    => 353,
	       -top     => 5,
	       -width   => 63,
	       -height  => 50,
	       -foreground => 0,
	       -onClick => \&openMap,
	      );
	$self->{mw}->AddButton(
	       -text    => "Sit",
	       -name    => "sit command",
	       -left    => 4,
	       -top     => 5,
	       -width   => 50,
	       -height  => 20,
	       -foreground => 0,
	       -onClick => sub { Commands::run("sit"); },
	      );
	
	$self->{mw}->AddButton(
	       -text    => "complete report",
	       -name    => "Report",
	       -left    => 60,
	       -top     => 5,
	       -width   => 100,
	       -height  => 20,
	       -foreground => 0,
	       -onClick => sub { Commands::run("exp report"); },
	      );







#
	
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

sub OnMinimize {
	my $self = shift;
	$self->Disable();
	$self->Hide();
}

sub tray_Click {
	my $self = shift;
	$self->Enable();
    $self->Show();
}

sub errorDialog {
	my $self = shift;
	my $msg = shift;
	Win32::GUI::MessageBox($msg,"Error",MB_ICONERROR | MB_OK,);
}

sub onExit {
	my $self = shift;
	if ($conState) {
		push @input_que, "\n";
		$quit = 1;
	}
}

sub openMap {

		$map->initMapGUI();
		$map->paintMap();
		$map->paintMiscPos();		
		$map->paintPos();
	}

sub compause {
	$AI = 0;
}
sub commanual {
	$AI = 1;
}
sub comresume {
	$AI = 2;
}
sub comstatus {
Commands::run("s"); 
}
sub comstat {
Commands::run("st"); 
}
sub comitems {
Commands::run("i");
}
sub comskills {
Commands::run("skills");
}
sub comerooo {
Commands::run("exp");
}


sub UpdateCharacter {
	my $self = shift;
	return if (!$char || !$char->{'hp_max'} || !$char->{'sp_max'} || !$char->{'weight_max'});
	return if ($currentStatus eq $char->statusesString && $char->{'hp'} == $currentHP && $char->{'sp'} == $currentSP && $char->{'exp'} == $currentLvl && $char->{'exp_job'} == $currentJob);

	$self->{name}->Text($char->{'name'});
	$self->{gender}->Text($sex_lut{$char->{'sex'}});
	$self->{class}->Text($jobs_lut{$char->{'jobID'}});
	$self->{status}->Text($char->statusesString);
	
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
	} elsif ($percent_hp < 50) {
		$self->{hp_bar}->SetBarColor([223,223,0]);
	} else {
		$self->{hp_bar}->SetBarColor([30,100,190]);
	}

	if ($percent_sp < 20) {
		$self->{sp_bar}->SetBarColor([255,89,89]);
	} elsif ($percent_sp < 50) {
		$self->{sp_bar}->SetBarColor([223,223,0]);
	} else {
		$self->{sp_bar}->SetBarColor([30,100,190]);
	}
		
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

