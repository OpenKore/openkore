package Interface::Wx::Window::ConfigEditor;
use strict;

use Wx ':everything';
use Wx::Event ':everything';
use base 'Wx::Panel';

use Interface::Wx::Base::ConfigEditor;

use Globals qw/%config/;
use Misc qw/configModify/;
use Translation qw/T TF/;

sub new {
	my ($class, $parent, $id) = @_;

	my $self = $class->SUPER::new($parent, $id);

	my $vsizer = new Wx::BoxSizer(wxVERTICAL);
	$self->SetSizer($vsizer);

	my $cfg = new Interface::Wx::Base::ConfigEditor($self, wxID_ANY);
	$cfg->setConfig(\%config);
	$cfg->addCategory('All', 'Grid');
	$cfg->addCategory('server', 'Grid', ['master', 'server', 'username', 'password', 'char', 'serverType']);
	$cfg->addCategory('X-Kore', 'Grid', ['XKore', 'XKore_silent', 'XKore_bypassBotDetection', 'XKore_exeName', 'XKore_listenIp', 'XKore_listenPort', 'XKore_publicIp', 'secureAdminPassword', 'adminPassword', 'callSign', 'commandPrefix']);
	$cfg->addCategory('lockMap', 'Grid', ['lockMap', 'lockMap_x', 'lockMap_y', 'lockMap_randX', 'lockMap_randY']);
	$cfg->addCategory('attack', 'Grid', ['attackAuto', 'attackAuto_party', 'attackAuto_onlyWhenSafe', 'attackAuto_followTarget', 'attackAuto_inLockOnly', 'attackDistance', 'attackDistanceAuto', 'attackMaxDistance', 'attackMaxRouteDistance', 'attackMaxRouteTime', 'attackMinPlayerDistance', 'attackMinPortalDistance', 'attackUseWeapon', 'attackNoGiveup', 'attackCanSnipe', 'attackCheckLOS', 'attackLooters', 'attackChangeTarget', 'aggressiveAntiKS']);
	$cfg->addCategory('route', 'Grid', ['route_escape_reachedNoPortal', 'route_escape_randomWalk', 'route_escape_shout', 'route_randomWalk', 'route_randomWalk_inTown', 'route_randomWalk_maxRouteTime', 'route_maxWarpFee', 'route_maxNpcTries', 'route_teleport', 'route_teleport_minDistance', 'route_teleport_maxTries', 'route_teleport_notInMaps', 'route_step']);
	$cfg->addCategory('teleport', 'Grid', ['teleportAuto_hp', 'teleportAuto_sp', 'teleportAuto_idle', 'teleportAuto_portal', 'teleportAuto_search', 'teleportAuto_minAggressives', 'teleportAuto_minAggressivesInLock', 'teleportAuto_onlyWhenSafe', 'teleportAuto_maxDmg', 'teleportAuto_maxDmgInLock', 'teleportAuto_deadly', 'teleportAuto_useSkill', 'teleportAuto_useChatCommand', 'teleportAuto_allPlayers', 'teleportAuto_atkCount', 'teleportAuto_atkMiss', 'teleportAuto_unstuck', 'teleportAuto_dropTarget', 'teleportAuto_dropTargetKS', 'teleportAuto_attackedWhenSitting', 'teleportAuto_totalDmg', 'teleportAuto_totalDmgInLock', 'teleportAuto_equip_leftAccessory', 'teleportAuto_equip_rightAccessory', 'teleportAuto_lostHomunculus']);
	$cfg->addCategory('follow', 'Grid', ['follow', 'followTarget', 'followEmotion', 'followEmotion_distance', 'followFaceDirection', 'followDistanceMax', 'followDistanceMin', 'followLostStep', 'followSitAuto', 'followBot']);
	$cfg->addCategory('items', 'Grid', ['itemsTakeAuto', 'itemsTakeAuto_party', 'itemsGatherAuto', 'itemsMaxWeight', 'itemsMaxWeight_sellOrStore', 'itemsMaxNum_sellOrStore', 'cartMaxWeight']);
	$cfg->addCategory('sellAuto', 'Grid', ['sellAuto', 'sellAuto_npc', 'sellAuto_standpoint', 'sellAuto_distance']);
	$cfg->addCategory('storageAuto', 'Grid', ['storageAuto', 'storageAuto_npc', 'storageAuto_distance', 'storageAuto_npc_type', 'storageAuto_npc_steps', 'storageAuto_password', 'storageAuto_keepOpen', 'storageAuto_useChatCommand', 'relogAfterStorage']);
	$cfg->addCategory('disconnect', 'Grid', ['dcOnDeath', 'dcOnDualLogin', 'dcOnDisconnect', 'dcOnEmptyArrow', 'dcOnMute', 'dcOnPM', 'dcOnZeny', 'dcOnStorageFull', 'dcOnPlayer']);

	$cfg->onChange(sub {
		my ($key, $value) = @_;
		configModify($key, $value) if ($value ne $config{$key});
	});
	$vsizer->Add($cfg, 1, wxGROW | wxALL, 8);


	my $sizer = new Wx::BoxSizer(wxHORIZONTAL);
	$vsizer->Add($sizer, 0, wxGROW | wxLEFT | wxRIGHT | wxBOTTOM, 8);

	my $revert = new Wx::Button($self, 46, T('&Revert'));
	$revert->SetToolTip(T('Revert settings to before you opened the selected category'));
	$sizer->Add($revert, 0);
	EVT_BUTTON($revert, 46, sub {
		$cfg->revert;
	});
	$revert->Enable(0);
	$cfg->onRevertEnable(sub {
		$revert->Enable($_[0]);
	});

	my $pad = new Wx::Window($self, wxID_ANY);
	$sizer->Add($pad, 1);

=pod
	my $close = new Wx::Button($self, 47, T('&Close'));
	$close->SetToolTip(T('Close this panel/dialog'));
	$close->SetDefault;
	$sizer->Add($close, 0);
	EVT_BUTTON($close, 47, sub {
		$self->{notebook}->closePage('Advanced Configuration');
	});
=cut

	return $self;
}

1;
