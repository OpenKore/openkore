package NPCConversationStaticTest;

use strict;
use Test::More;
use File::Find;

sub start {
	print "### Starting NPCConversationStaticTest\n";

	my @roots = ('src', 'plugins');
	my @violations;

	find(
		{
			no_chdir => 1,
			wanted   => sub {
				return unless -f $_;
				return unless $_ =~ /\.(?:pm|pl)$/;
				return if $_ =~ m{(?:^|[\\/])src[\\/]Globals\.pm$};
				return if $_ =~ m{(?:^|[\\/])src[\\/]NPC[\\/]Conversation\.pm$};
				return if $_ =~ m{(?:^|[\\/])src[\\/]test[\\/]};
				return if $_ =~ m{(?:^|[\\/])plugins[\\/]needs-review[\\/]};

				open my $fh, '<', $_ or die "Cannot open $_: $!";
				my $line_number = 0;
				while (my $line = <$fh>) {
					$line_number++;
					$line =~ s/\r?\n\z//;
					my $code = $line;
					$code =~ s/\s+#.*$//;
					next if $code =~ /^\s*#/;
					next if $code =~ /^\s*use\s+Globals\b.*\%talk/;
					next if $code =~ /^\s*our\s+\%talk\b/;

					if ($code =~ /\$talk\{/ || $code =~ /\$ai_v\{\s*['"]npc_talk['"]\s*\}/ || $code =~ /(?<![\w:])%talk\b/) {
						push @violations, "$_:$line_number:$line";
					}
				}
				close $fh;
			},
		},
		@roots,
	);

	is_deeply(\@violations, [], 'production code outside NPC::Conversation does not access legacy npc talk globals directly');
	done_testing();
}

1;
