package webMonitorServer;

# webMonitor - an HTTP interface to monitor bots
# Copyright (C) 2006 kaliwanagan
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#############################################

# webMonitorV2 - Web interface to monitor yor bots
# Copyright (C) 2012 BonScott
# thanks to iMikeLance
#
# ------------------------------
# How use:
# Add in your config.txt
#
# webPort XXXX
# 
# Where XXXX is a number of your choice. Ex:
# webPort 1020
#
# If webPort not defined in config, the default port is 1025
# ------------------------------
# Set only one port for each bot. For more details, visit:
# [OpenKoreBR]
#	http://openkore.com.br/index.php?/topic/3189-webmonitor-v2-by-bonscott/
# [OpenKore International]
#	http://forums.openkore.com/viewtopic.php?f=34&t=18264
#############################################

use strict;
use Base::WebServer;
use base qw(Base::WebServer);
use Translation qw(T TF);
use Globals;
use Log qw(message debug);
use Utils;
use Log;
use Commands;
use template;
use Skill;
use Settings;
use Network;
use Network::Send ();
use POSIX qw/strftime/;

BEGIN {
	eval {
		require Math::Random::Secure;
		Math::Random::Secure->import('rand');
	};

	eval {
		require HTML::Entities;
		HTML::Entities->import('encode_entities');
	};
	if ($@) {
		*encode_entities = sub { '' };
	}

	eval {
		require File::ReadBackwards;
	};
}

# TODO use real templating system?
my %templates;

# Keywords are specific fields in the template that will eventually get
# replaced by dynamic content.
my %keywords;

my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
$mon++; $year += 1900; 
my $time = strftime('%H:%M:%S', localtime);
###
# cHook
#
# This sub hooks into the Log module of OpenKore in order to store console
# messages into a FIFO array @messages. Many thanks to PlayingSafe, from whom
# most of the code was derived from.
my @messages;
my $cHook = Log::addHook(\&cHook, "Console Log");
my $hookShopList = Plugins::addHook('packet_vender_store', \&hookShopList);

# CSRF prevention token
my $csrf = int rand 2**32;

sub new {
	my $class = shift;

	my $self = $class->SUPER::new(@_);
	message TF("webMonitor started at http://%s:%s/\n", $self->getHost, $self->getPort), 'connection';
	$self
}

sub checkCSRF {
	my ($self, $process) = @_;

	my $ret = $process->{GET}{csrf} eq $csrf;
	unless ($ret) {
		$process->status(403 => 'Forbidden');
		$process->header('Content-Type' => 'text/html');
		$process->shortResponse('<h1>Forbidden</h1>');
	}
	$ret
}

sub cHook {
	my ($type, $domain, $level, $currentVerbosity, $message, $data) = @_;

	if ($level <= $currentVerbosity) {
		push @messages, {type => $type, domain => $domain, level => $level, message => $message};

		# Make sure we don't let @messages grow too large
		# TODO: make the message size configurable
		while (@messages > 40) {
			splice @messages, 0, -20
		}
	}
}

sub messageClass {
	my ($type, $domain) = @_;
	return unless $type =~ /^\w+$/ && $domain =~ /^\w+$/;
	$domain = 'default' unless $consoleColors{$type}{$domain};
	'msg_' . $type . '_' . $domain
}

sub consoleColorsCSS {
	my $css;

	for my $type (keys %consoleColors) {
		for my $domain (keys %{$consoleColors{$type}}) {
			next unless $type =~ /^\w+$/ && $domain =~ /^\w+$/;
			my $color = $consoleColors{$type}{$domain};
			$css .= ".msg_${type}_${domain} { color: ${consoleColors{$type}{$domain}}; }\n"
		}
	}

	$css
}

sub consoleLogHTML {
	my @parts;

	defined &HTML::Entities::encode
	or return '<span class="msg_web"><a href="http://search.cpan.org/perldoc?HTML::Entities">HTML::Entities</a> is required to display console log.' . "\n" . '</span>';

	for (@messages) {
		my $domain = $consoleColors{$_->{type}}{$_->{domain}} ? $_->{domain} : 'default';
		my $class = messageClass($_->{type}, $_->{domain});
		$class = ' class="' . $class . '"' if $class;

		push @parts, '<span' . $class . '>' . encode_entities($_->{message}) . '</span>';
	}

	push @parts, '<noscript><span class="msg_web">Reload to get new messages.</span></noscript>';

	local $";
	"@parts"
}

# TODO merge with chist command somehow, new API?
# TODO chat_log_file's contents are formatted and look different
sub chatLogHTML {
	my @parts;

	my $bw = eval { File::ReadBackwards->new($Settings::chat_log_file) }
	or return do {
		if ($@ =~ 'perhaps you forgot to load "File::ReadBackwards"' || $@ =~ 'Can\'t locate object method "new" via package "File::ReadBackwards"') {
			'<span class="msg_web"><a href="http://search.cpan.org/perldoc?File::ReadBackwards">File::ReadBackwards</a> is required to retrieve chat log.' . "\n" . '</span>'
		} else {
			'<span class="msg_error_default">Error while retrieving file \'' . $Settings::chat_log_file . '\' chat log:' . "\n" . encode_entities($@) . '</span>'
		}
	};

	defined &HTML::Entities::encode
	or return '<span class="msg_web"><a href="http://search.cpan.org/perldoc?HTML::Entities">HTML::Entities</a> is required to display chat log.' . "\n" . '</span>';

	while (defined(my $line = $bw->readline)) {
		push @parts, encode_entities($line);
		# TODO: make the message size configurable
		last if @parts > 20;
	}
	@parts = reverse @parts;

	push @parts, '<noscript><span class="msg_web">Reload to get new messages.</span></noscript>';

	local $";
	"@parts"
}

# "hookShopList" is used on tab "Shop".
my ($shopNumber, @price, @number, @listName, @listAmount, @upgrade, @cards, @type, @id, @shopJS);
sub hookShopList {
	my ($packet, $args) = @_;
	push (@price, formatNumber($args->{price}));
	push (@listName, $args->{name});
	push (@number, $args->{number});
	push (@listAmount, $args->{amount});
	push (@upgrade, $args->{upgrade});
	push (@cards, $args->{cards});
	push (@type, $args->{type});
	push (@id, $args->{nameID});
	
	if ($args->{price} < $char->{'zeny'}){
		push (@shopJS, '<a class="btn btn-mini btn-success"  href="/handler?csrf=' . $csrf . '&command=buy+' . $shopNumber . ' , ' . $args->{number} . ')">Buy</a>');
	} else {
		push (@shopJS, '');
	}
}

###
# $webMonitorServer->request
#
# This virtual method will be called every time a web browser requests a page
# from this web server. We override this method so we can respond to requests.
sub request {
	my ($self, $process) = @_;
	my $content = '';
	
	# We then inspect the headers the client sent us to see if there are any
	# resources that was sent
	my %resources = %{$process->{GET}};
	
	# TODO: sanitize $filename for possible exploits (like ../../config.txt)
	my $filename = $process->file;

	# map / to /index.html
	$filename .= 'index.html' if ($filename =~ /\/$/);
	# alias the newbie maps to new_zone01
	$filename =~ s/new_.../new_zone01/;

	my $csrf_pass = $resources{csrf} eq $csrf;

# Collect data for the tab Report
	# Experience
	my ($endTime_EXP, $w_sec, $bExpPerHour, $jExpPerHour, $EstB_sec, $zenyMade, $zenyPerHour, $EstJ_sec);
	my (@reportMonsterID, @reportMonsterName, @reportMonsterCount);
	my (@reportItemID, @reportItemName, @reportItemCount);
	$endTime_EXP = time;
	$w_sec = int($endTime_EXP - $startTime_EXP);
	
	if ($w_sec > 0) {
		$zenyMade = $char->{zeny} - $startingzeny;
		$bExpPerHour = int($totalBaseExp / $w_sec * 3600);
		$jExpPerHour = int($totalJobExp / $w_sec * 3600);
		$zenyPerHour = int($zenyMade / $w_sec * 3600);
		
		if ($char->{exp_max} && $bExpPerHour) {
		$EstB_sec = int(($char->{exp_max} - $char->{exp})/($bExpPerHour/3600));
		}
	
		if ($char->{exp_job_max} && $jExpPerHour) {
		$EstJ_sec = int(($char->{'exp_job_max'} - $char->{exp_job})/($jExpPerHour/3600));
		}
	}
	# Monster
	for (my $i = 0; $i < @monsters_Killed; $i++) {
		next if ($monsters_Killed[$i] eq "");
		push (@reportMonsterID, $monsters_Killed[$i]{nameID});
		push (@reportMonsterName, $monsters_Killed[$i]{name});
		push (@reportMonsterCount, $monsters_Killed[$i]{count});
	}
	# Itens
	for my $item (sort keys %itemChange) {
		next unless $itemChange{$item};
		push (@reportItemID, $item); #Bugfix: Is there something equivalent to a items_rlut?
		push (@reportItemName, $item);
		push (@reportItemCount, $itemChange{$item});
	}

# Show inventory
	my (@unusable, @usable, @equipment, @uequipment);
	my (@unusableAmount, @usableAmount);
	my (@unusableJS, @usableJS, @equipmentJS, @uequipmentJS);
	my (@unusableID, @usableID, @equipmentID, @uequipmentID);
	my $Item_IDN;
	for (my $i; $i < @{$char->inventory->getItems()}; $i++) {
		my $item = $char->inventory->getItems()->[$i];
		next unless $item && %{$item};
		if (($item->{type} == 3 || $item->{type} == 6 ||
			$item->{type} == 10) && !$item->{equipped})
		{
			push @unusableID, $item->{nameID};
			push @unusable, $item->{name};
			push @unusableAmount, $item->{amount};
			push @unusableJS, '<td><a class="btn btn-mini btn-danger" href="/handler?csrf=' . $csrf . '&command=drop+' . $item->{invIndex} . '">' . T('Drop 1') . '</a></td>';
		} elsif ($item->{type} <= 2) {
			push @usableID, $item->{nameID};
			push @usable, $item->{name};
			push @usableAmount, $item->{amount};
			push @usableJS, '<td><a class="btn btn-mini btn-success" href="/handler?csrf=' . $csrf . '&command=is+' . $item->{invIndex} . '">' . T('Use 1 on self') . '</a></td><td><a class="btn btn-mini btn-danger" href="/handler?csrf=' . $csrf . '&command=drop+' . $item->{invIndex} . '">' . T('Drop 1') . '</a></td>';
		} else {
			if ($item->{equipped}) {
				push @equipmentID, $item->{nameID};
				push @equipment, $item->{name};
				push @equipmentJS, '<td><a class="btn btn-mini btn-inverse" href="/handler?csrf=' . $csrf . '&command=uneq+' . $item->{invIndex} . '">' . T('Unequip') . '</a></td><td></td>';
			} else {
				push @uequipmentID, $item->{nameID};
				push @uequipment, $item->{name};
				push @uequipmentJS, '<td><a class="btn btn-mini btn-inverse" href="/handler?csrf=' . $csrf . '&command=eq+' . $item->{invIndex} . '">' . T('Equip') . '</a></td><td><a class="btn btn-mini btn-danger" href="/handler?csrf=' . $csrf . '&command=drop+' . $item->{invIndex} . '">' . T('Drop 1') . '</a></td>';
			}
		}
	}
	my @statuses = (keys %{$char->{statuses}});

# Show members of the clan
	my ($i, $name, $class, $lvl, $title, $online, $ID, $charID);
	my (@listMemberIndex, @listMemberName, @listMemberClass, @listMemberLvl, @listMemberTitle, @listMemberOnline, @listMemberID, @listMemberCharID);
	
	if (defined @{$guild{member}}) {
		my $count = @{$guild{member}};
			for ($i = 0; $i < $count; $i++) {
				$name  = $guild{member}[$i]{name};
				next if (!defined $name);

				$class   = $jobs_lut{$guild{member}[$i]{jobID}};
				$lvl   = $guild{member}[$i]{lv};
				$title = $guild{member}[$i]{title};
				# Translation Comment: Guild member online
				$online = $guild{member}[$i]{online} ? "<span class='label label-success'>Online</span>" : "<span class='label label-important'>Offline</span>";
				$ID = unpack("V",$guild{member}[$i]{ID});
				$charID = unpack("V",$guild{member}[$i]{charID});

				push @listMemberIndex, $i;
				push @listMemberName, $name;
				push @listMemberClass, $class;
				push @listMemberLvl, $lvl;
				push @listMemberTitle, $title;
				push @listMemberOnline, $online;
				push @listMemberID, $charID;
		}
	}
	
# List player stores (NPC's shops won't be listed!!)
	my (@listComboBox);

	for (my $i = 0; $i < @venderListsID; $i++) {
		next if ($venderListsID[$i] eq "");
		my $player = Actor::get($venderListsID[$i]);
		# autovivifies $obj->{pos_to} but it doesnt matter
		push (@listComboBox, '<option value="' . $i . '">' . $venderLists{$venderListsID[$i]}{'title'} . '</option>');
		#push @shopList, $i . ' ' . $venderLists{$venderListsID[$i]}{'title'} . ' ' . $player->{pos_to}{x} || '?' . ' ' . $player->{pos_to}{y} || '?' . ' ' . $player->name . '<br>'
	}

# Show NPC's
	my (@npcBinID, @npcName, @npcLocX, @npcLocY, @npcNameID, @npcTalk);
	my $npcs = $npcsList->getItems();
		foreach my $npc (@{$npcs}) {
			push @npcNameID, $npc->{binID};
			push @npcLocX, $npc->{pos}{x};
			push @npcLocY, $npc->{pos}{y};
			push @npcName, $npc->name;
			push @npcBinID, $npc->{nameID};
			push @npcTalk, '<a class="btn btn-mini" href="javascript:write_input(\'talk ' . $npc->{binID} . '\')">Talk</a>';
		}

# Show skills
	my (@skillsIDN, @skillsName, @skillsLevel, @skillsJS, @skillsIcoUp);	
	for my $handle (@skillsID) {
		my $skill = new Skill(handle => $handle);
		my $sp = $char->{skills}{$handle}{sp};
		my $IDN = $skill->getIDN();
		my $act = '';

		my $type = $skill->getTargetType();
		if ($char->getSkillLevel($skill) > 0){
			$act = '<td>' . $sp . '</td><td><div align="center">';
			if ($type == Skill::TARGET_PASSIVE){
				$act .= '<a class="btn btn-mini disabled">Passive</a></div></td>'; #Skill passive
			}
			if ($type == Skill::TARGET_SELF || $type == Skill::TARGET_ACTORS || $type == Skill::TARGET_LOCATION){
				$act .= '<a class="btn btn-mini" href="/handler?csrf=' . $csrf . '&command=ss+' . $IDN . '">' . T('Use on self') . '</a> ';
			}
			if ($type == Skill::TARGET_ENEMY){
				$act .= '<a class="btn btn-mini" href="/handler?csrf=' . $csrf . '&command=sm+' . $IDN . '+0">' . T('Use on enemy') . '</a> ';
			}
			if ($type == Skill::TARGET_ACTORS){
				$act .= '<a class="btn btn-mini" href="/handler?csrf=' . $csrf . '&command=sp+' . $IDN . '+0">' . T('Use on actor') . '</a> ';
			} 
			if ($type == Skill::TARGET_LOCATION){
				$act .= '<a class="btn btn-mini" href="/handler?csrf=' . $csrf . '&command=sl+' . $IDN . '+{characterLocationX}+{characterLocationY}">' . T('Use on location') . '</a> ';
			}
			$act .= '</div></td>';
		} else {
			$act = '<td></td><td></td>';
		}
		
		my $ico_up;
		if ($char->{points_skill} > 0 && $char->{skills}{$handle}{up} == 1){
			$ico_up = '<a href="/handler?csrf=' . $csrf . '&command=skills+add+' . $IDN .'" title="' . T('Level up') . '" rel="tooltip"><i class="icon-plus-sign"></i></a> ';
		}
		
		my $title = $skill->getHandle;

		# To finalize, add the elements into the array's
		push @skillsIDN, $IDN;
		push @skillsIcoUp, $ico_up;
		push @skillsName, '<abbr title="' . $title . '">' . $skill->getName() . '</abbr>';
		push @skillsLevel, $char->getSkillLevel($skill);
		push @skillsJS, $act;
	}
	
	my @menu = (
		{ url => '/', title => T('Status'), image => 'icon-user' },
		{ url => '/inventory.html', title => T('Inventory') },
		{ url => '/report.html', title => T('Report'), image => 'icon-tasks' },
		{ url => '/config.html', title => T('Config'), image => 'icon-cog' },
		{ url => '/console.html', title => T('Console') },
		{ url => '/chat.html', title => T('Chat Log'), image => 'icon-comment' },
		{ url => '/guild.html', title => T('Guild') },
		{ url => '/shop.html', title => T('Vender List'), image => 'icon-shopping-cart' },
		{ url => '/npcs.html', title => T('NPC List') },
		{ url => '/skills.html', title => T('Skill List') },
	);

	%keywords =	(
		socketPort => int($webMonitorPlugin::socketServer && $webMonitorPlugin::socketServer->getPort),
		csrf => $csrf,
		menu =>
			'<li class="nav-header">' . T('Menu') . '</li>'
			. (join "\n", map { '<li class="' . ($_->{url} eq $process->file && 'active') . '"><a href="' . $_->{url} . '"><i class="' . ($_->{image} || 'icon-chevron-right') . '"></i> ' . $_->{title} . '</a></li>' } @menu),
	# Logs
		'consoleColors' => consoleColorsCSS,
		'consoleLog' => consoleLogHTML,
		'chatLog' => chatLogHTML,
	# NPC
		'npcBinID' => \@npcBinID, # Never used
		'npcName' => \@npcName,
		'npcLocationX' => \@npcLocX,
		'npcLocationY' => \@npcLocY,
		'npcNameID' => \@npcNameID,
		'npcTalkJS' => \@npcTalk,
	# Inventory
		'inventoryEquipped' => \@equipment,
		'inventoryEquippedJS' => \@equipmentJS,
		'inventoryUnequipped' => \@uequipment,
		'inventoryUnequippedJS' => \@uequipmentJS,
		'inventoryUsable' => \@usable,
		'inventoryUsableAmount' => \@usableAmount,
		'inventoryUsableJS' => \@usableJS,
		'inventoryUnusableAmount' => \@unusableAmount,
		'inventoryUnusable' => \@unusable,
		'inventoryUnusableJS' => \@unusableJS,
		'unusableID' => \@unusableID,
		'usableID' => \@usableID,
		'equipmentID' => \@equipmentID,
		'uequipmentID' => \@uequipmentID,
	# Guild
		'guildLv' => $guild{lv},
		'guildExp' => $guild{exp},
		'guildExpNext' => $guild{exp_next},
		'guildMaster' => $guild{master},
		'guildConnect' => $guild{conMember},
		'guildMember' => $guild{maxMember},
		'guildListMemberIndex' => \@listMemberIndex, # Never used
		'guildListMemberName' => \@listMemberName,
		'guildListMemberClass' => \@listMemberClass,
		'guildListMemberLvl' => \@listMemberLvl,
		'guildListMemberTitle' => \@listMemberTitle,
		'guildListMemberOnline' => \@listMemberOnline,
		'guildListMemberID' => \@listMemberID, # Never used
		'guildListMemberCharID' => \@listMemberCharID, # Never used
	# Shop
		'shopListComboBox' => \@listComboBox,
		'shopName' => \@listName,
		'shopAmount' => \@listAmount,
		'shopPrice' => \@price,
		'shopNumber' => \@number,
		'shopUpgrade' => \@upgrade, # Never used
		'shopCards' => \@cards, # Never used
		'shopType' => \@type, # Never used
		'shopID' => \@id, # Never used
		'shopJS' => \@shopJS,
	# Skills
		'skillsIDN' => \@skillsIDN,
		'skillsIcoUp' => \@skillsIcoUp,
		'skillsName' => \@skillsName,
		'skillsLevel' => \@skillsLevel,
		'skillsJS' => \@skillsJS,
	# Report
		'time' => $time,
		'deathCount' => (exists $char->{deathCount} ? $char->{deathCount} : 0),
		'bottingTime' => timeConvert($w_sec),
		'totalBaseExp' => $totalBaseExp,
		'perHourBaseExp' => $bExpPerHour,
		'levelupBaseEstimation' => timeConvert($EstB_sec),
		'totalJobExp' => $totalJobExp,
		'perHourJobExp' => $jExpPerHour,
		'levelupJobEstimation' => timeConvert($EstJ_sec),
		'zenyMade' => formatNumber($zenyMade),
		'perHourZeny' => $zenyPerHour, # Never used
		'deltaHp' => $char->{deltaHp}, # Never used
		'reportMonsterID' => \@reportMonsterID,
		'reportMonsterName' => \@reportMonsterName,
		'reportMonsterCount' => \@reportMonsterCount,
		'reportItemID' => \@reportItemID,
		'reportItemName' => \@reportItemName,
		'reportItemCount' => \@reportItemCount,
	# Character infos general
		'characterStatuses' => \@statuses, # Never used
		'characterSkillPoints' => $char->{points_skill},
		'characterStatusesSring' => $char->statusesString(), # Never used
		'characterName' => $char->name(),
		'characterJob' => $jobs_lut{$char->{jobID}},
		'characterJobID' => $char->{jobID},
		'characterSex' => $sex_lut{$char->{sex}},
		'characterSexID' => $char->{sex},
		'characterLevel' => $char->{lv},
		'characterJobLevel' => $char->{lv_job},
		'characterID' => unpack("V", $char->{ID}), # Never used
		'characterHairColor'=> $haircolors{$char->{hair_color}}, # Never used
		'characterGuildName' => $char->{guild}{name},
		'characterLeftHand' => $char->{equipment}{leftHand}{name} || 'none', # Never used
		'characterRightHand' => $char->{equipment}{rightHand}{name} || 'none', # Never used
		'characterTopHead' => $char->{equipment}{topHead}{name} || 'none', # Never used
		'characterMidHead' => $char->{equipment}{midHead}{name} || 'none', # Never used
		'characterLowHead' => $char->{equipment}{lowHead}{name} || 'none', # Never used
		'characterRobe' => $char->{equipment}{robe}{name} || 'none', # Never used
		'characterArmor' => $char->{equipment}{armor}{name} || 'none', # Never used
		'characterShoes' => $char->{equipment}{shoes}{name} || 'none', # Never used
		'characterLeftAccessory' => $char->{equipment}{leftAccessory}{name} || 'none', # Never used
		'characterRightAccessory' => $char->{equipment}{rightAccessory}{name} || 'none', # Never used
		'characterArrow' => $char->{equipment}{arrow}{name} || 'none', # Never used
		'characterZeny' => formatNumber($char->{'zeny'}),
		'characterStr' => $char->{str},
		'characterStrBonus' => $char->{str_bonus},
		'characterStrPoints' => $char->{points_str},
		'characterAgi' => $char->{agi},
		'characterAgiBonus' => $char->{agi_bonus},
		'characterAgiPoints' => $char->{points_agi},
		'characterVit' => $char->{vit},
		'characterVitBonus' => $char->{vit_bonus},
		'characterVitPoints' => $char->{points_vit},
		'characterInt' => $char->{int},
		'characterIntBonus' => $char->{int_bonus},
		'characterIntPoints' => $char->{points_int},
		'characterDex' => $char->{dex},
		'characterDexBonus' => $char->{dex_bonus},
		'characterDexPoints' => $char->{points_dex},
		'characterLuk' => $char->{luk},
		'characterLukBonus' => $char->{luk_bonus},
		'characterLukPoints' => $char->{points_luk},
		'characterFreePoints' => $char->{points_free},
		'characterAttack' => $char->{attack},
		'characterAttackBonus' => $char->{attack_bonus},
		'characterAttackMagicMax' => $char->{attack_magic_max},
		'characterAttackMagicMin' => $char->{attack_magic_min},
		'characterAttackRange' => $char->{attack_range}, # Never used
		'characterAttackSpeed' => $char->{attack_speed},
		'characterHit' => $char->{hit},
		'characterCritical' => $char->{critical},
		'characterDef' => $char->{def},
		'characterDefBonus' => $char->{def_bonus},
		'characterDefMagic' => $char->{def_magic},
		'characterDefMagicBonus' => $char->{def_magic_bonus},
		'characterFlee' => $char->{flee},
		'characterFleeBonus' => $char->{flee_bonus},
		'characterSpirits' => $char->{spirits} || '-', # Never used
	
		'characterBaseExp' => $char->{exp},
		'characterBaseMax' => $char->{exp_max},
		'characterBasePercent' => $char->{exp_max} ?
			sprintf("%.2f", $char->{exp} / $char->{exp_max} * 100) :
			0,
		'characterJobExp' => $char->{exp_job},
		'characterJobMax' => $char->{exp_job_max},
		'characterJobPercent' => $char->{exp_job_max} ?
			sprintf("%.2f", $char->{'exp_job'} / $char->{'exp_job_max'} * 100) :
			0,
		'characterHP' => $char->{hp},
		'characterHPMax' => $char->{hp_max},
		'characterHPPercent' => sprintf("%.2f", $char->hp_percent()),
		'characterSP' => $char->{sp},
		'characterSPMax' => $char->{sp_max},
		'characterSPPercent' => sprintf("%.2f", $char->sp_percent()),
		'characterWeight' => $char->{weight},
		'characterWeightMax' => $char->{weight_max},
		'characterWeightPercent' => sprintf("%.0f", $char->weight_percent()),
		'characterWalkSpeed' => $char->{walk_speed}, # Never used
		'characterLocationX' => $char->position()->{x},
		'characterLocationY' => $char->position()->{y},
		'characterLocationMap' => $field->name,
		'characterLocationMapURL' => sprintf($config{webMapURL} || '/map/%s', $field->name),
		'characterLocationDescription' => $field->descString,
		'characterGetRouteX' => $char->{pos_to}->{x}, # Never used
		'characterGetRouteY' => $char->{pos_to}->{y}, # Never used
		'characterGetTimeRoute' => $char->{time_move_calc}, # Never used
	# Other's
		'userAccount' => $config{username},
		'userChar' => $config{char}, # Never used
		'brand' => $Settings::NAME,
		'version' => $Settings::NAME . ' ' . $Settings::VERSION . ' ' . $Settings::CVS, # Never used
	);
	
	# FIXME
	%templates = map { $_ => template->new($webMonitorPlugin::path . '/WWW/' . $_ . '.template')->{template} } qw(
		_header.html
		_footer.html
		_sidebar.html
	);
	
	if ($filename eq '/handler') {
		$self->checkCSRF($process) or return;
		handle(\%resources, $process);
		return;
	}

	if ($filename =~ m{^/map/(\w+)$} and my $image = Field->new(name => $1)->image('png, jpg')) {
		$process->header('Content-Type' => contentType($image));
		sendFile($process, $image);

	} else {
		# Figure out the content-type of the file and send a header to the
		# client containing that information. Well-behaved clients should
		# respect this header.
		$process->header("Content-Type", contentType($filename));

		my $file = new template($webMonitorPlugin::path . '/WWW/' . $filename . '.template');

		# The file requested has an associated template. Do a replacement.
		if ($file->{template}) {
			# FIXME
			$file->{template} = $file->replace(\%templates, qw({{ }}));

			# FIXME: gettext in templates
			$keywords{"T $_"} = T($_) for $file->{template} =~ /\{T ([^}]+)\}/g;

			$content = $file->replace(\%keywords, '{', '}');
			$process->print($content);

		# See if the file being requested exists in the file system. This is
		# useful for static stuff like style sheets and graphics.
		} elsif (sendFile($process, $webMonitorPlugin::path . '/WWW/' . $filename)) {

		} else {
			# our custom 404 message
			$process->header('Content-Type' => 'text/html');
			$process->status(404 => 'Not Found');
			$content .= "<h1>Not Found</h1>";
			$process->shortResponse($content);
		}
	}
}

sub sendFile {
	my ($process, $filename) = @_;

	if (open my $f, '<', $filename) {
		binmode $f;
		while (read $f, my $buffer, 1024) {
			$process->print($buffer);
		}
		close $f;
		return 1;
	}
}

sub handle {
	my $resources = shift;
	my $process = shift;
	my $retval;

	if ($resources->{command}) {
		message "New command received via web: $resources->{command}\n";
		Commands::run($resources->{command});
	}

	if ($resources->{x} && $resources->{y}) {
		my ($x, $y) = map int, @{$resources}{qw(x y)};
		$y = $field->{height} - $y;
		Commands::run("move $x $y");
	}

	# Used Shop tab
	if ($resources->{shop}) {
	# Erase old data from array (Won't show itens from stores previously opened) 
		@price = ();
		@number = ();
		@listName = ();
		@listAmount = ();
		@upgrade = ();
		@cards = ();
		@type = ();
		@id = ();
		@shopJS = ();
	# Tell send\ServerType0.pm to send packets to Ragnarok, in order to list the itens from the shop
		$shopNumber = $resources->{shop};
		$messageSender->sendEnteringVender($venderListsID[$shopNumber]);
	# Look "sub hookShopList" to learn how the data reading was made
	}

	# make sure this is the last resource to be checked
	if ($resources->{page}) {
		my $filename = $resources->{page};
		$filename .= 'index.html' if ($filename =~ /\/$/);

		# hooray for standards-compliance
 		$process->header('Location', $filename);
		$process->status(303, "See Other");
		$process->print("\n");
		return
	}

	$process->status(204 => 'No Content');
}

sub contentType {
	# TODO: make it so we don't depend on the filename extension for the content
	# type. Instead, look in the file to determine the content-type.
	my $filename = shift;
	
	my @parts = split /\./, $filename;
	my $extension = $parts[-1];
	if (lc($extension) eq "asf") {
		return "video/x-ms-asf";
	} elsif (lc($extension) eq "avi") {
		return "video/avi";
	} elsif (lc($extension) eq "doc") {
		return "application/msword";
	} elsif (lc($extension) eq "zip") {
		return "application/zip";
	} elsif (lc($extension) eq "xls") {
		return "application/vnd.ms-excel";
	} elsif (lc($extension) eq "gif") {
		return "image/gif";
	} elsif (lc($extension) eq "png") {
		return "image/png";
	} elsif (lc($extension) eq "jpg" || lc($extension) eq "jpeg") {
		return "image/jpeg";
	} elsif (lc($extension) eq "wav") {
		return "audio/wav";
	} elsif (lc($extension) eq "mp3") {
		return "audio/mpeg3";
	} elsif (lc($extension) eq "mpg"|| lc($extension) eq "mpeg") {
		return "video/mpeg";
	} elsif (lc($extension) eq "rtf") {
		return "application/rtf";
	} elsif (lc($extension) eq "htm"|| lc($extension) eq "html") {
		return "text/html";
	} elsif (lc($extension) eq "txt") {
		return "text/plain";
	} elsif (lc($extension) eq "css") {
		return "text/css";
	} elsif (lc($extension) eq "pdf") {
		return "application/pdf";
	} else {
		return "application/x-unknown";
	}
}

1;

	# the webserver shouldn't differentiate between actual characters and url
	# encoded characters. see http://www.blooberry.com/indexdot/html/topics/urlencoding.htm
#	$filename =~ s/\%24/\$/sg;
#	$filename =~ s/\%26/\&/sg;
#	$filename =~ s/\%2B/\+/sg;
#	$filename =~ s/\%2C/\,/sg;
#	$filename =~ s/\%2F/\//sg;
#	$filename =~ s/\%3A/\:/sg;
#	$filename =~ s/\%3B/\:/sg;
#	$filename =~ s/\%3D/\=/sg;
#	$filename =~ s/\%3F/\?/sg;
#	$filename =~ s/\%40/\@/sg;
#	$filename =~ s/\%20/\+/sg;
#	$filename =~ s/\%22/\"/sg;
#	$filename =~ s/\%3C/\</sg;
#	$filename =~ s/\%3E/\>/sg;
#	$filename =~ s/\%23/\#/sg;
#	$filename =~ s/\%25/\%/sg;
#	$filename =~ s/\%7B/\{/sg;
#	$filename =~ s/\%7D/\}/sg;
#	$filename =~ s/\%7C/\|/sg;
#	$filename =~ s/\%5C/\\/sg;
#	$filename =~ s/\%5E/\^/sg;
#	$filename =~ s/\%7E/\~/sg;
#	$filename =~ s/\%5B/\[/sg;
#	$filename =~ s/\%5D/\]/sg;
#	$filename =~ s/\%60/\`/sg;
