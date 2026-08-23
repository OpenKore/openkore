# Unit test for Network
package NetworkTest;

use strict;
use FindBin qw($RealBin);
use File::Spec;
use Test::More;
use Time::HiRes qw(time);
use FileParsers qw(parseRecvpackets);
use Actor::NPC;
use ActorList;
use InventoryList;
use Misc;
use Network::MessageTokenizer;
use Network::Receive;
use Network::Send;
use Task::TalkNPC;
use Globals qw($masterServer $messageSender %rpackets %timeout %ai_v %talk @ai_seq $storeList);

sub with_master_server {
	my ($server, $code) = @_;
	my $previous = $masterServer;
	my $context = wantarray;
	my (@result, $result, $ok, $error);

	$masterServer = $server;
	$ok = eval {
		if (!defined $context) {
			$code->();
		} elsif ($context) {
			@result = $code->();
		} else {
			$result = $code->();
		}
		1;
	};
	$error = $@;
	$masterServer = $previous;
	die $error unless $ok;
	return $context ? @result : $result;
}

sub with_timeout_entries {
	my ($keys, $code) = @_;
	my %previous;
	my $context = wantarray;
	my (@result, $result, $ok, $error);

	for my $key (@$keys) {
		my $value = $timeout{$key};
		$previous{$key} = [
			exists $timeout{$key},
			ref $value eq 'HASH' ? { %$value } : $value,
		];
	}

	$ok = eval {
		if (!defined $context) {
			$code->();
		} elsif ($context) {
			@result = $code->();
		} else {
			$result = $code->();
		}
		1;
	};
	$error = $@;
	for my $key (@$keys) {
		my ($exists, $value) = @{$previous{$key}};
		$exists ? ($timeout{$key} = $value) : delete $timeout{$key};
	}
	die $error unless $ok;
	return $context ? @result : $result;
}

sub with_message_sender {
	my ($sender, $code) = @_;
	my $previous = $messageSender;
	my $context = wantarray;
	my (@result, $result, $ok, $error);

	$messageSender = $sender;
	$ok = eval {
		if (!defined $context) {
			$code->();
		} elsif ($context) {
			@result = $code->();
		} else {
			$result = $code->();
		}
		1;
	};
	$error = $@;
	$messageSender = $previous;
	die $error unless $ok;
	return $context ? @result : $result;
}

sub with_recvpackets_file {
	my ($file, $code) = @_;
	my %previous = map { $_ => { %{$rpackets{$_}} } } keys %rpackets;
	my $context = wantarray;
	my (@result, $result, $ok, $error);

	parseRecvpackets($file, \%rpackets);
	$ok = eval {
		if (!defined $context) {
			$code->();
		} elsif ($context) {
			@result = $code->();
		} else {
			$result = $code->();
		}
		1;
	};
	$error = $@;
	%rpackets = %previous;
	die $error unless $ok;
	return $context ? @result : $result;
}

sub lastro_recvpackets_file {
	return File::Spec->catfile(
		$RealBin, 'tables', 'kRO', 'Ragexe_2021_11_03', 'recvpackets.txt'
	);
}

sub choose_lastro_airship_route_map {
	return unless eval { require Lastro::Airship; 1 };
	return Lastro::Airship::chooseRouteMap(@_);
}

sub start {
	my %tests = (
		'Network::Receive' => [
			{
				switches => ['quest_update_mission_hunt'],
				mobs => [
					{questID => 1001, mobID => 2001, count => 10},
					{questID => 1002, mobID => 2002, count => 100},
				]
			},
		],
		'Network::Send' => [
			{
				switches => ['reconstruct_master_login', 'parse_master_login'],
				version => 1,
				master_version => 123456,
				username => 'username',
				password => 'password',
			},
			{
				switches => ['reconstruct_buy_bulk_vender', 'parse_buy_bulk_vender'],
				items => [
					{itemIndex => 0, amount => 1},
					{itemIndex => 2, amount => 30000},
				]
			},
		],
	);

	for my $serverType (qw(
		0
		bRO
		cRO
		idRO
		iRO
		kRO
		rRO
		Sakray
		tRO
		twRO
		Zero
		kRO_RagexeRE_0
	)) {
		subtest "serverType $serverType" => sub {
			for my $module (keys %tests) {
				SKIP: {
					# kRO has too many base classes (more than 100), and perl dies trying to load it
					skip 'known to be broken', 1 if $serverType =~ /^(rRO)$/;
					my $instance = eval { $module->create(undef, $serverType) };
					ok($instance, "create $module") or skip 'failed', 1;

					skip 'broken packet_list', 1 if $serverType =~ /^(rRO)$/;

					for (keys %{$instance->{packet_lut}}) {
						subtest sprintf('$_{packet_list}{$_{packet_lut}{%s}}', $_) => sub { SKIP: {
							ok(my $handler = $instance->{packet_list}{$instance->{packet_lut}{$_}}, 'exists') or skip 'failed', 1;
							is($_, $handler->[0], 'matches');
							done_testing();
						}}
					}

					# do not test kRO tree further
					next if $serverType =~ /^kRO/;

					for my $expected (@{$tests{$module}}) {
						subtest "@{$expected->{switches}}" => sub { SKIP: {
							my @callbacks;

							subtest 'callbacks exist' => sub {
								for my $switch (@{$expected->{switches}}) {
									ok(push @callbacks, $instance->can($switch), $switch);
								}
								done_testing();
							} or skip 'failed', 1;
							
							if ( $serverType =~ /^(bRO|idRO|tRO)$/) { # different login packet. Parser is not implemented 2021-02-15
								done_testing();
								next;
							}
							my $got = Storable::dclone($expected);
							for my $callback (@callbacks) {
								$instance->$callback($got);
							}

							# there may be additional keys after reconstruct_callback
							$got = reduce_struct($got, $expected);					
							is_deeply($got, $expected, 'test data');
							done_testing();
						}}
					}
				}
			}
			done_testing();
		}
	}

	subtest 'ServerType0 uses configured client type in 0065' => sub {
		with_master_server({
			clientType => 3,
			ip => '43.248.3.48',
		}, sub {

			my $instance = Network::Send->create(undef, 0);
			my $packet = $instance->reconstruct({
				switch => 'game_login',
				accountID => pack('V', 1),
				sessionID => pack('V', 2),
				sessionID2 => pack('V', 3),
				accountSex => 0,
				iAccountSID => 0,
			});

			is(unpack('v', substr($packet, 14, 2)), 3,
				'0065 client type comes from the server configuration');
		});
		done_testing();
	};

	subtest 'Lastro 0436 matches the browser enter packet' => sub {
		with_master_server({
			serverType => 'kRO_RagexeRE_2021_11_03',
			sendCryptKeys => '0x47DA30BB, 0x234A5224, 0x1B013ABC',
		}, sub {

			my $net = NetworkTest::FakeNet->new;
			my $instance = Network::Send->create($net, 'kRO_RagexeRE_2021_11_03');
			$instance->cryptKeys(0x47DA30BB, 0x234A5224, 0x1B013ABC);
			$instance->sendMapLogin(pack('V', 1), pack('V', 2), pack('V', 3), 0);

			my $packet = $net->{sent}[0];
			is(unpack('v', $packet), 0x447D, '0436 uses the browser PacketCrypt header');
			is(length($packet), 23, '0436 has the browser packet length');
			is(substr($packet, 14, 8), "\0" x 8,
				'0436 leaves the browser reserved/client-time fields at zero');
		});
		done_testing();
	};

	subtest 'Lastro starts browser-equivalent timers on map login' => sub {
		with_timeout_entries([qw(ai_sync ai_move_retry)], sub {
			$timeout{ai_sync} = {timeout => 1, time => 0};
			$timeout{ai_move_retry} = {timeout => 1};

			with_master_server({
				serverType => 'kRO_RagexeRE_2021_11_03',
				sendCryptKeys => '0x47DA30BB, 0x234A5224, 0x1B013ABC',
			}, sub {
				my $net = NetworkTest::FakeNet->new;
				my $instance = Network::Send->create($net, 'kRO_RagexeRE_2021_11_03');
				$instance->cryptKeys(0x47DA30BB, 0x234A5224, 0x1B013ABC);
				$instance->sendMapLogin(pack('V', 1), pack('V', 2), pack('V', 3), 0);
			});

			is($timeout{ai_sync}{timeout}, 15,
				'periodic sync uses the browser 15-second interval');
			ok($timeout{ai_sync}{time},
				'periodic sync interval starts at map login');
			is($timeout{ai_move_retry}{timeout}, 0.5,
				'movement retry uses the browser 500-millisecond cadence');
		});
		done_testing();
	};

	subtest 'Lastro movement and repeated attack match browser packet bytes' => sub {
		with_master_server({
			serverType => 'kRO_RagexeRE_2021_11_03',
			sendCryptKeys => '0x47DA30BB, 0x234A5224, 0x1B013ABC',
		}, sub {
			my $net = NetworkTest::FakeNet->new;
			my $instance = Network::Send->create($net, 'kRO_RagexeRE_2021_11_03');
			$instance->cryptKeys(0x47DA30BB, 0x234A5224, 0x1B013ABC);
			$instance->sendMapLogin(pack('V', 1), pack('V', 2), pack('V', 3), 0);
			$instance->sendMapLoaded;
			$instance->sendMove(187, 336);
			$instance->sendAction(pack('V', 0x01020304), 7);

			is(unpack('H*', $net->{sent}[3]), '046b2ed500',
				'035F move matches browser coordinate packing and PacketCrypt state');
			is(unpack('H*', $net->{sent}[4]), '35780403020107',
				'0437 repeated attack matches browser layout and PacketCrypt state');
		});
		done_testing();
	};

	subtest 'Lastro does not send blocking-player cancel packets' => sub {
		with_master_server({
			serverType => 'kRO_RagexeRE_2021_11_03',
			sendCryptKeys => '0x47DA30BB, 0x234A5224, 0x1B013ABC',
		}, sub {
			my $net = NetworkTest::FakeNet->new;
			my $instance = Network::Send->create($net, 'kRO_RagexeRE_2021_11_03');
			$instance->cryptKeys(0x47DA30BB, 0x234A5224, 0x1B013ABC);
			$instance->sendBlockingPlayerCancel;

			is(scalar @{$net->{sent}}, 0,
				'0447 is not emitted by the browser-compatible sender');
		});
		done_testing();
	};

	subtest 'Lastro private airship matches the browser direct-map request' => sub {
		with_recvpackets_file(lastro_recvpackets_file(), sub {
		with_master_server({
			serverType => 'kRO_RagexeRE_2021_11_03',
			lastroAirship => 1,
			sendCryptKeys => '0x47DA30BB, 0x234A5224, 0x1B013ABC',
		}, sub {
			my $net = NetworkTest::FakeNet->new;
			my $instance = Network::Send->create($net, 'kRO_RagexeRE_2021_11_03');
			$instance->cryptKeys(0x47DA30BB, 0x234A5224, 0x1B013ABC);
			$instance->sendPrivateAirshipRequest('prt_fild08', 14527);

			my $packet = $net->{sent}[0];
			is(length($packet), 34,
				'0A49 uses the browser 34-byte structure');
			SKIP: {
				skip 'full browser structure is not available yet', 2 unless length($packet) == 34;
				is(substr($packet, 2, 16), "prt_fild08\0" . "\0" x 5,
					'0A49 sends the bare map name in a 16-byte field');
				is_deeply([unpack('V4', substr($packet, 18, 16))], [0, 0, 0, 14527],
					'0A49 sends zero x/y/type and Lastro item ID 14527');
			}
		});
		});
		done_testing();
	};

	subtest 'Lastro NPC purchase matches the browser transaction' => sub {
		with_master_server({
			serverType => 'kRO_RagexeRE_2021_11_03',
			sendCryptKeys => '0x47DA30BB, 0x234A5224, 0x1B013ABC',
		}, sub {
			my $net = NetworkTest::FakeNet->new;
			my $sender = Network::Send->create($net, 'kRO_RagexeRE_2021_11_03');
			$sender->cryptKeys(0x47DA30BB, 0x234A5224, 0x1B013ABC);

			with_message_sender($sender, sub {
				completeNpcBuy([{itemID => 1750, amount => 6000}]);
			});

			is(scalar @{$net->{sent}}, 1,
				'NPC purchase sends only the browser purchase packet');
			is(length($net->{sent}[0]), 10,
				'6000-arrow purchase uses the browser packet length');
			is(unpack('H*', substr($net->{sent}[0], 2)), '0a007017d6060000',
				'6000-arrow purchase encodes count as u16 and item ID as u32');
		});
		done_testing();
	};

	subtest 'Lastro auto-follow matches the browser setting packet' => sub {
		with_master_server({
			serverType => 'kRO_RagexeRE_2021_11_03',
			lastroAutoFollow => 1,
			sendCryptKeys => '0x47DA30BB, 0x234A5224, 0x1B013ABC',
		}, sub {
			my $net = NetworkTest::FakeNet->new;
			my $sender = Network::Send->create($net, 'kRO_RagexeRE_2021_11_03');
			$sender->cryptKeys(0x47DA30BB, 0x234A5224, 0x1B013ABC);

			ok($sender->can('sendLastroAutoFollow'),
				'has a sender for the Lastro auto-follow setting') or return;

			for my $case (
				{request => 'on', payload => '2501000000'},
				{request => 'off', payload => '2501000000'},
			) {
				$sender->sendLastroAutoFollow($case->{request});
				my $packet = $net->{sent}[-1];

				is(length($packet), 7,
					"auto-follow $case->{request} uses the browser packet length");
				is(unpack('H*', substr($packet, 2)), $case->{payload},
					"auto-follow $case->{request} uses Lastro's toggle action after PacketCrypt");
			}
		});
		done_testing();
	};

	subtest 'Lastro follow-state packets use browser lengths' => sub {
		with_recvpackets_file(lastro_recvpackets_file(), sub {
			is($rpackets{'0AF5'}{length}, 58,
				'0AF5 reads Lastro initial follow settings as a 58-byte packet');
			is($rpackets{'0AF6'}{length}, 7,
				'0AF6 reads Lastro follow-state updates as a 7-byte packet');
		});
		done_testing();
	};

	subtest 'Lastro target notifications preserve following packet boundaries' => sub {
		with_recvpackets_file(lastro_recvpackets_file(), sub {
			with_master_server({lastroAutoFollow => 1}, sub {
				my @states;
				my $hook = Plugins::addHook('lastro_autofollow_state', sub {
					my (undef, $args) = @_;
					push @states, $args->{enabled};
				});
				my $receiver = Network::Receive->create(
					undef, 'kRO_RagexeRE_2021_11_03'
				);
				my $tokenizer = Network::MessageTokenizer->new(\%rpackets);
				$tokenizer->add(
					pack('v V C', 0x0AF1, 0x0000043B, 1)
					. pack('v V C', 0x0AF1, 0x0000045E, 1)
					. pack('v V C', 0x0AF1, 0x00000697, 1)
					. pack('v', 0x0AF5) . ("\0" x 43) . pack('C', 1) . ("\0" x 12)
				);

				my @switches;
				my $type;
				while (my $message = $tokenizer->readNext(\$type)) {
					my $switch = Network::MessageTokenizer::getMessageID($message);
					push @switches, $switch;
					$receiver->parse($message, $receiver);
				}

				is($rpackets{'0AF1'}{length}, 7,
					'0AF1 matches the browser 4-byte target ID and 1-byte target state');
				is($receiver->{packet_list}{'0AF1'}[0], 'lastro_ignored',
					'0AF1 has a Lastro receiver handler instead of an unknown switch');
				is_deeply(\@switches, [qw(0AF1 0AF1 0AF1 0AF5)],
					'consecutive target notifications do not consume the following load-info packet');
				is_deeply(\@states, [1],
					'0AF5 still updates the auto-follow state after target notifications');
				is(length($tokenizer->getBuffer), 0,
					'notification sequence leaves no partial packet in the tokenizer');
				Plugins::delHook($hook);
			});
		});
		done_testing();
	};

	subtest 'Lastro keeps load-info after the map initialization zero frame' => sub {
		with_recvpackets_file(lastro_recvpackets_file(), sub {
			is($rpackets{'0000'}{length}, 2560,
				'0000 skips Lastro\'s 2560-byte map initialization padding frame');
			is($rpackets{'0AFC'}{length}, 30,
				'0AFC uses Lastro\'s 30-byte offline-message layout');
			with_master_server({lastroAutoFollow => 1}, sub {
				my @states;
				my $hook = Plugins::addHook('lastro_autofollow_state', sub {
					my (undef, $args) = @_;
					push @states, $args->{enabled};
				});
				my $receiver = Network::Receive->create(
					undef, 'kRO_RagexeRE_2021_11_03'
				);
				my $tokenizer = Network::MessageTokenizer->new(\%rpackets);
				$tokenizer->add(
					pack('v', 0x0AD6)
					. ("\0" x 2560)
					. pack('v', 0x0AF5) . ("\0" x 43) . pack('C', 1) . ("\0" x 12)
					. pack('v', 0x0AFC) . ("\0" x 28)
				);

				my @switches;
				my $type;
				while (my $message = $tokenizer->readNext(\$type)) {
					my $switch = Network::MessageTokenizer::getMessageID($message);
					push @switches, $switch;
					$receiver->parse($message, $receiver);
				}

				is_deeply(\@switches, [qw(0AD6 0000 0AF5 0AFC)],
					'zero-filled map initialization frame does not swallow following packets');
				is_deeply(\@states, [1],
					'0AF5 following the initialization frame initializes auto-follow state');
				is(length($tokenizer->getBuffer), 0,
					'initialization sequence leaves no partial packet in the tokenizer');
				Plugins::delHook($hook);
			});
		});
		done_testing();
	};

	subtest 'Lastro NPC shop list packet uses the NPC store handler' => sub {
		my $receiver = Network::Receive->create(
			undef, 'kRO_RagexeRE_2021_11_03'
		);

		ok($receiver, 'creates the Lastro receiver');
		is($receiver->{packet_list}{'0B7A'}[0], 'npc_store_info',
			'0B7A is parsed as an NPC shop item list');
		done_testing();
	};

	subtest 'Lastro NPC shop list uses the extended item layout' => sub {
		my $receiver = Network::Receive->create(
			undef, 'kRO_RagexeRE_2021_11_03'
		);
		my $packet = pack('v v V C v a12 V C v a12',
			0x0B7A, 42,
			1750, 10, 1, "\0" x 12,
			1770, 10, 3, "\0" x 12
		);

		my @previous_ai_seq = @ai_seq;
		my %previous_ai_v = %ai_v;
		my %previous_talk = %talk;
		@ai_seq = ('buyAuto');
		%ai_v = (npc_talk => {ID => 1});
		%talk = ();
		my $previous_store_list = $storeList;
		$storeList = InventoryList->new;
		$receiver->npc_store_info({
			switch => '0B7A',
			RAW_MSG => $packet,
			RAW_MSG_SIZE => length($packet),
		});

		is($storeList->get(0)->{nameID}, 1750,
			'0B7A reads the item ID from the extended record');
		is($storeList->get(0)->{type}, 10,
			'0B7A reads the item type from the compact record');
		is($storeList->get(0)->{price}, 1,
			'0B7A reads the 16-bit price from the compact record');
		is($storeList->get(1)->{nameID}, 1770,
			'0B7A advances by the complete 19-byte record');
		is($storeList->get(1)->{price}, 3,
			'0B7A preserves the price sent by the server');
		$storeList = $previous_store_list;
		@ai_seq = @previous_ai_seq;
		%ai_v = %previous_ai_v;
		%talk = %previous_talk;
		done_testing();
	};

	subtest 'Lastro responds to a server-closed dialog with Talk Cancel' => sub {
		my $receiver = Network::Receive->create(
			undef, 'kRO_RagexeRE_2021_11_03'
		);
		my @previous_ai_seq = @ai_seq;
		my %previous_ai_v = %ai_v;
		my %previous_talk = %talk;
		@ai_seq = ('buyAuto');
		%ai_v = (npc_talk => {ID => pack('V', 1), talk => 'select'});
		%talk = (ID => pack('V', 1));
		local $Misc::npcsList = ActorList->new('Actor::NPC');
		local $Misc::monstersList = ActorList->new('Actor::Monster');

		with_master_server({serverType => 'kRO_RagexeRE_2021_11_03'}, sub {
			my $net = NetworkTest::FakeNet->new;
			my $sender = Network::Send->create($net, 'kRO_RagexeRE_2021_11_03');
			my $task = Task::TalkNPC->new(sequence => '');
			$task->activate;
			$task->{stage} = Task::TalkNPC::TALKING_TO_NPC();
			$task->{target} = Actor::NPC->new;

			$receiver->npc_talk_close({ID => pack('V', 1)});
			$task->{time} = time - 1;

			local $Task::TalkNPC::net = $net;
			with_message_sender($sender, sub {
				$task->iterate;
			});

			is(scalar @{$net->{sent}}, 1,
				'Lastro sends Talk Cancel after 00B6 to receive the shop list');
		});

		@ai_seq = @previous_ai_seq;
		%ai_v = %previous_ai_v;
		%talk = %previous_talk;
		done_testing();
	};

	subtest 'non-Lastro private airship keeps the legacy request' => sub {
		with_master_server({serverType => 'laRO'}, sub {
			my $net = NetworkTest::FakeNet->new;
			my $instance = Network::Send->create($net, 'laRO');
			$instance->sendPrivateAirshipRequest('prt_fild08.gat', 25464);

			my $packet = $net->{sent}[0];
			is(length($packet), 20,
				'non-Lastro keeps the legacy 20-byte structure');
			is(substr($packet, 2, 16), "prt_fild08.gat\0" . "\0",
				'non-Lastro keeps the .gat map name');
			is(unpack('v', substr($packet, 18, 2)), 25464,
				'non-Lastro keeps the legacy item ID field');
		});
		done_testing();
	};

	subtest 'Lastro automatic airship chooses the outdoor map before a dungeon' => sub {
		my $map = choose_lastro_airship_route_map(
			[
				{map => 'prontera'},
				{map => 'izlude'},
				{map => 'iz_dun00'},
			],
			'prontera',
			{izlude => 1},
		);

		is($map, 'izlude',
			'uses the closest allowlisted outdoor map instead of iz_dun00');
		done_testing();
	};

	subtest 'Lastro automatic airship uses a free final destination directly' => sub {
		my $map = choose_lastro_airship_route_map(
			[
				{map => 'prontera'},
				{map => 'prt_fild08'},
			],
			'prontera',
			{prt_fild07 => 1, prt_fild08 => 1},
			'prt_fild07',
		);

		is($map, 'prt_fild07',
			'uses the allowlisted final map instead of its route predecessor');
		done_testing();
	};

	subtest 'Lastro does not reuse a stale route source after entering a map' => sub {
		my $map = choose_lastro_airship_route_map(
			[
				{map => 'glast_01'},
				{map => 'gl_church'},
			],
			'gl_church',
			{glast_01 => 1},
			'gl_church',
		);

		ok(!defined $map,
			'waits for MapRoute to advance after the portal map change');
		done_testing();
	};

	subtest 'Lastro preserves multi-floor dungeon routing' => sub {
		my $map = choose_lastro_airship_route_map(
			[
				{map => 'iz_dun00'},
				{map => 'iz_dun01'},
				{map => 'iz_dun02'},
			],
			'iz_dun01',
			{iz_dun00 => 1},
			'iz_dun02',
		);

		ok(!defined $map,
			'does not send an intermediate dungeon floor back to its predecessor');
		done_testing();
	};

	subtest 'Lastro answers SECOND_CHECK with browser CHECK_BIN data' => sub {
		with_recvpackets_file(lastro_recvpackets_file(), sub {
		with_master_server({
			serverType => 'kRO_RagexeRE_2021_11_03',
			sendCryptKeys => '0x47DA30BB, 0x234A5224, 0x1B013ABC',
		}, sub {
			my $net = NetworkTest::FakeNet->new;
			my $sender = Network::Send->create($net, 'kRO_RagexeRE_2021_11_03');
			$sender->cryptKeys(0x47DA30BB, 0x234A5224, 0x1B013ABC);
			$sender->sendMapLogin(pack('V', 1), pack('V', 2), pack('V', 3), 0);
			$sender->sendMapLoaded;

			with_message_sender($sender, sub {
				my $receiver = Network::Receive->create($net, 'kRO_RagexeRE_2021_11_03');
				my $args = $receiver->parse(
					pack('v V V', 0x0AD5, 0x0000E87A, 0x001EA24E),
					$receiver,
				);

				ok($args, 'SECOND_CHECK is recognized by the receiver');
				is($args ? $args->{pincode} : undef, 0x0000E87A,
					'SECOND_CHECK reads the complete pincode field');
				is($args ? $args->{AID} : undef, 0x001EA24E,
					'SECOND_CHECK reads the account ID field');
			});

			is(scalar @{$net->{sent}}, 4,
				'SECOND_CHECK produces one CHECK_BIN reply');
			is(length($net->{sent}[3]), 10,
				'CHECK_BIN uses the browser wire length');
			is(unpack('H*', substr($net->{sent}[3], 2)), '4ea21e0034383631',
				'CHECK_BIN preserves AID and browser-derived pincode 4861');
		});
		});
		done_testing();
	};

	subtest 'Lastro sends load-info initialization after map loaded' => sub {
		with_master_server({
			serverType => 'kRO_RagexeRE_2021_11_03',
			sendCryptKeys => '0x47DA30BB, 0x234A5224, 0x1B013ABC',
		}, sub {

			my $net = NetworkTest::FakeNet->new;
			my $instance = Network::Send->create($net, 'kRO_RagexeRE_2021_11_03');
			$instance->cryptKeys(0x47DA30BB, 0x234A5224, 0x1B013ABC);
			$instance->sendMapLoaded;

			is(scalar @{$net->{sent}}, 2,
				'map loaded sends both browser initialization packets');
		});
		done_testing();
	};

	subtest 'Lastro skips non-browser initial sync and guild request' => sub {
		with_master_server({
			serverType => 'kRO_RagexeRE_2021_11_03',
			sendCryptKeys => '0x47DA30BB, 0x234A5224, 0x1B013ABC',
		}, sub {

			my $net = NetworkTest::FakeNet->new;
			my $instance = Network::Send->create($net, 'kRO_RagexeRE_2021_11_03');
			$instance->cryptKeys(0x47DA30BB, 0x234A5224, 0x1B013ABC);
			$instance->sendSync(1);
			$instance->sendGuildRequestInfo(0);

			is(scalar @{$net->{sent}}, 0,
				'initial browser-equivalent map load emits no extra packets');
			$instance->sendSync();
			is(scalar @{$net->{sent}}, 1,
				'periodic sync remains available after map load');
		});
		done_testing();
	};
}

sub reduce_struct {
	my ($got, $expected) = @_;

	ref $got eq 'HASH' ? {map { exists $expected->{$_} ? ($_ => reduce_struct($got->{$_}, $expected->{$_})) : () } keys %$got}
	: ref $got eq 'ARRAY' ? [List::MoreUtils::pairwise { reduce_struct($a, $b) } @$got, @$expected]
	: $got
}

{
	package NetworkTest::FakeNet;

	sub new {
		return bless {sent => []}, shift;
	}

	sub serverAlive { return 1; }
	sub getState { return 5; }
	sub version { return 0; }
	sub serverSend {
		my ($self, $packet) = @_;
		push @{$self->{sent}}, $packet;
	}
}

1;
