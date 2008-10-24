# $Header$
#
# acl plugin by Arachno
#
#
# This source code is licensed under the
# GNU General Public License, Version 2.
# See http://www.gnu.org/licenses/gpl.html

#
# just a proof of concept
#
# todo:
# - revoke access for users
# - give feedback using Log::addHook

package acl;

my $Version = "0.1";
$Version .= sprintf(" rev%d.%02d", q$Revision: 3842 $ =~ /(\d+)\.(\d+)/);

use strict;
use Plugins;
use Settings qw(addConfigFile delConfigFile);
use Globals;
use Utils;
use Log qw(message warning error);
use Commands;
use Misc;

our %acl;
our %auth;
our $trigger;

Plugins::register('acl', 'allow commands based on access control lists', \&Unload, \&Unload);

my $hooks = Plugins::addHooks(
	['Command_post', \&commandHandler, undef],
	['packet_privMsg', \&pmHandler, undef]
);

our $file = "$Settings::control_folder/acl.txt";
our $cfID = addConfigFile($file, \%acl, \&parseACL);

sub Unload {
	undef %acl;
	undef %auth;
	delConfigFile($cfID);
	Plugins::delHooks($hooks);
	message "[acl] cleaning up.\n";
}

sub parseACL {
	my ($file, $r_hash) = @_;
	undef %{$r_hash};

	my ($cBlock, $block);
	open FILE, "< $file";
	foreach (<FILE>) {
		next if (/^\s*#/); # skip comments
		s/^\s*//g;         # remove leading whitespaces
		s/\s*[\r\n]?$//g;  # remove trailing whitespaces and eol
		s/  +/ /g;         # trim down spaces
		next unless ($_);
		if (!defined $cBlock && /^\/\*/) {
			$cBlock = 1; next;
		} elsif (m/\*\/$/) {
			undef $cBlock;
			next
		} elsif (defined $cBlock) {
			next
		} elsif (!defined $block && /{$/) {
			s/\s*{$//;
			my ($level, $passwd) = $_ =~ /^level ([0-9]+) (.*)/;
			$r_hash->{$level}->{passwd} = $passwd;
			$block = $level;
		} elsif (defined $block && $_ eq "}") {
			undef $block;
			next
		} elsif (defined $block) {
			push(@{$r_hash->{$block}->{cmds}}, $_);
		} else {
			next
		}
	}
	close FILE;
	return 1
}

sub commandHandler {
	my (undef, $arg) = @_;
	my ($cmd, $param, @args) = split(/ /, $arg->{input});
	if ($cmd eq 'acl') {
		if ($param eq 'show') {listACLwrapper(@args)}
		elsif ($param eq 'version') {showVersion()}
		elsif ($param eq 'edit') {editACL(@args)}
		elsif ($param eq 'save') {saveACL()}
		else {usage()}
		$arg->{return} = 1;
	}
}

sub showVersion {
	message "ACL plugin version $Version\n", "list";
}

sub usage {
	message "usage: acl [show|edit|save|version]\n", "list";
	message "acl show: lists access control levels with their passwords and their allowed commands\n";
	message "acl show {level}: lists access control level {level} with it's commands\n";
	message "acl show pass: lists access control levels with their passwords\n";
	message "acl show users: lists identified users\n";
	message "acl edit {level} passwd {new password}: sets new password for level {level}\n";
	message "acl edit {level} add {command}: adds command to level {level}\n";
	message "acl edit {level} del {command}: removes command from level {level}\n";
	message "acl save: saves the current acl to acl.txt\n";
	message "acl version: shows version info\n";
	message "---\n", "list";
}

sub editACL {
	my ($level, $cmd, $arg) = @_;
	if ($level =~ /^[0-9]+$/ && defined $arg) {
		if ($cmd eq 'passwd') {chPass($level, $arg)}
		if ($cmd eq 'add') {addCmd($level, $arg)}
		if ($cmd eq 'del') {delCmd($level, $arg)}
		warning "Use \"acl save\" to write $file\n";
		return
	} else {
		warning "[acl] edit: wrong syntax.\n"; usage();
	}
}

sub saveACL {
	my $level = 0;
	open FILE, "> $file" or return;
	while (exists $acl{$level}) {
		print FILE "level $level $acl{$level}->{passwd} {\n";
		foreach (@{$acl{$level++}->{cmds}}) {print FILE "\t$_\n"}
		print FILE "}\n\n";
	}
	close FILE;
	message "[acl] acl written to $file\n";
}

sub chPass {
	my ($level, $pass) = @_;
	if (defined $acl{$level}) {
		$acl{$level}->{passwd} = $pass;
		message "[acl] changed password for level $level\n";
		return;
	}
	warning "[acl] there's no access level $level\n";
}

sub addCmd {
	my ($level, $cmd) = @_;
	if (!defined $acl{$level}) {
		warning "[acl] there's no access level $level, adding it with dummy password \"acl\"\n";
		warning "[acl] type \"acl edit $level passwd {new password}\" to edit\n";
		$acl{$level}->{passwd} = "acl";
	}
	foreach (@{$acl{$level}->{cmds}}) {
		if ($_ eq $cmd) {warning "[acl] command $cmd already exists in level $level\n"; return}
	}
	push(@{$acl{$level}->{cmds}}, $cmd);
	message "[acl] added $cmd to level $level\n";
	
	for (my $l = 0; $l < $level; $l++) {
		for (my $i = @{$acl{$l}->{cmds}}; $i >= 0; $i--) {
			 if (${$acl{$l}->{cmds}}[$i] eq $cmd) {
				 splice(@{$acl{$l}->{cmds}}, $i);
				 message "[acl] -> removed $cmd from $l\n";
			 }
		}
	}
}

sub delCmd {
	my ($level, $cmd) = @_;
	if (!defined $acl{$level}) {
		warning "[acl] there's no access level $level.\n";
		return;
	}
	for (my $i = @{$acl{$level}->{cmds}}; $i >= 0; $i--) {
		if (${$acl{$level}->{cmds}}[$i] eq $cmd) {
			splice(@{$acl{$level}->{cmds}}, $i);
			message "[acl] removed $cmd from $level\n";
			return;
		}
	}
}

sub listACLwrapper {
	my $extra = shift;
	message "access control list\n", "list";
	if ($extra =~ /^[0-9]+$/) {listACL($extra)}
	elsif ($extra eq 'users') {
		foreach my $u (keys %auth) {message "'$u' access level: $auth{$u}\n"}
	} else {
		my $level = 0; while (exists $acl{$level}) {
			message "level $level: $acl{$level}->{passwd}\n", "list";
			if (!defined $extra) {listACL($level)}
			$level++;
		}
	}
	message "---\n", "list";
}

sub listACL {
	my $level = shift;
	return unless $acl{$level};
	foreach (@{$acl{$level}->{cmds}}) {message "+ $_\n"}
}

sub getACL {
	my $nick = shift;
	return $auth{$nick} if exists $auth{$nick};
	return;
}

sub checkCmd {
	my ($level, $pm) = @_;
	$pm =~ s/^$trigger\s*//g;
	my ($cmd, $args) = $pm =~ /^(.*?) +(.*)$/;
	$cmd = $pm unless defined $cmd;
	for (my $l = 0; $l <= $level; $l++) {
		foreach (@{$acl{$l}->{cmds}}) {
			if ($_ eq $cmd) {
				if (!Commands::run($cmd." ".$args)) {
					error "command '$cmd $args' failed.\n";
				}
				return 1
			}
		}
	}
	return 0
}

sub pmHandler {
	my (undef, $arg) = @_;
	$trigger = quotemeta $::config{acltrigger};
	if ($arg->{privMsg} =~ /^auth /) {
		my ($level, $pass) = $arg->{privMsg} =~ /^auth +([0-9]+) +(.*)/;
		if (defined $level && defined $pass && $pass eq $acl{$level}->{passwd}) {
			$auth{$arg->{privMsgUser}} = $level;
			reply($arg->{privMsgUser}, "access to level $level granted");
		}
	} elsif ($arg->{privMsg} =~ /^$trigger/) {
		my $level = getACL($arg->{privMsgUser});
		if (defined $level) {
			if (checkCmd($level, $arg->{privMsg})) {
				reply($arg->{privMsgUser}, "ok.");
			} else {
				reply($arg->{privMsgUser}, "access denied");
			}
		}
	}
}

sub reply {
	my ($nick, $msg) = @_;
	Misc::sendMessage(\$remote_socket, "pm", $msg, $nick);
}

1;
