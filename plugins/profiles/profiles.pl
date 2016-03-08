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
use Globals qw($interface $quit);
use Getopt::Long;
use Settings qw( %sys );

our $profile_folder = "profiles";
our $profile;

return unless
Plugins::register('profiles', 'Profiles Selector', \&on_unload);

my $hooks = Plugins::addHooks(
      ['parse_command_line', \&onParseCommandLine],
      ['usage', \&onUsage],
      ['start', \&onStart]
   );

sub on_unload {
   Plugins::delHook($hooks);
   undef $profile_folder;
}

sub onUsage {
	my ( undef, $params ) = @_;
	push @{ $params->{options} }, { plugin => 'profiles', long => '--profile=PROFILE', description => 'profile to use (default: prompt)' };
}

sub onParseCommandLine {
	GetOptions( 'profile=s' => \$profile );
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

	if ( $profile && !grep { $_ eq $profile } @profiles ) {
		printf "Unknown profile [%s] requested.\n", $profile;
		$profile = undef;
	}

	if ( !$profile && @profiles ) {
		my $choice = $interface->showMenu(	#
			"Please choose a Profiles folder.",
			\@profiles,
			title => "Profiles Selector"
		);

		return $quit = 1 if $choice == -1;

		$profile = $profiles[$choice];
	}

	unshift @Settings::controlFolders, File::Spec->catdir( $profile_folder, $profile ) if $profile;
}

return 1;
