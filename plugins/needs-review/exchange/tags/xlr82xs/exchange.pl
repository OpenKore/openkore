package itemexchange;

use strict;
use Plugins;
use Globals;
use Settings;


Plugins::register('itemexchange', 'xlr82xs item exchange code.', \&Unload, \&Reload);
Plugins::addHook('AI_pre', \&Called);

sub Unload {
	print "Item Exchange code unloaded.\n";
}

sub Reload {
	print "Item Exchange code reloaded (why?)\n";
}

sub Called {

# This is my really really really funky way of dealing with all the red socks with holes that I constantly pick up
# However, it can just as easily be used to have your bot convert any * herb + empty bottles that it picks up into a potion
# Not much of the real meat is done here (strangly enough) basically, if itemExchange is turned on in config.txt
# and ai_itemExchangeCheck returns true, it'll move to the npc designated by itemExchange_npc in config.txt and talk to them
# The sequence it sends the npc is controlled by itemExchange_steps in config.txt so its easy to set it up to do juice, or potions
# or red socks, or whatever.
#  accepts only one input, "minimum"
# more about that near the sub ;)

	if (($ai_seq[0] eq "" || $ai_seq[0] eq "route") && $config{'itemExchange'} && $config{'itemExchange_npc'} ne "" && itemexchange::Check()) {
		$ai_v{'temp'}{'ai_route_index'} = binFind(\@ai_seq, "route");
		if ($ai_v{'temp'}{'ai_route_index'} ne "") {
			$ai_v{'temp'}{'ai_route_attackOnRoute'} = $ai_seq_args[$ai_v{'temp'}{'ai_route_index'}]{'attackOnRoute'};
		}
		if (!($ai_v{'temp'}{'ai_route_index'} ne "" && $ai_v{'temp'}{'ai_route_attackOnRoute'} <= 1)) {
			unshift @ai_seq, "itemExchange";
			unshift @ai_seq_args, {};
		}
	}

	if ($ai_seq[0] eq "itemExchange" && timeOut(\%{$timeout{'ai_itemExchange'}})) {
		if (!$config{'itemExchange'} || !%{$npcs_lut{$config{'itemExchange_npc'}}}) {
			$ai_seq_args[0]{'done'} = 1;
			last;
		}

		undef $ai_v{'temp'}{'do_route'};
		if ($field{'name'} ne $npcs_lut{$config{'itemExchange_npc'}}{'map'}) {
			$ai_v{'temp'}{'do_route'} = 1;
		} else {
			$ai_v{'temp'}{'distance'} = distance(\%{$npcs_lut{$config{'itemExchange_npc'}}{'pos'}}, \%{$chars[$config{'char'}]{'pos_to'}});
			if ($ai_v{'temp'}{'distance'} > 14) {
				$ai_v{'temp'}{'do_route'} = 1;
			}
		}

		if ($ai_v{'temp'}{'do_route'}) {
			print "Calculating auto-exchange route to: $maps_lut{$npcs_lut{$config{'itemExchange_npc'}}{'map'}.'.rsw'}($npcs_lut{$config{'itemExchange_npc'}}{'map'}): $npcs_lut{$config{'itemExchange_npc'}}{'pos'}{'x'}, $npcs_lut{$config{'itemExchange_npc'}}{'pos'}{'y'}\n";
			injectMessage("Calculating auto-exchange route to: $maps_lut{$npcs_lut{$config{'itemExchange_npc'}}{'map'}.'.rsw'}($npcs_lut{$config{'itemExchange_npc'}}{'map'}): $npcs_lut{$config{'itemExchange_npc'}}{'pos'}{'x'}, $npcs_lut{$config{'itemExchange_npc'}}{'pos'}{'y'}\n") if ($config{'XKore'});
			ai_route(\%{$ai_v{'temp'}{'returnHash'}}, $npcs_lut{$config{'itemExchange_npc'}}{'pos'}{'x'}, $npcs_lut{$config{'itemExchange_npc'}}{'pos'}{'y'}, $npcs_lut{$config{'itemExchange_npc'}}{'map'}, 0, 0, 1, 0, 0, 1);
		}

	} elsif ($config{'itemExchange'}) {
		my $temp = "minimum";
		while (itemexchange::Check($temp)) {
			if ($ai_seq_args[0]{'sentTalk'} <= 1) {
				sendTalk(\$remote_socket, pack("L1",$config{'itemExchange_npc'})) if !$ai_seq_args[0]{'sentTalk'};
				@{$ai_seq_args[0]{'steps'}} = split(/ +/, $config{'itemExchange_steps'});
				$timeout{'ai_itemExchange'}{'time'} = time;
				$ai_seq_args[0]{'sentTalk'}++;
				last;
				$ai_seq_args[0]{'step'} = 0;

			} elsif ($ai_seq_args[0]{'steps'}[$ai_seq_args[0]{'step'}]) {
				if ($ai_seq_args[0]{'steps'}[$ai_seq_args[0]{'step'}] =~ /c/i) {
					sendTalkContinue(\$remote_socket, pack("L1",$config{'itemExchange_npc'}));
					message("Sent Talk Continue.\n", "debug");
				} elsif ($ai_seq_args[0]{'steps'}[$ai_seq_args[0]{'step'}] =~ /n/i) {
					sendTalkCancel(\$remote_socket, pack("L1",$config{'itemExchange_npc'}));
					message("Sent Talk Cancel.\n", "debug");
				} elsif ($ai_seq_args[0]{'steps'}[$ai_seq_args[0]{'step'}] ne "") {
					($ai_v{'temp'}{'arg'}) = $ai_seq_args[0]{'steps'}[$ai_seq_args[0]{'step'}] =~ /r(\d+)/i;
					if ($ai_v{'temp'}{'arg'} ne "") {
						$ai_v{'temp'}{'arg'}++;
						sendTalkResponse(\$remote_socket, pack("L1",$config{'itemExchange_npc'}), $ai_v{'temp'}{'arg'});
						message("Sent Talk Responce ".$ai_v{'temp'}{'arg'}."\n", "debug");
					}
				}
			} else {
				undef @{$ai_seq_args[0]{'steps'}};
			}
			$ai_seq_args[0]{'step'}++;
			$timeout{'ai_itemExchange'}{'time'} = time;
			last;
		}
	}
}

# itemexchange::Check([exchange])
#
# This is where most of the actual calculation for the item exchange is done.
# If $exchange equals "minimum", we only check that we can do
# one exchange (specified by itemExchange_minAmount_x in the config).
# Say we're making something that requires 3 pearls, 2 apples, and 8 empty bottles
# and we only want to go and make this item when we have at least 30 pearls, 20 apples, and 80 empty bottles
# what we would put into config.txt would be:
#
# itemExchange_item_0 Pearl
# itemExchange_amount_0 30
# itemExchange_minAmount_0 3
#
# itemExchange_item_1 Apple
# itemExchange_amount_1 20
# itemExchange_minAmount_1 2
#
# itemExchange_item_2 Empty bottle
# itemExchange_   etc etc etc
#
# If $exchange is not "minimum" it will look to see if we have at least 30 pearls,
# 20 apples, and 80 empty bottles (done very inelligently by cycling through your inventory, seeing if item names match
# what is in your config.txt, and if it does, seeing if the amount is greater than amount)
# if on the other hand you do a itemexchange::Check('minimum'), it does the same thing, except it compares the amounts
# to the minamount specified in config.txt
# maybe at some stage i'll modify it so you can make more than one item, but for now, meh
sub Check {
	my $exchange = $_[0];
	my $failed = 0;
	my $j = 0;

	while ($config{"itemExchange_item_$j"}) {
		last if ($failed);
		last if (!$config{"itemExchange_item_$j"} || !$config{"itemExchange_amount_$j"} || !config{"itemExchange_minAmount_$j"});
		my $amount;

		my $item = $config{"itemExchange_item_$j"};
		if ($exchange eq 'minimum') {
			$amount = $config{"itemExchange_minAmount_$j"};
		} else {
			$amount = $config{"itemExchange_amount_$j"};
		}

		for (my $i = 0; $i < @{$chars[$config{'char'}]{'inventory'}}; $i++) {
			next if (!%{$chars[$config{'char'}]{'inventory'}[$i]} || $chars[$config{'char'}]{'inventory'}[$i]{'equipped'});

			if (lc($chars[$config{'char'}]{'inventory'}[$i]{'name'}) eq lc($item)
			    && $chars[$config{'char'}]{'inventory'}[$i]{'amount'} ne $amount) {
				$failed = 1;
				last;
			}
		}
		$j++;
	}

	if ($failed) {
		return 0;
	} else {
		return 1;
	}
}


return 1;
