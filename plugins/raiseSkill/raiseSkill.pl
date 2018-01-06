package raiseSkill;

use strict;
use Plugins;
use Utils;
use Skill;
use Globals qw(%config $net $char $messageSender);
use Log qw(message debug error);
use Settings qw(%sys);
use Translation;

my $translator = new Translation("$Plugins::current_plugin_folder/po", $sys{locale});

Plugins::register('raiseSkill', $translator->translate('automatically raise character skills'), \&on_unload);

################################################################
#  Hooks used to activate the plugin during initialization
#  and on config change events.
my $base_hooks = Plugins::addHooks(
	['start3',        \&checkConfig],
	['postloadfiles', \&checkConfig],
    ['configModify',  \&on_configModify]
   );

my @skills_to_add;
my $waiting_hooks;
my $adding_hook;
my $next_skill;
my $status;
my $timeout = { time => 0, timeout => 1 };

use constant {
	INACTIVE => 0,
	AWAITING_CHANCE_OR_ANSWER => 1,
	ADDING => 2
};

sub on_unload {
   Plugins::delHook($base_hooks);
   changeStatus(INACTIVE);
   message $translator->translate("[raiseSkill] Plugin unloading or reloading\n"), 'success';
}

################################################################
#  changeStatus() is the function responsible for adding
#  and deleting hooks when changing plugin status.
#  During status == 0 the plugin will be inactive and won't
#  look for opportunities to raise skills.
#  During status == 1 the plugin will be active and will
#  have 'speculative' hooks added to try to look for
#  opportunities to raise skills, during this phase plugin
#  will also be awaiting for an answer after we sent a
#  raise request to server.
#  During status == 2 the plugin will be active and will
#  have 'AI_pre' hook active, on each AI call the plugin
#  will try to raise skills if possible.
sub changeStatus {
	my $new_status = shift;
	Plugins::delHook($waiting_hooks) if ($status == AWAITING_CHANCE_OR_ANSWER);
	Plugins::delHook($adding_hook) if ($status == ADDING);
	if ($new_status == INACTIVE) {
		undef $next_skill;
		undef @skills_to_add;
		debug $translator->translate("[raiseSkill] Plugin stage changed to 'INACTIVE'\n");
	} elsif ($new_status == AWAITING_CHANCE_OR_ANSWER) {
		$waiting_hooks = Plugins::addHooks(
			['packet_charSkills', \&on_possible_raise_chance_or_answer],
			['packet_homunSkills', \&on_possible_raise_chance_or_answer],
			['packet/stat_info', \&on_possible_raise_chance_or_answer], # 12 is points_skill
		);
		debug $translator->translate("[raiseSkill] Plugin stage changed to 'AWAITING_CHANCE_OR_ANSWER'\n");
	} elsif ($new_status == ADDING) {
		$adding_hook = Plugins::addHooks(
			['AI_pre',            \&on_ai_pre]
		);
		debug $translator->translate("[raiseSkill] Plugin stage changed to 'ADDING'\n");
	}
	$status = $new_status;
}

################################################################
#  on_possible_raise_chance_or_answer() is the function called by
#  our 'speculative' hooks to try to look for
#  opportunities to raise skills or server answers to our raise
#  requests. It changes the plugin status to 'ADDING' (2).
sub on_possible_raise_chance_or_answer {
	my $hookName = shift;
	my $args = shift;
	return if ($hookName eq 'packet/stat_info' && $args && $args->{type} != 12);
	debug $translator->translate("[raiseSkill] Received a raise chance or answer\n");
	changeStatus(ADDING);
}

################################################################
#  getNextSkill() is the function responsible for deciding
#  which skill we need to raise next, according to
#  '@skills_to_add', if we still have skills to raise, set it
#  to '$next_skill' and return 1, if we have no skills to raise
#  return 0.
sub getNextSkill {
	foreach my $skill (@skills_to_add) {
		my $char_skill_level = $char->getSkillLevel($skill);
		my $wanted_skill_level = $skill->getLevel;
		if ($char_skill_level < $wanted_skill_level) {
			$next_skill = $skill;
			debug $translator->translatef("[raiseSkill] Decided next skill to raise: '%s'\n", $next_skill);
			return 1;
		}
	}
	message $translator->translate("[raiseSkill] No more skills to raise; disabling skillsAddAuto\n"), 'success';
	return 0;
}

################################################################
#  hasFreeSkillPoint() is the function responsible for checking if
#  we have free skill points.
sub hasFreeSkillPoint {
	$char->{points_skill};
}

################################################################
#  on_ai_pre() is called by 'AI_pre' (duh) when status is
#  'ADDING' (2), it checks if we can raise our next skill, and
#  if we can't, change plugin status, otherwise calls raiseSkill()
sub on_ai_pre {
	return if !$char;
	return if $net->getState != Network::IN_GAME;
	return if !timeOut( $timeout );
	$timeout->{time} = time;
	return changeStatus(INACTIVE) unless (getNextSkill());
	unless (hasFreeSkillPoint()) {
		debug $translator->translate("[raiseSkill] We don't have any free skill point\n");
		return changeStatus(AWAITING_CHANCE_OR_ANSWER);
	}
	debug $translator->translate("[raiseSkill] We have free skill points\n");
	unless (canRaiseFurther()) {
		debug $translator->translatef("[raiseSkill] Skill '%s' cannot be raised further\n", $next_skill->getName);
		return changeStatus(INACTIVE);
	}
	debug $translator->translatef("[raiseSkill] We can raise '%s' further\n", $next_skill->getName);
	raiseSkill();
	changeStatus(AWAITING_CHANCE_OR_ANSWER);
}

sub canRaiseFurther {
	if (!$char->{skills}{$next_skill->getHandle()}) {
		error $translator->translatef("[raiseSkill] Skill '%s' does not exist in your skill tree; disabling skillsAddAuto\n", $next_skill->getName);
		return 0;
	} elsif ($char->{skills}{$next_skill->getHandle()}{up} == 0) {
		error $translator->translatef("[raiseSkill] Skill '%s' reached its maximum level or prerequisite not reached; disabling skillsAddAuto\n", $next_skill->getName);
		return 0;
	}
	return 1;
}

################################################################
#  raiseSkill() sends to the server our skill raise request and
#  prints it on console.
sub raiseSkill {
	message $translator->translatef("Auto-adding skill '%s' to '%d'\n", $next_skill->getName, $char->getSkillLevel($next_skill)+1);
	$messageSender->sendAddSkillPoint($next_skill->getIDN);
}

################################################################
#  on_configModify() is called whenever config is changed, it
#  checks if something important to us was changed, and can 
#  change plugin status.
sub on_configModify {
	my (undef, $args) = @_;
	return changeStatus(ADDING) if ($args->{key} eq 'skillsAddAuto' && $args->{val} && $config{skillsAddAuto_list} && validateSteps($config{skillsAddAuto_list}));
	return changeStatus(ADDING) if ($args->{key} eq 'skillsAddAuto_list' && $args->{val} && $config{skillsAddAuto} && validateSteps($args->{val}));
	return changeStatus(INACTIVE) if ($args->{key} eq 'skillsAddAuto_list' || $args->{key} eq 'skillsAddAuto');
}

################################################################
#  checkConfig() is called after config is re(loaded), it
#  checks our configuration on config.txt and changes plugin
#  status.
sub checkConfig {
	return changeStatus(ADDING) if ($config{skillsAddAuto} && $config{skillsAddAuto_list} && validateSteps($config{skillsAddAuto_list}));
	return changeStatus(INACTIVE);
}

################################################################
#  validateSteps() is the function responsible for validating 
#  '$config{skillsAddAuto_list}', return 0 if errors are found
#  and 1 if everything is okay.
sub validateSteps {
	my $list = shift;
	my @steps = split(/\s*,+\s*/, $list);
	undef @skills_to_add;
	foreach my $step (@steps) {
		my ($sk, undef, $level) = $step =~ /^(.*?)(\s+(\d+))?$/;
		my $skill = new Skill(auto => $sk, level => (defined $level) ? $level : 1);
		if ($skill->getIDN) {
			push(@skills_to_add, $skill);
		} else {
			error $translator->translatef("Unknown skill '%s' in '%s'; disabling skillsAddAuto\n", $sk, $step);
			return 0;
		}
	}
	debug $translator->translate("[raiseSkill] Configuration set in config.txt is valid\n");
	return 1;
}


return 1;
