# =======================
# reactOnNPC v.1.1.1
# =======================
# This plugin is licensed under the GNU GPL
# Copyright 2006 by hakore
#
# http://forums.openkore.com/viewtopic.php?t=19973

package reactOnNPC;

use strict;
use Plugins;
use Globals;
use Utils;
use Commands;
use Log qw(message debug);

Plugins::register('reactOnNPC', "react on NPC messages", \&Unload);

my $hooks = ((substr($Settings::VERSION, 0, 3) >= 1.9) ?
	Plugins::addHooks(
            ['packet/npc_talk', \&onNPCTalk, undef],
            ['packet/npc_talk_close', \&onNPCAction, undef],
            ['packet/npc_talk_continue', \&onNPCAction, undef],
            ['packet/npc_talk_number', \&onNPCAction, undef],
            ['packet/npc_talk_responses', \&onNPCAction, undef],
            ['packet/npc_talk_text', \&onNPCAction, undef]
	) :
	Plugins::addHooks(
            ['parseMsg/pre', \&onParseMsg,
				{
					'00B4' => [\&onNPCTalk, 'packet/npc_talk'],
					'00B5' => [\&onNPCAction, 'packet/npc_talk_continue'],
					'00B6' => [\&onNPCAction, 'packet/npc_talk_close'],
					'00B7' => [\&onNPCAction, 'packet/npc_talk_responses'],
					'0142' => [\&onNPCAction, 'packet/npc_talk_number'],
					'01D4' => [\&onNPCAction, 'packet/npc_talk_text']
				}
			]
	)
);

my %reactOnNPC;

sub Unload
{
	Plugins::delHooks($hooks);
};

sub onNPCTalk
{
	my (undef, $args) = @_;
	my $ID = unpack("V", substr($args->{RAW_MSG}, 4, 4));
	my $msg = unpack("Z*", substr($args->{RAW_MSG}, 8));
	if ((substr($Settings::VERSION, 0, 3) >= 1.9) && (substr($Settings::VERSION, 4) >= 1))
	{
		$msg = I18N::bytesToString($msg);
	}

	if (!defined %reactOnNPC || $reactOnNPC{action})
	{
		undef %reactOnNPC if defined %reactOnNPC;
		$reactOnNPC{index} = 0;
		$reactOnNPC{ID} = $ID;
		$reactOnNPC{msg}[$reactOnNPC{index}] = $msg;
	}
	else
	{
		$reactOnNPC{index}++;
		$reactOnNPC{msg}[$reactOnNPC{index}] = $msg;
	}
	debug "[reactOnNPC] NPC message saved ($reactOnNPC{index}): \"$msg\".\n", "reactOnNPC";
}

sub onNPCAction
{
	my $type = substr(shift, 16);
	$reactOnNPC{action} = $type;
	debug "[reactOnNPC] onNPCAction type is: $type.\n", "reactOnNPC";

	if ($type eq 'responses')
	{
		my $args = shift;
		my $msg = unpack("Z*", substr($args->{RAW_MSG}, 8));
		if ((substr($Settings::VERSION, 0, 3) >= 1.9) && (substr($Settings::VERSION, 4) >= 1))
		{
			$msg = I18N::bytesToString($msg);
		}
		undef @{$reactOnNPC{responses}};
		my @responses = split /:/, $msg;
		foreach (@responses) {
			push @{$reactOnNPC{responses}}, $_ if $_ ne "";
		}
	}
	
	my $i = 0;
	while (exists $config{"reactOnNPC_$i"}) {
		if (
			!$config{"reactOnNPC_$i"}
			|| !main::checkSelfCondition("reactOnNPC_$i")
			|| ($config{"reactOnNPC_${i}_type"} && $config{"reactOnNPC_${i}_type"} ne $type)
		) {
			debug "[reactOnNPC] Conditions for reactOnNPC_$i not met.\n", "reactOnNPC";
			$i++;
			next;
		}
		my $j = 0;
		my $ok = 1;
		while (exists $config{"reactOnNPC_${i}_msg_$j"})
		{
			my $msg;
			if (exists $reactOnNPC{msg}[$j])
			{
				$msg = $reactOnNPC{msg}[$j];
				# Remove RO color codes
				$msg =~ s/\^[a-fA-F0-9]{6}//g unless ($config{"reactOnNPC_${i}_useColors"});
			}

			if (!defined $msg || !match($j, $msg, $config{"reactOnNPC_${i}_msg_$j"}))
			{
				debug "[reactOnNPC] One or more lines doesn't match for \"reactOnNPC_$i\" ($j).\n", "reactOnNPC";
				$ok = 0;
				last;
			}
			$j++;
		}

		if ($ok)
		{
			my $cmd = $config{"reactOnNPC_$i"};
			$cmd =~ s/#(\d+)~(\d+)/$reactOnNPC{match}[$1][$2]/g;
			my $kws = 'eval|resp';
			while (my ($kw, $expr) = $cmd =~ /\@($kws)\(((?:(?!(?<!\@)\@$kws\().)+?)(?<!\@)\)/)
			{
				my $eval;
				my $eval_expr = $expr;
				$eval_expr =~ s/\@(?=[\@)])//g;
				if ($kw eq 'eval')
				{
					$eval = eval $eval_expr;
				}
				elsif ($kw eq 'resp')
				{
					$i = 0;
					foreach (@{$reactOnNPC{responses}}) {
						if (match(undef, $_, $eval_expr))
						{
							last;
						}
						$i++;
					}
					$eval = $i;
				}
				$expr = quotemeta $expr;
				$cmd =~ s/\@$kw\($expr\)/$eval/g;
			}
			message "[reactOnNPC] Reacting to NPC. Executing command \"$cmd\".\n", "success";
			Commands::run($cmd);
			last;
		}
		$i++;
	}
	undef %reactOnNPC if $type eq 'close';
}

sub match
{
	my ($line, $subject, $pattern) = @_;
	
	debug "[reactOnNPC] Matching \"$subject\" to \"$pattern\" ($line)... ", "reactOnNPC";
	if (my ($re, $ci) = $pattern =~ /^\/(.+?)\/(i?)$/)
	{
		if (($ci && $subject =~ /$re/i) || (!$ci && $subject =~ /$re/))
		{
			if (defined $line)
			{
				no strict;
				foreach my $index (1..$#-)
				{
					$reactOnNPC{match}[$line][$index] = ${$index};
				}
			}
			debug "regexp ok.\n", "reactOnNPC";
			return 1;
		}
	}
	elsif ($subject eq $pattern)
	{
		debug "ok.\n", "reactOnNPC";
		return 1;
	}
	debug "doesn't match.\n", "reactOnNPC";
}

sub onParseMsg
{
	my (undef, $args, $handlers) = @_;
	
	if ($handlers->{$args->{switch}})
	{
		my $handler = $handlers->{$args->{switch}};
		$handler->[0]->($handler->[1], ($args->{switch} eq '00B4' || $args->{switch} eq '00B7') ? {RAW_MSG => $args->{msg}} : undef);
	}
}

return 1;