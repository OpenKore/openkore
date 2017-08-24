
########################################
	# Wait4Party v1.5 rev a -- Stick Together Team!
	# ©2008 by Contrad
	#
	# This software is open source, licensed under the GNU General Public
	# License, version 3.
	# Basically, this means that you're allowed to modify and/or distribute
	# this software. However, if you distribute modified versions, you MUST
	# also distribute the source code.
	# See <http://www.gnu.org/licenses/> for the full license.
	#
	# Sep 11, 2010 : add sub emulateCmdSit, fix wait4party_followSit
	# Oct 22, 2010 : change %field into $field
##########################################

package wait4party;
	
	use strict;
	# use warnings;
	# use Data::Dumper;
	
	use Plugins;
	use Globals qw(%config @partyUsersID $playersList $accountID $char $field %ai_v @ai_seq @ai_seq_args %timeout $taskManager);
	use Utils qw(distance timeOut);
	use Utils::DataStructures qw(existsInList);
	use Log qw(message warning error debug);
	use Translation qw/T TF/;
	
	use constant {  NAME => 'wait4party' };
	
	my %findParty;
	my %partySit;
	my @notAI = qw(storageAuto storageGet sellAuto buyAuto attack skill_use);
	
	Plugins::register( NAME, 'Wait for party', \&unload, \&unload);
	my $hooks = Plugins::addHooks(
	['AI_pre', \&waitForOthers, undef],
	['is_casting', \&waitCast, undef]);
	
	sub unload {
        Plugins::delHooks($hooks);
        undef %findParty;
        undef %partySit;
        undef @notAI;
	}
	
	sub waitForOthers {
        return unless ($config{'wait4party'} && @partyUsersID);
		
        my $actor;
        foreach (@partyUsersID) {
			next if (!$_ || $_ eq $accountID
			|| ($config{'wait4party_ignore'} && existsInList("$config{'wait4party_ignore'}", "$char->{'party'}{'users'}{$_}{'name'}"))
			|| ($findParty{ID} && $findParty{ID} ne $_)); # first lost first served
			$actor = $playersList->getByID($_);
			
			# PARTY MISSING!!
			if(!$actor && $char->{'party'}{'users'}{$_}{'online'}) {
				# party Check
				my %party;
				$party{x} = $char->{party}{users}{$_}{pos}{x};
				$party{y} = $char->{party}{users}{$_}{pos}{y};
				($party{map}) = $char->{party}{users}{$_}{map} =~ /([\s\S]*)\.gat/;
				
				if ($party{map} ne $field->baseName() || !$party{'x'} || !$party{'y'}
				|| ($party{'x'} == 0) || ($party{'y'} == 0)) {
					next if $config{'wait4party_sameMapOnly'};
					return unless timeOut($timeout{ai}{time},5);
					
					delete $party{x};
					delete $party{y};
				}
				
				next unless ($party{map} ne $field->baseName || exists $party{x});
				
				# set %findParty when party dissappear from screen
				if (!$findParty{ID}) {
					$findParty{ID} = $_;
					$findParty{time} = time if !$findParty{time};
					$findParty{timeout} = $config{'wait4party_timeout'} if ($config{'wait4party_timeout'});
					
					if ($config{'wait4party_waitBySitting'}) {
						message ("Party (".$char->{party}{users}{$_}{name}.") lost, wait by sitting.\n", "wait4party");
						} else {
						message ("Party (".$char->{party}{users}{$_}{name}.") lost.\n", "wait4party");
					}
					
				}
				
				# notAI
				return if AI::inQueue(@notAI);
				if ($config{'wait4party_waitBySitting'}) {
					emulateCmdSit() if (!$char->{sitting});
					return if (!$findParty{timeout});   # wait by sit forever..
				}
				return if ($findParty{timeout} && !timeOut(\%findParty));
				
				# Search for Party
				if ((exists $ai_v{party} && distance(\%party, $ai_v{party}) > $config{followDistanceMax})
				|| ($party{map} ne $ai_v{party}{map})
				|| ($ai_v{party}{time} && timeOut($ai_v{party}{time}, 15) && distance(\%party, $char->{pos_to}) > $config{followDistanceMax})) {
					$ai_v{party}{x} = $party{x};
					$ai_v{party}{y} = $party{y};
					$ai_v{party}{map} = $party{map};
					$ai_v{party}{time} = time;
					
					if ($ai_v{party}{map} ne $field->baseName) {
						message TF("Calculating route to find %s: %s\n", $char->{party}{users}{$_}{name}, $ai_v{party}{map}), NAME;
						} elsif (distance(\%party, $char->{pos_to}) > $config{followDistanceMax} ) {
						message TF("Calculating route to find %s: %s (%d %d)\n", $char->{party}{users}{$_}{name}, $ai_v{party}{map}, $ai_v{party}{x}, $ai_v{party}{y}), NAME;
						} else {
						return;
					}
					
					AI::clear("move", "route", "mapRoute");
					AI::ai_route($ai_v{party}{map}, $ai_v{party}{x}, $ai_v{party}{y}, distFromGoal => $config{followDistanceMin}, attackOnRoute => $config{'wait4party_attackOnSearch'});
					return;
				}
				
                # party found
                } elsif ($findParty{ID} eq $_) {
				%findParty = (); ## undef findParty!!
				if (!$char->{'party'}{'users'}{$_}{'online'}) {
					message TF("Party member %s is offline\n", $char->{party}{users}{$_}{name}), NAME;
					AI::clear("route");
					return;
				}
				Commands::cmdStand() if ($char->{sitting} && !$partySit{ID});
				message TF("Party member %s found!\n", $char->{party}{users}{$_}{name}), NAME;
				
                ## party sit?
                } elsif ($actor && $config{'wait4party_followSit'} && !(AI::inQueue(@notAI)) && AI::action ne "sitAuto") {
				# Salah trigger??
				if ($actor->{sitting} && !$partySit{ID}) {
					emulateCmdSit() if (!$char->{sitting});
					message TF ("Party member %s sit\n", $actor->{name}), NAME;
					%partySit = ( 'ID' => $actor->{ID}, 'time' => time, 'timeout' => 10 );
					
					} elsif ($partySit{ID} && $actor->{ID} eq $partySit{ID} && timeOut(\%partySit)) {
					if ($actor->{sitting}) {
						emulateCmdSit() if (!$char->{sitting});
						$partySit{'time'} = time;
						$partySit{'timeout'} = 5;
						
						} elsif (!$actor->{sitting}) {
						Commands::cmdStand();
						message TF("Party member %s stand\n", $actor->{name}), NAME;
						%partySit = ();
						return;
					}
					
					if (!$char->{'party'}{'users'}{$_}{'online'}) {
						Commands::cmdStand();
						message TF("Party member %s is offline\n", $actor->{name}), NAME;
						%partySit = ();
						return;
					}
				}
			}
		}
        return;
	}
	
	sub waitCast {
        return unless ($config{'wait4party'}
		&& $config{'wait4party_cast'}
		&& @partyUsersID
		&& AI::action eq "route" && !AI::inQueue("attack"));
		
        my (undef,$actor) = @_;
        return unless existsInList($config{'wait4party_cast'}, $actor->{skill}->getName());
		
        foreach (@partyUsersID) {  
			next if (!$_ || $_ ne $actor->{sourceID} || $_ eq $accountID
			|| ($config{'wait4party_ignore'} && existsInList("$config{'wait4party_ignore'}", "$char->{'party'}{'users'}{$_}{'name'}")));
			my $wait = int($actor->{castTime} * 0.001 + 1) + 1;
			message TF("Party member %s is casting %s, wait %d seconds\n",
			$char->{party}{users}{$_}{name}, $actor->{skill}->getName(), $wait), NAME;
			
			# can't find better idea to suspend AI other than this
			AI::clear("clientSuspend");
			AI::ai_clientSuspend(0, $wait);
			return;
		}
	}
	
	# Note:
		# Copied from Commands::cmdSit
	# change AI::ai_getAggresives() to AI::ai_getAggressives(1,1) -> react for party aggressive monster?
	sub emulateCmdSit {
        $ai_v{sitAuto_forcedBySitCommand} = 1;
        AI::clear("move", "route", "mapRoute");
        AI::clear("attack") unless AI::ai_getAggressives(1,1);
        require Task::SitStand;
        my $task = new Task::ErrorReport(
		task => new Task::SitStand(
		mode => 'sit',
		priority => Task::USER_PRIORITY
		)
        );
        $taskManager->add($task);
        $ai_v{sitAuto_forceStop} = 0;
	}
	
1;