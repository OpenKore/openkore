# Unit test for Skill
package SkillTest;

use Test::More;
use Skill;

sub start {
	print "### Starting SkillTest\n";
	Skill::StaticInfo::parseSkillsDatabase_id2handle('SKILL_id_handle.txt');
	Skill::StaticInfo::parseSkillsDatabase_handle2name('skillnametable.txt');
	Skill::StaticInfo::parseSPDatabase("skillssp.txt");
	testStaticInfo();
	testStaticSPInfo();
	testDynamicInfo();
	testUnknownSkills();
	testDuplicateNames();
}

sub testStaticInfo {
	print "Testing static information conversion...\n";
	my $skill = new Skill(name => "Blessing");
	is($skill->getName(), "Blessing");
	is($skill->getIDN(), 34);
	is($skill->getHandle(), "AL_BLESSING");

	$skill = new Skill(name => "blessing");
	is($skill->getName(), "Blessing");
	is($skill->getIDN(), 34);
	is($skill->getHandle(), "AL_BLESSING");

	$skill = new Skill(idn => 5);
	is($skill->getName(), "Bash");
	is($skill->getIDN(), 5);
	is($skill->getHandle(), "SM_BASH");

	$skill = new Skill(handle => "NV_BASIC");
	is($skill->getName(), "Basic Skill");
	is($skill->getIDN(), 1);
	is($skill->getHandle(), "NV_BASIC");
}

sub testStaticSPInfo {
	print "Testing static SP usage information...\n";
	my $skill = new Skill(name => "Blessing");
	is($skill->getSP(1), 28);
	is($skill->getSP(5), 44);
	is($skill->getSP(10), 64);

	my $skill = new Skill(handle => "SM_BASH");
	is($skill->getSP(1), 8);
	is($skill->getSP(5), 8);
	is($skill->getSP(10), 15);
}

sub testDynamicInfo {
	print "Testing dynamic information conversion...\n";
	Skill::DynamicInfo::clear();
	Skill::DynamicInfo::add(42, "MC_MAMMONITE", 3, 5, 1, Skill::TARGET_ENEMY, Skill::OWNER_CHAR);
	Skill::DynamicInfo::add(456, "ABC_COMBO_BREAKER", 4, 15, 20, Skill::TARGET_LOCATION, Skill::OWNER_HOMUN);

	my $skill = new Skill(idn => 42);
	is($skill->getName(), "Mammonite");
	is($skill->getIDN(), 42);
	is($skill->getHandle(), "MC_MAMMONITE");
	is($skill->getSP(1), undef);
	is($skill->getSP(3), 5);
	is($skill->getRange(), 1);
	is($skill->getTargetType, Skill::TARGET_ENEMY);
	is($skill->getOwnerType, Skill::OWNER_CHAR);

	$skill = new Skill(handle => "ABC_COMBO_BREAKER");
	is($skill->getName(), "Combo Breaker");
	is($skill->getIDN(), 456);
	is($skill->getHandle(), "ABC_COMBO_BREAKER");
	is($skill->getSP(1), undef);
	is($skill->getSP(4), 15);
	is($skill->getRange(), 20);
	is($skill->getTargetType, Skill::TARGET_LOCATION);
	is($skill->getOwnerType, Skill::OWNER_HOMUN);

	$skill = new Skill(name => "Mammonite");
	is($skill->getName(), "Mammonite");
	is($skill->getIDN(), 42);
	is($skill->getHandle(), "MC_MAMMONITE");
	is($skill->getSP(1), undef);
	is($skill->getSP(3), 5);
	is($skill->getRange(), 1);
	is($skill->getTargetType, Skill::TARGET_ENEMY);
	is($skill->getOwnerType, Skill::OWNER_CHAR);
}

sub testDuplicateNames {
	print "Testing duplicate skill names...\n";
	Skill::DynamicInfo::clear;
	Skill::DynamicInfo::add(9001, 'DUP_BLESSING', 3, 5, 1, Skill::TARGET_ACTORS, Skill::OWNER_CHAR);
	
	my $skill = new Skill(name => 'Blessing');
	is($skill->getName, 'Blessing (DUP_BLESSING)');
	is($skill->getIDN, 9001);
	is($skill->getHandle, 'DUP_BLESSING');
	
	$skill = new Skill(name => 'Blessing (DUP_BLESSING)');
	is($skill->getName, 'Blessing (DUP_BLESSING)');
	is($skill->getIDN, 9001);
	is($skill->getHandle, 'DUP_BLESSING');
	
	Skill::DynamicInfo::add(34, 'AL_BLESSING', 3, 5, 1, Skill::TARGET_ACTORS, Skill::OWNER_CHAR);
	
	$skill = new Skill(name => 'Blessing');
	is($skill->getName, 'Blessing');
	is($skill->getIDN, 34);
	is($skill->getHandle, 'AL_BLESSING');
	
	$skill = new Skill(name => 'Blessing (AL_BLESSING)');
	is($skill->getName, 'Blessing');
	is($skill->getIDN, 34);
	is($skill->getHandle, 'AL_BLESSING');
	
	$skill = new Skill(name => 'Blessing (DUP_BLESSING)');
	is($skill->getName, 'Blessing (DUP_BLESSING)');
	is($skill->getIDN, 9001);
	is($skill->getHandle, 'DUP_BLESSING');
}

sub testUnknownSkills {
	print "Testing unknown skills...\n";
	my $skill = new Skill(handle => "UNKNOWN");
	is($skill->getName(), "Unknown");
	is($skill->getIDN(), undef);
	is($skill->getHandle(), undef);
	is($skill->getSP(1), undef);

	$skill = new Skill(idn => 1234);
	is($skill->getName(), "Unknown 1234");
	is($skill->getIDN(), 1234);
	is($skill->getHandle(), undef);
	is($skill->getSP(1), undef);
}

1;
