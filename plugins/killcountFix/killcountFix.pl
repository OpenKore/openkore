package killcountFix;
 
use strict;
use Plugins;
use Settings;
use Globals;
use Utils;
use Misc;
use Log qw(message error warning);
use Network;
use JSON::Tiny qw(from_json to_json);
 
#########
# startup
Plugins::register('killcountFix', 'fixes killcount quest goals on some servers', \&Unload, \&Unload);

my $hooks = Plugins::addHooks(
	['start2',                \&onstart2, undef],
	['quest_mission_updated', \&onUpdate, undef],
	['quest_mission_added',   \&onAdd,    undef]
);

my $filename = "quests_killcount.txt";
my %quests_kill_count;

# onUnload
sub Unload {
	Plugins::delHooks($hooks);
}

sub onstart2 {
	Settings::addTableFile($filename, loader => [\&parseROQuestsKillcount, \%quests_kill_count], mustExist => 0);
}

sub onAdd {
	my ($self, $args) = @_;
	
	return if (exists $questList->{$args->{'questID'}}{'missions'}{$args->{'mission_id'}}{'mob_goal'});
	
	message "[killcountFix] New mission added without goal. Quest id: '".$args->{'questID'}."' | Mob id: '".$args->{'mission_id'}."'\n", "system";
	
	if (exists $quests_kill_count{$args->{'questID'}} && exists $quests_kill_count{$args->{'questID'}}{$args->{'mission_id'}}) {
		$questList->{$args->{'questID'}}{'missions'}{$args->{'mission_id'}}{'mob_goal'} = $quests_kill_count{$args->{'questID'}}{$args->{'mission_id'}};
		message "[killcountFix] Setting hunt goal to '".$quests_kill_count{$args->{'questID'}}{$args->{'mission_id'}}."' using data file information.\n", "system";
	} else {
		message "[killcountFix] Data file has no information on questID '".$args->{'questID'}."' and MobID '".$args->{'mission_id'}."'.\n", "system";
		message "[killcountFix] Data file will be updated once you kill the first mob.\n", "system";
	}
	
	return;
}

sub onUpdate {
	my ($self, $args) = @_;
	if (
	  !exists $quests_kill_count{$args->{'questID'}} ||                                   # Received questID isn't in %quests_kill_count
	  !exists $quests_kill_count{$args->{'questID'}}{$args->{'mission_id'}} ||            # Received mobID from quest questID isn't in %quests_kill_count
	  $quests_kill_count{$args->{'questID'}}{$args->{'mission_id'}} != $args->{'goal'}    # Received quest goal is different from %quests_kill_count
	){
		updateQuestsKillcount(Settings::getTableFilename($filename), $args->{'questID'}, $args->{'mission_id'}, $args->{'goal'});
	}
}

sub parseROQuestsKillcount {
    my $file = shift;
	my $quests_kill_count_ref = shift;
	undef %{$quests_kill_count_ref};

	open FILE, "<:utf8", $file;
	my @lines = <FILE>;
	close(FILE);
	chomp @lines;
	my $jsonString = join('',@lines);

	my %quests = %{from_json($jsonString, { utf8  => 1 } )};

	%$quests_kill_count_ref = %quests;

	return 1;
}

sub updateQuestsKillcount {
	my ($file, $questID, $mission_id, $goal) = @_;

	$quests_kill_count{$questID}{$mission_id} = $goal;

	message "[killcountFix] Updating data file to add or update quest information\n", "system";
	message "[killcountFix] Adding goal of ".$goal." to mobID ".$mission_id." in questID ".$questID."\n", "system";

	open REWRITE, ">:utf8", $file;
	print REWRITE to_json(\%quests_kill_count, {utf8 => 1, pretty => 1});
	close(REWRITE);
}



return 1;
