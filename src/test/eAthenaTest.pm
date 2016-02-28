package eAthenaTest;

use strict;

#use File::Path qw(make_path);
use Test::More;
BEGIN { *eq_or_diff = \&is_deeply unless eval q(use Test::Differences; 1) }

use Misc;
use Network::Receive::kRO::RagexeRE_0;
use Network::Send;

use constant EA_PACKET_DB => 'eathena/db/packet_db.txt';
#use constant RECVPACKETS_PREFIX => 'eathena-recvpackets/';

sub start {
	# compare static information
	SKIP: {
		ok(-r-f EA_PACKET_DB, 'packet database found') or skip('eAthena not found', 1);
		
		# read EA_PACKET_DB
		note sprintf 'Loading %s...', EA_PACKET_DB;
		my $reader = Utils::TextReader->new(EA_PACKET_DB);
		my @theirServerTypes = qw(Sakexe_0);
		my %packet_db;
		while (!$reader->eof and defined(my $_ = $reader->readLine)) {
			chomp;
			
			if (m{^//}) {
				if (/(\d{4})-(\d{2})-(\d{2})(\w)(Sakexe|RagexeRE)(?! to )/) {
					push @theirServerTypes, "$5_$1_$2_$3$4";
					$packet_db{$theirServerTypes[-1]}{version} = $packet_db{$theirServerTypes[-2]}{version};
				}
			} else {
				s|//.*$||;
				if (/^(.*?):\s*(.*)$/) {
					if ($1 eq 'packet_ver') {
						$packet_db{$theirServerTypes[-1]}{version} = $2;
					}
				} elsif ((my ($_, $len, $func, $pos) = split /,/) > 1) {
					s/^0x//;
					$packet_db{$theirServerTypes[-1]}{packets}{+uc} = {
						len => $len, (func => $func) x defined $func, pos => [split /:/, $pos]
					};
				}
			}
		}
		
		## generate recvpackets for each serverType
		#make_path RECVPACKETS_PREFIX;
		#if (-w-d RECVPACKETS_PREFIX) {
		#	my %data;
		#	for (@theirServerTypes) {
		#		if (open my $recvpackets, '>', sprintf my $file = '%srecvpackets-%s.txt', RECVPACKETS_PREFIX, $_) {
		#			@data{keys %{$packet_db{$_}{packets}}} = values %{$packet_db{$_}{packets}};
		#			printf $recvpackets "%s %d\n", $_, $data{$_}{len} for sort keys %data;
		#		}
		#	}
		#}
		
		# list of our serverTypes
		my @ourServerTypes = qw(Network::Receive::kRO::RagexeRE_0);
		until ($ourServerTypes[0] =~ /Sakexe_0$/) {
			no strict 'refs';
			unshift @ourServerTypes, ${$ourServerTypes[0].'::ISA'}[0];
		}
		pop @ourServerTypes; # remove RagexeRE_0
		@ourServerTypes = map /::(\w+)$/, @ourServerTypes;
		
		# compare serverType list
		eq_or_diff(\@ourServerTypes, \@theirServerTypes, 'serverType lists match');
		
		# compare packet structures
		for my $ST (@ourServerTypes) {
			subtest $ST => sub {
				SKIP: {
					skip 'not found in eAthena database', 1 unless $packet_db{$ST};
					
					my @parsers = map { $_->create(undef, "kRO_$ST") } qw(Network::Send Network::Receive);
					
					SKIP: {
						skip 'version undefined in eAthena (parser bug)', 1 unless $packet_db{$ST}{version};
						# FIXME: why ->version is (only) in Network::Send?
						is(eval {$_->version}, $packet_db{$ST}{version}, sprintf('%s->version', ref)) for $parsers[0];
					}
					
					for my $switch (sort keys %{$packet_db{$ST}{packets}}) {
						subtest sprintf('switch %s (%s)', $switch, $packet_db{$ST}{packets}{$switch}{func} || 'unknown') => sub {
							SKIP: {
								# FIXME: replace
								#ok(my ($our_info) = (grep defined, map { $_->{packet_list}{$switch} } @parsers), 'switch found')
								(my ($our_info) = grep defined, map { $_->{packet_list}{$switch} } @parsers)
								or skip 'switch not found', 1;
								
								note $our_info->[0];
								my $their_info = $packet_db{$ST}{packets}{$switch};
								
								SKIP: {
									# FIXME: replace
									#is(defined $our_info->[1], $their_info->{len} != 2, 'structure needed only for non-empty packets')
									(defined $our_info->[1] xor! ($their_info->{len} != 2))
									
									or skip 'structure needed only for non-empty packets', 1;
									
									unless (@{$packet_db{$ST}{packets}{$switch}{pos}}) {
										if ($their_info->{len} > 0) {
											is(length(pack $our_info->[1]) + 2, $their_info->{len}, 'total length (fixed-length packet)');
										} else {
											like($our_info->[1], qr/^(?:x2|v).*\*$/, 'variable-length last field (variable-length packet)');
										}
										
										skip 'no structure to compare to', 1;
									}
									
									SKIP: {
										for ($our_info->[1]) {
											s/([cCWsSlLqQiInNvVjJfdFDpuUw])(\d+)/join ' ', ($1) x $2/ge;
											
											if ($their_info->{len} <= 0 and s/^x2/v/) {
												unshift @{$our_info->[2]}, 'TESTFIX_IMPLIED_LENGTH_FIELD';
											}
											
											my ($pos, $i, $len, $template, $repeat) = 2;
											for (split) {
												if (($template, $repeat) = /^(\w)(\d+|\*)?$/) {
													$repeat ||= 1;
													$len = length pack $_;
													
													next if $template eq 'x';
													
													is($pos, $packet_db{$ST}{packets}{$switch}{pos}[$i], $our_info->[2][$i]);
												} else {
													fail $our_info->[2][$i];
													skip "can't parse structure at: $_", 1;
												}
												
												++$i;
											} continue {
												$pos += $len;
											}
											
											if ($their_info->{len} > 0) {
												is($pos, $their_info->{len}, 'total length (fixed-length packet)');
											} else {
												is($repeat, '*', 'variable-length last field (variable-length packet)');
											}
										}
									}
								}
							}
						}
					}
				}
			}
		}
	}
	
	# TODO: run eA and do live tests?
}

1;
