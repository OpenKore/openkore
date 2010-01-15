#########################################################################
#  OpenKore - Network subsystem
#  Copyright (c) 2006 OpenKore Team
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#########################################################################
# bRO (Brazil): Thor
# Servertype overview: http://www.openkore.com/wiki/index.php/ServerType
package Network::Receive::bRO::Thor;

use strict;
use Network::Receive::bRO ();
use base qw(Network::Receive::bRO);
use Log qw(message warning error debug);
use Translation;
use Globals;
use Plugins;
use Misc;
use I18N qw(bytesToString);
use Utils qw(getHex swrite makeIP makeCoords);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new();

	$self->{packet_list}{'0078'} = ['actor_display', 'x a4 v14 a4 a2 v2 C2 a3 C3 v', [qw(ID walk_speed opt1 opt2 option type hair_style weapon lowhead shield tophead midhead hair_color clothes_color head_dir guildID emblemID manner opt3 karma sex coords unknown1 unknown2 act lv)]]; #standing
	$self->{packet_list}{'007C'} = ['actor_display', 'x a4 v14 C2 a3 C2', [qw(ID walk_speed opt1 opt2 option hair_style weapon lowhead type shield tophead midhead hair_color clothes_color head_dir karma sex coords unknown1 unknown2)]]; #spawning
	$self->{packet_list}{'022C'} = ['actor_display', 'x a4 v3 V v5 V v5 a4 a2 v V C2 a5 x C2 v', [qw(ID walk_speed opt1 opt2 option type hair_style weapon shield lowhead tick tophead midhead hair_color clothes_color head_dir guildID emblemID manner opt3 karma sex coords unknown1 unknown2 lv)]]; # walking
	$self->{packet_list}{'009A'} = ['system_chat', 'x2 A*', [qw(message)]];

	return $self;
}

sub system_chat {
   my ($self, $args) = @_;

   my $message = bytesToString($args->{message});
   if (substr($message,0,4) eq 'micc') {
      $message = bytesToString(substr($args->{message},34));
   }
   stripLanguageCode(\$message);
   chatLog("s", "$message\n") if ($config{logSystemChat});
   # Translation Comment: System/GM chat
   message TF("[GM] %s\n", $message), "schat";
   ChatQueue::add('gm', undef, undef, $message);

   Plugins::callHook('packet_sysMsg', {
      Msg => $message
   });
}


1;