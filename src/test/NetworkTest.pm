# Unit test for Network
package NetworkTest;

use strict;
use Test::More;
use Misc;
use Network::Receive;
use Network::Send;

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
	test_item_move_failed();
}

sub reduce_struct {
	my ($got, $expected) = @_;

	ref $got eq 'HASH' ? {map { exists $expected->{$_} ? ($_ => reduce_struct($got->{$_}, $expected->{$_})) : () } keys %$got}
	: ref $got eq 'ARRAY' ? [List::MoreUtils::pairwise { reduce_struct($a, $b) } @$got, @$expected]
	: $got
}


# ZC_MOVE_ITEM_FAILED (0AA7) is defined independently in ServerType0 and
# kRO::Sakexe_0; verify both protocol families with captured failure packets.
sub test_item_move_failed {
	my $legacy = Network::Receive->create(undef, 'kRO_RagexeRE_0');
	ok(!exists $legacy->{packet_list}{'0AA7'},
		'legacy kRO RagexeRE_0 does not register 0AA7');

	for my $serverType (0, 'kRO_RagexeRE_2021_11_03') {
		subtest "0AA7 serverType $serverType" => sub {
			my $receiver = Network::Receive->create(undef, $serverType);
			ok($receiver, 'receive parser created');

			is_deeply($receiver->{packet_list}{'0AA7'},
				['item_move_failed', 'v2', [qw(index amount)]],
				'item move failure maps to two 16-bit fields');

			for my $case ([2, 12], [3, 14], [4, 2]) {
				my ($index, $amount) = @$case;
				subtest "index=$index amount=$amount" => sub {
					my @warnings;
					local *Network::Receive::warning = sub { push @warnings, $_[0]; };

					my $args = $receiver->parse(pack('v3', 0x0AA7, $index, $amount), $receiver);
					ok($args, 'packet recognized and handled');
					is($args->{switch}, '0AA7', 'packet ID');
					is($args->{index}, $index, 'decoded item index');
					is($args->{amount}, $amount, 'decoded item quantity');
					is_deeply(\@warnings,
						["Item move failed (index: $index, amount: $amount).\n"],
						'server rejection reported');
				};
			}
		};
	}
}

1;
