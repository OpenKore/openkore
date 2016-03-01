=pod

chatDomains plugin - configurable domains for chat messages

# Config

chatDomain <destination domain> {
	[domain <comma-separated list of: publicchat, pm, partychat, guildchat, schat>]
	[message /<regexp>/[i]]
}

If you don't know what regexp is: http://perldoc.perl.org/perlre.html

# Examples

chatDomain woe {
	domain schat
	message /^The \[.+\] castle has been conquered by the \[.+\] guild\.$/
}
chatDomain godlike {
	domain schat
	message /^\[.+\], of guild \[.+\] has brought a .+ into this world\.$/
}
chatDomain spam {
	domain publicchat, pm
	message /(?:sell|sale)\w*\s*zeny|faster delivery|delivery24/i
}
beepDomains godlike
squelchDomains spam

# Notes

- public chat message will not have actor binID and distance

=cut

package chatDomains;
use strict;
use warnings;

use Utils::DataStructures qw/existsInList/;
use Globals qw/%config/;
use Log qw/message/;
use Misc qw/checkSelfCondition/;

use constant {
	MESSAGE_FORMAT => {
		packet_pubMsg => "%2\$s: %s\n",
		packet_privMsg => "(From: %2\$s) : %s\n",
		packet_partyMsg => "[Party] %2\$s : %s\n",
		packet_guildMsg => "[Guild] %2\$s : %s\n",
		packet_sysMsg => "[GM] %s\n",
	},
};

my $squelch;

Plugins::register 'chatDomains', 'configurable domains for chat messages', \&unload;

my $hooks = Plugins::addHooks (
	['packet_pre/public_chat', \&packet_pre],
	['packet_pre/private_message', \&packet_pre],
	['packet_pre/party_chat', \&packet_pre],
	['packet_pre/guild_chat', \&packet_pre],
	['packet_pre/system_chat', \&packet_pre],
	['packet_pubMsg', \&msg, 'publicchat'],
	['packet_privMsg', \&msg, 'pm'],
	['packet_partyMsg', \&msg, 'partychat'],
	['packet_guildMsg', \&msg, 'guildchat'],
	['packet_sysMsg', \&msg, 'schat'],
);

sub unload {
	Plugins::delHooks ($hooks);
}

sub packet_pre {
	$squelch = $config{squelchDomains};
	$config{squelchDomains} .= ', publicchat, pm, partychat, guildchat, schat';
}

sub msg {
	my ($hook, $args, $domain) = @_;
	my ($message, $block) = ($args->{Msg});
	
	$config{squelchDomains} = $squelch;
	delete $config{squelchDomains} unless defined $squelch;
	
	for (my $i = 0; $block = "chatDomain_$i" and exists $config{$block}; $i++) {
		next unless $config{$block};
		
		next if $config{"${block}_domain"} && !existsInList ($config{"${block}_domain"}, $domain);
		if ($config{"${block}_message"} && $config{"${block}_message"} =~ m{^/(.*)/(\w*)$}) {
			next if $2 eq 'i' ? $message !~ /$1/i : $message !~ /$1/;
		}
		
		$domain = $config{$block};
		last;
	}
	
	message sprintf ((MESSAGE_FORMAT)->{$hook}, $message, $args->{MsgUser}), $domain;
}

1;
