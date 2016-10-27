package killcountFix;
 
use strict;
use Plugins;
use Settings;
use Globals;
use Utils;
use Misc;
use Log qw(message error warning);
use Network;
use JSON;
 
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
	
	if (exists $quests_kill_count{$args->{'questID'}} && exists $quests_kill_count{$args->{'questID'}}{$args->{'mobID'}}) {
		$questList->{$args->{'questID'}}{'missions'}{$args->{'mobID'}}{'goal'} = $quests_kill_count{$args->{'questID'}}{$args->{'mobID'}};
		message "[killcountFix] New mission without goal. Quest id: '".$args->{'questID'}."' | Mob id: '".$args->{'mobID'}."'\n", "system";
		message "[killcountFix] Setting goal to saved info '".$quests_kill_count{$args->{'questID'}}{$args->{'mobID'}}."'\n", "system";
	}
	
	return;
}

sub onUpdate {
	my ($self, $args) = @_;
	if (!exists $quests_kill_count{$args->{'questID'}}             #received questID isn't in %quests_kill_count
		|| !exists $quests_kill_count{$args->{'questID'}}{$args->{'mobID'}}      #received mobID from quest questID isn't in %quests_kill_count
		|| $quests_kill_count{$args->{'questID'}}{$args->{'mobID'}} != $args->{'goal'}) {  #received quest goal is different from %quests_kill_count
			updateQuestsKillcount(Settings::getTableFilename($filename), $args->{'questID'}, $args->{'mobID'}, $args->{'goal'});
		}
		#received quest goal is the same as in %quests_kill_count
	return;
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
	my ($file, $questID, $mobID, $goal) = @_;

	$quests_kill_count{$questID}{$mobID} = $goal;

	message "[killcountFix] Updating file to add new info\n", "system";
	message "[killcountFix] Adding goal of ".$goal." to mobID ".$mobID." in quest ".$questID."\n", "system";

	open REWRITE, ">:utf8", $file;
	print REWRITE to_json(\%quests_kill_count, {utf8 => 1, pretty => 1});
	close(REWRITE);
}



return 1;
