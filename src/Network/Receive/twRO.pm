#########################################################################
#  OpenKore - Network subsystem
#  Copyright (c) 2006 OpenKore Team
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#########################################################################
# twRO (Taiwan)
# Servertype overview: http://wiki.openkore.com/index.php/ServerType
package Network::Receive::twRO;

use strict;
use Time::HiRes;

use Globals;
use base qw(Network::Receive::ServerType0);
use Log qw(message warning error debug);
use Network::MessageTokenizer;
use Misc;
use Utils;
use Translation;

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);

	my $loadShuffles = Settings::addTableFile('shuffles.txt',loader => [\&parseShuffles,\my %npShuffles], mustExist => 0);
	Settings::loadByHandle($loadShuffles);
	# Settings::addTableFile(Settings::getRecvPacketsFilename(),
	# loader => [\&parseRecvpackets, \%rpackets]);
	
	#new packets
	my %packets = (
		'006D' => ['character_creation_successful', 'a4 V9 v V2 v14 Z24 C6 v2 Z*', [qw(charID exp zeny exp_job lv_job opt1 opt2 option stance manner points_free hp hp_max sp sp_max walk_speed type hair_style weapon lv points_skill lowhead shield tophead midhead hair_color clothes_color name str agi vit int dex luk slot renameflag mapname)]],
		'0097' => ['private_message', 'v Z28 Z*', [qw(len privMsgUser privMsg)]],
		'082D' => ['received_characters_info', 'x2 C5 x20', [qw(normal_slot premium_slot billing_slot producible_slot valid_slot)]],
		'099B' => ['map_property3', 'v a4', [qw(type info_table)]],
		'099F' => ['area_spell_multiple2', 'v a*', [qw(len spellInfo)]], # -1
		'0A3B' => ['misc_effect', 'v a4 C v', [qw(len ID flag effect)]],
		'0A0C' => ['inventory_item_added', 'v3 C3 a8 V C2 V v', [qw(index amount nameID identified broken upgrade cards type_equip type fail expire bindOnEquipType)]],#31
		'0991' => ['inventory_items_stackable', 'v a*', [qw(len itemInfo)]],#-1
		'0A0D' => ['inventory_items_nonstackable', 'v a*', [qw(len itemInfo)]],#-1
		'0A0A' => ['storage_item_added', 'v V v C4 a8', [qw(index amount nameID type identified broken upgrade cards)]],
		'0A0B' => ['cart_item_added', 'v V v C x26 C2 a8', [qw(index amount nameID identified broken upgrade cards)]],
		'0993' => ['cart_items_stackable', 'v a*', [qw(len itemInfo)]],#-1
		'0A0F' => ['cart_items_nonstackable', 'v a*', [qw(len itemInfo)]],#-1
		'0995' => ['storage_items_stackable', 'v Z24 a*', [qw(len title itemInfo)]],#-1
		'0A10' => ['storage_items_nonstackable', 'v Z24 a*', [qw(len title itemInfo)]],#-1
		
		'091D' => ['sync_request_ex'],
		'087A' => ['sync_request_ex'],
		'08A3' => ['sync_request_ex'],
		'0877' => ['sync_request_ex'],
		'0869' => ['sync_request_ex'],
		'0898' => ['sync_request_ex'],
		'091F' => ['sync_request_ex'],
		'085F' => ['sync_request_ex'],
		'0438' => ['sync_request_ex'],
		'08A1' => ['sync_request_ex'],
		'0960' => ['sync_request_ex'],
		'0885' => ['sync_request_ex'],
		'0957' => ['sync_request_ex'],
		'0281' => ['sync_request_ex'],
		'0937' => ['sync_request_ex'],
		'0961' => ['sync_request_ex'],
		'0876' => ['sync_request_ex'],
		'095B' => ['sync_request_ex'],
		'0938' => ['sync_request_ex'],
		'0894' => ['sync_request_ex'],
		'087D' => ['sync_request_ex'],
		'022D' => ['sync_request_ex'],
		'092B' => ['sync_request_ex'],
		'0A68' => ['sync_request_ex'],
		'0920' => ['sync_request_ex'],
		'089E' => ['sync_request_ex'],
		'0884' => ['sync_request_ex'],
		'0945' => ['sync_request_ex'],
		'0A5C' => ['sync_request_ex'],
		'0927' => ['sync_request_ex'],
		'089A' => ['sync_request_ex'],
		'0964' => ['sync_request_ex'],
		'0918' => ['sync_request_ex'],
		'0923' => ['sync_request_ex'],
		'0922' => ['sync_request_ex'],
		'086C' => ['sync_request_ex'],
		'0958' => ['sync_request_ex'],
		'0931' => ['sync_request_ex'],
		'0921' => ['sync_request_ex'],
		'0875' => ['sync_request_ex'],
		'085E' => ['sync_request_ex'],
		'0878' => ['sync_request_ex'],
		'0883' => ['sync_request_ex'],
		'093F' => ['sync_request_ex'],
		'094A' => ['sync_request_ex'],
		'089D' => ['sync_request_ex'],
		'0932' => ['sync_request_ex'],
		'096A' => ['sync_request_ex'],
		'0861' => ['sync_request_ex'],
		'087C' => ['sync_request_ex'],
		'0A69' => ['sync_request_ex'],
		'0899' => ['sync_request_ex'],
		'0868' => ['sync_request_ex'],
		'0363' => ['sync_request_ex'],
		'0955' => ['sync_request_ex'],
		'0A6E' => ['sync_request_ex'],
		'0369' => ['sync_request_ex'],
		'0942' => ['sync_request_ex'],
		'0860' => ['sync_request_ex'],
		'0888' => ['sync_request_ex'],
		'095D' => ['sync_request_ex'],
		'0943' => ['sync_request_ex'],
		'08AA' => ['sync_request_ex'],
		'087B' => ['sync_request_ex'],
		'0A6C' => ['sync_request_ex'],
		'0944' => ['sync_request_ex'],
		'0969' => ['sync_request_ex'],
		'0835' => ['sync_request_ex'],
		'0935' => ['sync_request_ex'],
		'0963' => ['sync_request_ex'],
		'0872' => ['sync_request_ex'],
		'088C' => ['sync_request_ex'],
		'0962' => ['sync_request_ex'],
		'0946' => ['sync_request_ex'],
		'089C' => ['sync_request_ex'],
		'092E' => ['sync_request_ex'],
		'0802' => ['sync_request_ex'],
		'086E' => ['sync_request_ex'],
		'091C' => ['sync_request_ex'],
		'0866' => ['sync_request_ex'],
		'0815' => ['sync_request_ex'],
		'093B' => ['sync_request_ex'],
		'0361' => ['sync_request_ex'],
		'0892' => ['sync_request_ex'],
	);
	$self->{packet_list}{$_} = $packets{$_} for keys %packets;

	$self->{sync_ex_reply} = {
		'091D' => '0936',
		'087A' => '08A2',
		'08A3' => '0895',
		'0877' => '08AC',
		'0869' => '088D',
		'0898' => '092A',
		'091F' => '07E4',
		'085F' => '0968',
		'0438' => '0368',
		'08A1' => '0947',
		'0960' => '0949',
		'0885' => '0917',
		'0957' => '0362',
		'0281' => '0202',
		'0937' => '086A',
		'0961' => '092F',
		'0876' => '094D',
		'095B' => '0891',
		'0938' => '0948',
		'0894' => '0954',
		'087D' => '088A',
		'022D' => '086D',
		'092B' => '093E',
		'0A68' => '085A',
		'0920' => '0364',
		'089E' => '091E',
		'0884' => '0929',
		'0945' => '0862',
		'0A5C' => '088F',
		'0927' => '0951',
		'089A' => '0889',
		'0964' => '092C',
		'0918' => '0874',
		'0923' => '094E',
		'0922' => '0879',
		'086C' => '0867',
		'0958' => '0952',
		'0931' => '0934',
		'0921' => '083C',
		'0875' => '0933',
		'085E' => '0941',
		'0878' => '0950',
		'0883' => '094C',
		'093F' => '08AD',
		'094A' => '0366',
		'089D' => '08A6',
		'0932' => '085D',
		'096A' => '0367',
		'0861' => '087E',
		'087C' => '0360',
		'0A69' => '093A',
		'0899' => '0886',
		'0868' => '0436',
		'0363' => '089F',
		'0955' => '0365',
		'0A6E' => '035F',
		'0369' => '0890',
		'0942' => '0865',
		'0860' => '094F',
		'0888' => '0437',
		'095D' => '0893',
		'0943' => '093C',
		'08AA' => '023B',
		'087B' => '0966',
		'0A6C' => '0940',
		'0944' => '07EC',
		'0969' => '085B',
		'0835' => '0965',
		'0935' => '08A4',
		'0963' => '0939',
		'0872' => '02C4',
		'088C' => '0863',
		'0962' => '093D',
		'0946' => '0924',
		'089C' => '094B',
		'092E' => '0838',
		'0802' => '0956',
		'086E' => '0967',
		'091C' => '086F',
		'0866' => '08A5',
		'0815' => '08A9',
		'093B' => '0819',
		'0361' => '091A',
		'0892' => '0930',
	};
	
	#New item type6
	$self->{nested} = {
		items_nonstackable => { # EQUIPMENTITEM_EXTRAINFO
			type6 => {
				len => 57,
				types => 'v2 C V2 C a8 l v2 x26 C',
				keys => [qw(index nameID type type_equip equipped upgrade cards expire bindOnEquipType sprite_id flag)],
			},
		},
		items_stackable => { # ITEMLIST_NORMAL_ITEM
			type6 => {
				len => 24,
				types => 'v2 C v V a8 l C',
				keys => [qw(index nameID type amount type_equip cards expire flag)],
			},
		},
	};
	
	return $self;
}

*parse_quest_update_mission_hunt = *Network::Receive::parse_quest_update_mission_hunt_v2;
*reconstruct_quest_update_mission_hunt = *Network::Receive::reconstruct_quest_update_mission_hunt_v2;

sub gameguard_request {
	my ($self, $args) = @_;

	debug "NProtect request received\n", "NProtect";
	return if ($config{NProtect} && $config{NProtect} == 0);

	if ($config{NProtect} == 1 || !$config{NProtect}) { #Re-log
		my $relogSecond = $timeout{'NProtect_relog_second'}{'timeout'} || 3; # 1 - 3 seconds
		error TF("NProtect check request received. Re-loging in %s seconds.\n", $relogSecond), 'info';
		
		#Re-logging in after random sec
		$taskManager->add(
			new Task::Chained(tasks => [
				new Task::Wait(seconds => rand(int($timeout{'NProtect_relog_delay'}{'timeout'})) + 1 || 5),
				new Task::Function(function => sub {relog(rand($relogSecond) + 1);$_[0]->setDone;})
			])
		);
	} elsif ($config{NProtect} == 2) {
		my $relogSecond = $timeout{'NProtect_relog_second'}{'timeout'} || 3; # 1 - 3 seconds
		error TF("NProtect check request received. Char-selecting in %s seconds.\n", $relogSecond), 'info';
		
		#Re-logging in after random sec
		$taskManager->add(
			new Task::Chained(tasks => [
				new Task::Wait(seconds => rand(int($timeout{'NProtect_relog_delay'}{'timeout'})) + 1 || 5),
				new Task::Function(function => sub {$messageSender->sendRestart(1);$_[0]->setDone;})
			])
		);
	}
}

sub sync_received_characters {
	my ($self, $args) = @_;
	if (exists $args->{sync_Count}) {
		$charSvrSet{sync_Count} = $args->{sync_Count};
		$charSvrSet{sync_CountDown} = $args->{sync_Count};
	}

	if ($config{'XKore'} ne '1') {
		$messageSender->sendToServer($messageSender->reconstruct({switch => 'sync_received_characters'}));
		$charSvrSet{sync_CountDown}--;
	}
}

sub received_characters_info {
	my ($self, $args) = @_;

	$charSvrSet{normal_slot} = $args->{normal_slot} if (exists $args->{normal_slot});
	$charSvrSet{premium_slot} = $args->{premium_slot} if (exists $args->{premium_slot});
	$charSvrSet{billing_slot} = $args->{billing_slot} if (exists $args->{billing_slot});
	$charSvrSet{producible_slot} = $args->{producible_slot} if (exists $args->{producible_slot});
	$charSvrSet{valid_slot} = $args->{valid_slot} if (exists $args->{valid_slot});

	$timeout{charlogin}{time} = time;
}

sub items_nonstackable {
	my ($self, $args) = @_;
	my $items = $self->{nested}->{items_nonstackable};

	if ($args->{switch} eq '0A0D' ||# inventory
		$args->{switch} eq '0A0F' ||# cart
		$args->{switch} eq '0A10'	# storage
	) {
		return $items->{type6} ;
	}
	#Exception
	warning "items_nonstackable: unsupported packet ($args->{switch})!\n";
}

sub items_stackable {
	my ($self, $args) = @_;
	my $items = $self->{nested}->{items_stackable};

	if ($args->{switch} eq '0991' ||# inventory
		$args->{switch} eq '0993' ||# cart
		$args->{switch} eq '0995'	# storage
	) {
		return $items->{type6};
	}
	#Exception
	warning "items_stackable: unsupported packet ($args->{switch})!\n";
}

sub parse_items_nonstackable {
	my ($self, $args) = @_;
	$self->parse_items($args, $self->items_nonstackable($args), sub {
		my ($item) = @_;
		
		$item->{amount} = 1 unless ($item->{amount});
		if ($item->{flag} == 0) {
			$item->{broken} = $item->{identified} = 0;
		} elsif ($item->{flag} == 1 || $item->{flag} == 5) {
			$item->{broken} = 0;
			$item->{identified} = 1;
		} elsif ($item->{flag} == 3 || $item->{flag} == 7) {
			$item->{broken} = $item->{identified} = 1;
		} else {
			message T ("Warning: unknown flag!\n");
		}
	});
}

sub parse_items_stackable {
	my ($self, $args) = @_;
	$self->parse_items($args, $self->items_stackable($args), sub {
		my ($item) = @_;
		
		$item->{idenfitied} = $item->{identified} & (1 << 0);
		if ($item->{flag} == 0) {
			$item->{identified} = 0;
		} elsif ($item->{flag} == 1 || $item->{flag} == 3) {
			$item->{identified} = 1;
		} else {
			message T ("Warning: unknown flag!\n");
		}
	});
}

sub parseShuffles {
	my ($file, $r_hash) = @_;
	%{$r_hash} = ();
	my $reader = new Utils::TextReader($file);
	while (!$reader->eof()) {
		my $line = $reader->readLine();
		next if ($line =~ /^#/);
		$line =~ s/[\r\n]//g;
		next if (length($line) == 0);
		
		my ($packetID, $function) = split /\s+/, $line, 2;
		$packetID =~ s/^(0x[0-9a-f]+)$/hex $1/e;
		$r_hash->{$packetID}{function} = $function; # can be used as description instead of packetdescriptions.txt, if defined.
	}
	close FILE;
	
	return 1;
}

1;