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

# TODO use real templating system?
my %templates;

#[PT-BR]
# Keywords são campos específicos no modelo que irá, eventualmente,
# ser substituído por conteúdo dinâmico
#[EN] 
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

sub new {
	my $class = shift;

	my $self = $class->SUPER::new(@_);
	message TF("webMonitor started at http://%s:%s/\n", $self->getHost, $self->getPort), 'connection';
	$self
}

sub cHook {
	my $type = shift;
	my $domain = shift;
	my $level = shift;
	my $currentVerbosity = shift;
	my $messages = shift;
	my $user_data = shift;
	my $logfile = shift;
	my $deathmsg = shift;

	if ($level <= $currentVerbosity) {
		# Prepend the time to the message
		my (undef, $microseconds) = Time::HiRes::gettimeofday;
		$microseconds = substr($microseconds, 0, 2);
		my $message = "[".getFormattedDate(int(time)).".$microseconds] ".$messages;	
	
		# TODO: make this configurable (doesn't prepend the time for now)
		my @lines = split "\n", $messages;
		if (@lines > 1) {
			foreach my $line (@lines) {
				$line .= "\n";
				push @messages, $line;
			}
		} else {
			push(@messages, $messages);
		}

		# Make sure we don't let @messages grow too large
		# TODO: make the message size configurable
		while (@messages > 20) {
			shift(@messages);
		}
	}
}

# [PT-BR] "hookShopList" é usada na aba "Shop".
# [EN] "hookShopList" is used on tab "Shop".
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
		push (@shopJS, '<a class="btn btn-mini btn-success"  href="/handler?command=buy+' . $shopNumber . ' , ' . $args->{number} . ')">Buy</a>');
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

# [PT-BR] Listar o inventário
# [EN] Show inventory
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
			push @unusableJS, '<td><a class="btn btn-mini btn-danger" href="/handler?command=drop+' . $item->{invIndex} . '">Drop</a></td>';
		} elsif ($item->{type} <= 2) {
			push @usableID, $item->{nameID};
			push @usable, $item->{name};
			push @usableAmount, $item->{amount};
			push @usableJS, '<td><a class="btn btn-mini btn-success" href="/handler?command=is+' . $item->{invIndex} . '">Use</a></td><td><a class="btn btn-mini btn-danger" href="/handler?command=drop+' . $item->{invIndex} . '">Drop</a></td>';
		} else {
			if ($item->{equipped}) {
				push @equipmentID, $item->{nameID};
				push @equipment, $item->{name};
				push @equipmentJS, '<td><a class="btn btn-mini btn-inverse" href="/handler?command=eq+' . $item->{invIndex} . '">Unequip</a></td><td><a class="btn btn-mini btn-danger" href="/handler?command=drop+' . $item->{invIndex} . '">Drop</a></td>';
			} else {
				push @uequipmentID, $item->{nameID};
				push @uequipment, $item->{name};
				push @uequipmentJS, '<td><a class="btn btn-mini btn-inverse" href="/handler?command=eq+' . $item->{invIndex} . '">Equip</a></td><td><a class="btn btn-mini btn-danger" href="/handler?command=drop+' . $item->{invIndex} . '">Drop</a></td>';
			}
		}
	}
	my @statuses = (keys %{$char->{statuses}});

# [PT-BR] Listar os membros do clã
# [EN] Show members of the clan
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
	
# [PT-BR] Listar as lojas dos jogadores (NÃO serão listadas as dos NPC's!!)
# [EN] List player stores (NPC's shops won't be listed!!)
	my (@listComboBox);

	for (my $i = 0; $i < @venderListsID; $i++) {
		next if ($venderListsID[$i] eq "");
		my $player = Actor::get($venderListsID[$i]);
		# autovivifies $obj->{pos_to} but it doesnt matter
		push (@listComboBox, '<option value="' . $i . '">' . $venderLists{$venderListsID[$i]}{'title'} . '</option>');
		#push @shopList, $i . ' ' . $venderLists{$venderListsID[$i]}{'title'} . ' ' . $player->{pos_to}{x} || '?' . ' ' . $player->{pos_to}{y} || '?' . ' ' . $player->name . '<br>'
	}

# [PT-BR] Listar os NPC's
# [EN] Show NPC's
	my (@npcBinID, @npcName, @npcLocX, @npcLocY, @npcNameID, @npcTalk);
	my $npcs = $npcsList->getItems();
		foreach my $npc (@{$npcs}) {
			push @npcNameID, $npc->{binID};
			push @npcLocX, $npc->{pos}{x};
			push @npcLocY, $npc->{pos}{y};
			push @npcName, $npc->name;
			push @npcBinID, $npc->{nameID};
			push @npcTalk, '<a class="btn btn-mini" href="javascript:talk(' . $npc->{binID} . ')">Talk</a>';
		}

# [PT-BR] Listar habilidades
# [EN] Show skills
	my (@skillsIDN, @skillsName, @skillsLevel, @skillsJS, @skillsIcoUp);	
	for my $handle (@skillsID) {
		my $skill = new Skill(handle => $handle);
		my $sp = $char->{skills}{$handle}{sp} || 'Skill Pasive';
		my $IDN = $skill->getIDN();
		my $act = '';

		#  [EN] $skill->getTargetType() can result in 0, 1, 2 and 4
		# 0 -> Passive Skill (Therefore $act have nothing, because it's not consumes SP and can't be used)
		# 1 -> It's used on enemy
		# 2 -> It's used in a place
		# 4 -> It's used in yourself. Can involve party too (E.G: Glory Skill)
		# 16 -> It's used in other players.
		# See more in src\Actor.pm		
		#  [PT-BR] $skill->getTargetType() pode resultar em 0, 1, 2 e 4
		# 0 -> Skill passiva (por isso $act terá nada, pois não consome 0 e não pode ser usada)
		# 1 -> Usa-se no inimigo
		# 2 -> Usa-se em um lugar
		# 4 -> Usa-se em você. Pode envolver o grupo também (ex: habilidade glória)
		# 16 -> Usa-se em outros jogadores
		# Veja mais no src\Actor.pm
		my $type = $skill->getTargetType();
		if ($char->getSkillLevel($skill) > 0){
			if ($type == 0){
				$act = '<td></td><td><div align="center"><a class="btn btn-mini disabled">Passive</a></div></td>'; #Skill passive
			} elsif ($type == 1){
				$act = '<td>SP: ' . $sp . '<td>   <div align="center"><a class="btn btn-mini" href="/handler?command=sm+' . $IDN . '+0">Attack</a></div>';
			} elsif ($type == 2){
				$act = '<td>SP: ' . $sp . '<td>   <div align="center"><a class="btn btn-mini" href="/handler?command=sl+' . $IDN . '+{characterLocationX}+{characterLocationY}">choose location</a></div>';
			} elsif ($type == 4){
				$act = '<td>SP: ' . $sp . '<td>   <div align="center"><a class="btn btn-mini" href="/handler?command=ss+' . $IDN . '">Use</a></div>';
			} elsif ($type == 16){
				$act = '<td>SP: ' . $sp . '<td>   <div align="center"><a class="btn btn-mini" href="/handler?command=sp+' . $IDN . '+0">Choose actor</a></div>';
			} 
		}
		
		# [PT-BR] Saber se o personagem tem ou não pontos de habilidades disponíveis e se a habilidade é melhorável
		#  (ainda não chegou ao nível máximo e atingiu seus pré-requisitos), para saber se deve mostrar a imagem de aumentar nível e sua função.
		my $ico_up;
		if ($char->{points_skill} > 0 && $char->{skills}{$handle}{up} == 1){
			$ico_up = '<a href="/handler?command=skills+add+' . $IDN .'"><i class="icon-plus-sign"></i></a> ';
		}
		
		# [PT-BR] Para finalizar, adicionar dados para as array's
		# [EN] To finalize, add the elements into the array's
		push @skillsIDN, $IDN;
		push @skillsIcoUp, $ico_up;
		push @skillsName, $skill->getName();
		push @skillsLevel, $char->getSkillLevel($skill);
		push @skillsJS, $act;
	}
	
	%keywords =	(
	# NPC
		'npcBinID' => \@npcBinID,
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
		'consoleMessages' => \@messages,
		'characterStatuses' => \@statuses,
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
		'guildListMemberIndex' => \@listMemberIndex,
		'guildListMemberName' => \@listMemberName,
		'guildListMemberClass' => \@listMemberClass,
		'guildListMemberLvl' => \@listMemberLvl,
		'guildListMemberTitle' => \@listMemberTitle,
		'guildListMemberOnline' => \@listMemberOnline,
		'guildListMemberID' => \@listMemberID,
		'guildListMemberCharID' => \@listMemberCharID,
	# Shop
		'shopListComboBox' => \@listComboBox,
		'shopName' => \@listName,
		'shopAmount' => \@listAmount,
		'shopPrice' => \@price,
		'shopNumber' => \@number,
		'shopUpgrade' => \@upgrade,
		'shopCards' => \@cards,
		'shopType' => \@type,
		'shopID' => \@id,
		'shopJS' => \@shopJS,
	# Skills
		'skillsIDN' => \@skillsIDN,
		'skillsIcoUp' => \@skillsIcoUp,
		'skillsName' => \@skillsName,
		'skillsLevel' => \@skillsLevel,
		'skillsJS' => \@skillsJS,
	# Report
		'time' => $time,
		'reconnectCount' => $reconnectCount, #relogs
		'deathCount' => $char->{deathCount}, #died times
		'totalElasped' => timeConvert($totalelasped), #tempo de bot
		'totalDamage' => $totaldmg, #dmg total feito
		'startTimeEXP' => timeConvert($startTime_EXP),
		'totalBaseExp' => $totalBaseExp, #exp ganha
		'totalJobExp' => $totalJobExp, #exp ganha
	# Other's
		'userAccount' => $config{username},
		'userChar' => $config{char},
		'characterSkillPoints' => $char->{points_skill},
		'characterStatusesSring' => $char->statusesString(),
		'characterName' => $char->name(),
		'characterJob' => $jobs_lut{$char->{jobID}},
		'characterJobID' => $char->{jobID},
		'characterSex' => $sex_lut{$char->{sex}},
		'characterSexID' => $char->{sex},
		'characterLevel' => $char->{lv},
		'characterJobLevel' => $char->{lv_job},
		'characterID' => unpack("V", $char->{ID}),
		'characterHairColor'=> $haircolors{$char->{hair_color}},
		'characterGuildName' => $char->{guild}{name},
		'characterLeftHand' => $char->{equipment}{leftHand}{name} || 'none',
		'characterRightHand' => $char->{equipment}{rightHand}{name} || 'none',
		'characterTopHead' => $char->{equipment}{topHead}{name} || 'none',
		'characterMidHead' => $char->{equipment}{midHead}{name} || 'none',
		'characterLowHead' => $char->{equipment}{lowHead}{name} || 'none',
		'characterRobe' => $char->{equipment}{robe}{name} || 'none',
		'characterArmor' => $char->{equipment}{armor}{name} || 'none',
		'characterShoes' => $char->{equipment}{shoes}{name} || 'none',
		'characterLeftAccessory' => $char->{equipment}{leftAccessory}{name} || 'none',
		'characterRightAccessory' => $char->{equipment}{rightAccessory}{name} || 'none',
		'characterArrow' => $char->{equipment}{arrow}{name} || 'none',
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
		'characterAttackRange' => $char->{attack_range},
		'characterAttackSpeed' => $char->{attack_speed},
		'characterHit' => $char->{hit},
		'characterCritical' => $char->{critical},
		'characterDef' => $char->{def},
		'characterDefBonus' => $char->{def_bonus},
		'characterDefMagic' => $char->{def_magic},
		'characterDefMagicBonus' => $char->{def_magic_bonus},
		'characterFlee' => $char->{flee},
		'characterFleeBonus' => $char->{flee_bonus},
		'characterSpirits' => $char->{spirits} || '-',
	
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
		'characterWalkSpeed' => $char->{walk_speed},
		'characterLocationX' => $char->position()->{x},
		'characterLocationY' => $char->position()->{y},
		'characterLocationMap' => $field->name,
		'characterGetRouteX' => $char->{pos_to}->{x},
		'characterGetRouteY' => $char->{pos_to}->{y},
		'characterGetTimeRoute' => $char->{time_move_calc},
		'lastConsoleMessage' => $messages[-1],
		'lastConsoleMessage2' => $messages[-2],
		'lastConsoleMessage3' => $messages[-3],
		'skin' => 'default', # TODO: replace with config.txt entry for the skin
		'version' => $Settings::NAME . ' ' . $Settings::VERSION . ' ' . $Settings::CVS,
	);
	
	# FIXME
	%templates = map { $_ => template->new($webMonitorPlugin::path . '/WWW/' . $_ . '.template')->{template} } qw(
		_header.html
	);
	
	if ($filename eq '/handler') {
		handle(\%resources, $process);
		return;
	}
	# TODO: will be removed later
	if ($filename eq '/variables') {
		# [PT-BR] Recarregar a página a cada 5 segundos | [EN] Reload the page every 5 seconds
		$content .= '<head><meta http-equiv="refresh" content="5"></head>';
		
		# Display internal variables in alphabetical order (useful for debugging)
		$content .= '<hr><h1>%keywords</h1><hr>';
		foreach my $key (sort keys %keywords) {
			$content .= "$key => " . $keywords{$key} . '<br>';
		}
		$content .= '<hr>';

		$content .= '<hr><h1>$char</h1><hr>';
		foreach my $key (sort keys %{$char}) {
			$content .= "$key => " . $char->{$key} . '<br>';
		}
		$content .= '<hr>';
		$process->shortResponse($content);

	# TODO: will be removed later
	} elsif ($filename eq '/console') {
		# [PT-BR] Recarregar a página a cada 5 segundos | [EN] Reload the page every 5 seconds
		$content .= '<head><meta http-equiv="refresh" content="1"></head>' . "\n";
		$content .= '<pre>' . "\n";

		# Concatenate the message buffer
		foreach my $message (@messages) {
			$content .= $message;
		}
		
		$content .= '</pre>';
		$process->shortResponse($content);

	} elsif ($filename =~ m{^/map/(\w+)$} and my $image = Field->new(name => $1)->image('png, jpg')) {
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

    #[EN]
	# Reading commands sent via web
	# Example to send your bot say "Brazil" :
	# http://localhost:1025/handler?command=c+Brazil&page=default/status.html
	
	#[PT-BR]
	# Leitura dos comandos enviados via web.
	# Exemplo para mandar o bot dizer "Brasil":
	# http://localhost:1025/handler?command=c+Brasil&page=default/status.html
	if ($resources->{command}) {
		message "New command received via web: $resources->{command}\n";
		Commands::run($resources->{command});
	}

	# [PT-BR] Usado na aba Shop.
	# [EN] Used Shop tab
	if ($resources->{shop}) {
	# [PT-BR] Apagar dandos antigos da array (Não mostrar os itens das lojas clicadas anteriomente) 
	# [EN] Erase old data from array (Won't show itens from stores previously opened) 
		@price = ();
		@number = ();
		@listName = ();
		@listAmount = ();
		@upgrade = ();
		@cards = ();
		@type = ();
		@id = ();
		@shopJS = ();
	# [PT-BR] Mandar o send\ServerType0.pm enviar pacotes para o Ragnarok, afim de listar os itens da loja
	# [EN] Tell send\ServerType0.pm to send packets to Ragnarok, in order to list the itens from the shop
		$shopNumber = $resources->{shop};
		$messageSender->sendEnteringVender($venderListsID[$shopNumber]);
	# [PT-BR] Veja na "sub hookShopList" como foi feita a leitura dos dados
	# [EN] Look "sub hookShopList" to learn how the data reading was made
	}
	
	###
	
	if ($resources->{requestVar}) {
		$process->print($keywords{$resources->{requestVar}});
	}

	# make sure this is the last resource to be checked
	if ($resources->{page}) {
		my $filename = $resources->{page};
		$filename .= 'index.html' if ($filename =~ /\/$/);

		# hooray for standards-compliance
 		$process->header('Location', $filename);
		$process->status(303, "See Other");
		$process->print("\n");
	}
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
