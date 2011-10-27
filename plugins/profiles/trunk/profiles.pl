#########################################################################
# This software is open source, licensed under the GNU General Public
# License, version 2.
# Basically, this means that you're allowed to modify and distribute
# this software. However, if you distribute modified versions, you MUST
# also distribute the source code.
# See http://www.gnu.org/licenses/gpl.html for the full license.
#########################################################################
# profiles selector (full)
# d3fc0n 30/12/2007
#########################################################################

package profiles;

use strict;
use Plugins;
use Globals qw($interface);

my $profile_folder = "profiles";

Plugins::register('profiles', 'Profiles Selector', \&on_unload);

my $hooks = Plugins::addHooks(
      ['start', \&onStart]
   );

sub on_unload {
   Plugins::delHook($hooks);
   undef $profile_folder;
}

sub onStart {
   opendir D, $profile_folder;
   my @conlist = readdir(D);
   closedir D;

   my @profiles;

   foreach (@conlist) {
      next if (!-d "$profile_folder\\$_");
      next if ($_ =~ /^\./);
      push @profiles, $_;
   }

   my $choice = $interface->showMenu(
         "Please choose a Profiles folder.",
         \@profiles,
         title => "Profiles Selector"
      );

   if ($choice == -1) {
      exit;

   } else {

      if (-e "$profile_folder\\" . @profiles[$choice] . "\\config.txt") {
         $Settings::config_file = "$profile_folder\\" . @profiles[$choice] . "\\config.txt";
      }

      if (-e "$profile_folder\\" . @profiles[$choice] . "\\mon_control.txt") {
         $Settings::mon_control_file = "$profile_folder\\" . @profiles[$choice] . "\\mon_control.txt";
      }

      if (-e "$profile_folder\\" . @profiles[$choice] . "\\items_control.txt") {
         $Settings::items_control_file = "$profile_folder\\" . @profiles[$choice] . "\\items_control.txt";
      }

      if (-e "$profile_folder\\" . @profiles[$choice] . "\\shop.txt") {
         $Settings::shop_file = "$profile_folder\\" . @profiles[$choice] . "\\shop.txt";
      }
   }
}

return 1;
