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
use File::Spec;
use Plugins;
use Globals qw($interface);

my $profile_folder = "profiles";

return unless
Plugins::register('profiles', 'Profiles Selector', \&on_unload);

my $hooks = Plugins::addHooks(
      ['start', \&onStart]
   );

sub on_unload {
   Plugins::delHook($hooks);
   undef $profile_folder;
}

sub onStart {
   opendir my $d, $profile_folder;
   my @conlist = readdir($d);
   closedir $d;

   my @profiles;

   foreach (@conlist) {
      next unless -d File::Spec->catdir($profile_folder, $_);
      next if ($_ =~ /^\./);
      push @profiles, $_;
   }

   @profiles = sort { $a cmp $b } @profiles;

   my $choice = $interface->showMenu(
         "Please choose a Profiles folder.",
         \@profiles,
         title => "Profiles Selector"
      );

   if ($choice == -1) {
      exit;

   } else {

      unshift @Settings::controlFolders, File::Spec->catdir($profile_folder, $profiles[$choice]);
   }
}

return 1;
