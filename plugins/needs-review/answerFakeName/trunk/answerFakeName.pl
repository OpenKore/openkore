# The plugin is made. It answers the NPC when it asks for your name ONLY. Still needs to be tested.
# http://forums.openkore.com/viewtopic.php?f=34&t=9939

package answerFakeName;

use strict;
use Plugins;

use Globals qw($accountID);
use Log qw(message);

Plugins::register('answerFakeName', 'Answers Anti-bot with defined name.', \&onUnload);

my $hooks = Plugins::addHooks(
   ['packet/npc_talk_text', \&typeText, undef],
   ['packet/npc_talk_number', \&typeNumber, undef],
   ['packet/actor_info', \&checkName, undef],
);

sub onUnload {
   Plugins::delHooks($hooks);
}

my $name;

sub checkName {
   my ($self, $args) = @_;
   if ($args->{ID} eq $accountID) {
      $name = $args->{name};
      message "Fake name found: $name\n";
   }
}

sub typeText {
   if ($name) {
      Commands::run("talk text $name");
      undef $name;
   }
}

sub typeNumber {
   if ($name) {
      Commands::run("talk num $name");
      undef $name;
   }
}

1;