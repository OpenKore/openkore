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

	my %npSync = {};
	my $loadShuffles = Settings::addTableFile('sync.txt',loader => [\&FileParsers::parseDataFile2,\%npSync], mustExist => 1);
	Settings::loadByHandle($loadShuffles);

	$self->{packet_list}{$_} = ['sync_request_ex'] for keys %npSync; #Shuffle Sync
	$self->{sync_ex_reply}{$_} = $npSync{value} for keys %npSync; #Sync Reply
	
	#new packets
	my %packets = ( #unique packets
		'006D' => ['character_creation_successful', 'a4 V9 v V2 v14 Z24 C6 v2 Z*', [qw(charID exp zeny exp_job lv_job opt1 opt2 option stance manner points_free hp hp_max sp sp_max walk_speed type hair_style weapon lv points_skill lowhead shield tophead midhead hair_color clothes_color name str agi vit int dex luk slot renameflag mapname)]],
		'0097' => ['private_message', 'v Z28 Z*', [qw(len privMsgUser privMsg)]],
		'082D' => ['received_characters_info', 'x2 C5 x20', [qw(normal_slot premium_slot billing_slot producible_slot valid_slot)]],
	);
	$self->{packet_list}{$_} = $packets{$_} for keys %packets;

	return $self;
}

*parse_quest_update_mission_hunt = *Network::Receive::parse_quest_update_mission_hunt_v2;
*reconstruct_quest_update_mission_hunt = *Network::Receive::reconstruct_quest_update_mission_hunt_v2;

sub gameguard_request {
	my ($self, $args) = @_;

	debug "NProtect request received\n", "NProtect";
	return if ($config{NProtect} == 0); #Disabled
	return if ($taskManager->countTasksByName('NProtect')); #Found task
	
	my $task; #Initialise
	my $relogDelay = int(rand(int($timeout{'NProtect_relog_delay'}{'timeout'})) + 1) || 300;
	my $relogSecond = int(rand($timeout{'NProtect_relog_second'}{'timeout'}) + 1) || 10;
	error TF("NProtect check request received. Re-loging in %s seconds.\n", $relogDelay), 'info';
	
	if ($config{NProtect} == 1) {
		$task = new Task::Chained(
			name => 'NProtect',
			tasks => [
				new Task::Wait(seconds => $relogDelay),
				new Task::Function(function => sub {
					relog($relogSecond);
					if ($net->getState() != Network::IN_GAME) {
						$_[0]->setDone;
					}
				})
		]);
	} else {
		$task = new Task::Chained(
			name => 'NProtect',
			tasks => [
				new Task::Wait(seconds => $relogDelay),
				new Task::Function(function => sub {
					$messageSender->sendRestart(1);
					if ($net->getState() != Network::IN_GAME) {
						$_[0]->setDone;
					}
				})
		]);
	}
	
	$taskManager->add($task);
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

sub vender_items_list {
	my ($self, $args) = @_;

	my $msg = $args->{RAW_MSG};
	my $msg_size = $args->{RAW_MSG_SIZE};
	my $headerlen;

	$headerlen = 12;

	undef @venderItemList;
	undef $venderID;
	undef $venderCID;
	$venderID = $args->{venderID};
	$venderCID = $args->{venderCID} if exists $args->{venderCID};
	my $player = Actor::get($venderID);

	message TF("%s\n" .
		"#   Name                                      Type        Amount          Price\n",
		center(' Vender: ' . $player->nameIdx . ' ', 79, '-')), ($config{showDomain_Shop}?$config{showDomain_Shop}:"list");
	for (my $i = $headerlen; $i < $args->{RAW_MSG_SIZE}; $i+=47) {
		my $item = {};
		my $index;

		($item->{price},
		$item->{amount},
		$index,
		$item->{type},
		$item->{nameID},
		$item->{identified}, # should never happen
		$item->{broken}, # should never happen
		$item->{upgrade},
		$item->{cards},
		$item->{options})	= unpack('V v2 C v C3 a8 a25', substr($args->{RAW_MSG}, $i, 47));

		$item->{name} = itemName($item);
		$venderItemList[$index] = $item;

		debug("Item added to Vender Store: $item->{name} - $item->{price} z\n", "vending", 2);

		Plugins::callHook('packet_vender_store', {
			venderID => $venderID,
			number => $index,
			name => $item->{name},
			amount => $item->{amount},
			price => $item->{price},
			upgrade => $item->{upgrade},
			cards => $item->{cards},
			type => $item->{type},
			id => $item->{nameID},
			options => $item->{options}
		});

		message(swrite(
			"@<< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< @<<<<<<<<<< @>>>>> @>>>>>>>>>>>>z",
			[$index, itemName($item), $itemTypes_lut{$item->{type}}, formatNumber($item->{amount}), formatNumber($item->{price})]),
			($config{showDomain_Shop}?$config{showDomain_Shop}:"list"));
	}
	message("-------------------------------------------------------------------------------\n", ($config{showDomain_Shop}?$config{showDomain_Shop}:"list"));

	Plugins::callHook('packet_vender_store2', {
		venderID => $venderID,
		itemList => \@venderItemList
	});
}

sub vending_start {
	my ($self, $args) = @_;

	my $msg = $args->{RAW_MSG};
	my $msg_size = unpack("v1",substr($msg, 2, 2));

	#started a shop.
	message TF("Shop '%s' opened!\n", $shop{title}), "success";
	@articles = ();
	# FIXME: why do we need a seperate variable to track how many items are left in the store?
	$articles = 0;

	my $display = center(" $shop{title} ", 79, '-') . "\n" .
		T("#  Name                                       Type        Amount          Price\n");
	for (my $i = 8; $i < $msg_size; $i += 47) {
	    my $item = {};
	    @$item{qw( price number quantity type nameID identified broken upgrade cards options )} = unpack 'V v v C v C C C a8 a25', substr $msg, $i, 47;
		$item->{name} = itemName($item);
	    $articles[delete $item->{number}] = $item;
		$articles++;

		debug ("Item added to Vender Store: $item->{name} - $item->{price} z\n", "vending", 2);

		$display .= swrite(
			"@< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< @<<<<<<<<<< @>>>>> @>>>>>>>>>>>>z",
			[$articles, $item->{name}, $itemTypes_lut{$item->{type}}, formatNumber($item->{quantity}), formatNumber($item->{price})]);
	}
	$display .= ('-'x79) . "\n";
	message $display, "list";
	$shopEarned ||= 0;
}

1;