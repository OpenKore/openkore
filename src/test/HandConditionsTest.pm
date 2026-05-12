package HandConditionsTest;

use strict;
use Test::More;
use Globals;
use Task;
use Actor::You;
use Actor::Item;
use Misc;

sub start {
	note('Starting ' . __PACKAGE__);
	__PACKAGE__->new->run;
}

sub new {
	return bless {}, $_[0];
}

sub run {
	my ($self) = @_;

	$self->testRightHandTypeAndEmptyConditions;
	$self->testLeftHandTypeAndEmptyConditions;
	$self->testFistMatchesEmptyHand;
}

sub testRightHandTypeAndEmptyConditions {
	local %Globals::config = (
		handtest_manualAI => 2,
		handtest_whenEquip_Right_Hand_Type => '2hSword',
		handtest_whenEquip_Right_Hand_Empty => 1,
	);
	local %Misc::config = %Globals::config;
	local %Globals::itemHandType_lut = (
		1105 => {
			itemID => 1105,
			aegisName => 'Blade',
			type => '2hSword',
		},
	);
	local %Misc::itemHandType_lut = %Globals::itemHandType_lut;
	local $Globals::char = Actor::You->new;
	local $Misc::char = $Globals::char;

	$Globals::char->{equipment}{rightHand} = _build_item(1105);

	ok(Misc::checkSelfCondition('handtest'), 'matches occupied right hand and right hand type');

	$Globals::config{handtest_whenEquip_Right_Hand_Type} = 'Dagger';
	$Misc::config{handtest_whenEquip_Right_Hand_Type} = 'Dagger';
	ok(!Misc::checkSelfCondition('handtest'), 'fails when right hand type does not match');

	$Globals::config{handtest_whenEquip_Right_Hand_Type} = '2hSword';
	$Globals::config{handtest_whenEquip_Right_Hand_Empty} = 0;
	$Misc::config{handtest_whenEquip_Right_Hand_Type} = '2hSword';
	$Misc::config{handtest_whenEquip_Right_Hand_Empty} = 0;
	ok(!Misc::checkSelfCondition('handtest'), 'fails when occupied right hand is expected to be empty');
}

sub testLeftHandTypeAndEmptyConditions {
	local %Globals::config = (
		handtest_manualAI => 2,
		handtest_whenEquip_Left_Hand_Type => 'Shield',
		handtest_whenEquip_Left_Hand_Empty => 1,
	);
	local %Misc::config = %Globals::config;
	local %Globals::itemHandType_lut = (
		2112 => {
			itemID => 2112,
			aegisName => 'Novice_Guard',
			type => 'Shield',
		},
	);
	local %Misc::itemHandType_lut = %Globals::itemHandType_lut;
	local $Globals::char = Actor::You->new;
	local $Misc::char = $Globals::char;

	$Globals::char->{equipment}{leftHand} = _build_item(2112);

	ok(Misc::checkSelfCondition('handtest'), 'matches occupied left hand and shield type');

	$Globals::config{handtest_whenEquip_Left_Hand_Type} = 'Katar';
	$Misc::config{handtest_whenEquip_Left_Hand_Type} = 'Katar';
	ok(!Misc::checkSelfCondition('handtest'), 'fails when left hand type does not match');

	$Globals::config{handtest_whenEquip_Left_Hand_Type} = 'Shield';
	$Globals::config{handtest_whenEquip_Left_Hand_Empty} = 0;
	$Misc::config{handtest_whenEquip_Left_Hand_Type} = 'Shield';
	$Misc::config{handtest_whenEquip_Left_Hand_Empty} = 0;
	ok(!Misc::checkSelfCondition('handtest'), 'fails when occupied left hand is expected to be empty');
}

sub testFistMatchesEmptyHand {
	local %Globals::config = (
		handtest_manualAI => 2,
		handtest_whenEquip_Right_Hand_Type => 'Fist',
		handtest_whenEquip_Right_Hand_Empty => 0,
		handtest_whenEquip_Left_Hand_Type => 'Fist',
		handtest_whenEquip_Left_Hand_Empty => 0,
	);
	local %Misc::config = %Globals::config;
	local %Globals::itemHandType_lut = ();
	local %Misc::itemHandType_lut = %Globals::itemHandType_lut;
	local $Globals::char = Actor::You->new;
	local $Misc::char = $Globals::char;

	ok(Misc::checkSelfCondition('handtest'), 'treats empty hands as Fist for type checks');

	$Globals::config{handtest_whenEquip_Right_Hand_Empty} = 1;
	$Misc::config{handtest_whenEquip_Right_Hand_Empty} = 1;
	ok(!Misc::checkSelfCondition('handtest'), 'empty condition still distinguishes empty from occupied');
}

sub _build_item {
	my ($name_id) = @_;
	my $item = Actor::Item->new;
	$item->{nameID} = $name_id;
	$item->{equipped} = 1;
	return $item;
}

1;
