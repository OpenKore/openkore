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
use Log qw(debug message warning error);
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

my $chooks = Commands::register(
      ['changeProfile', "Changes profile", \&commandHandler]
   );

sub on_unload {
   Plugins::delHook($hooks);
   Commands::unregister($chooks);
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

sub commandHandler {
	my (undef, $new_profile) = @_;

	if (!grep { $_ eq File::Spec->catdir($profile_folder, $profile) } @Settings::controlFolders) {
		error "[profiles] Profile loaded not found in control folder list\n";
		return;
	}
	
	opendir my $d, $profile_folder;
	my @conlist = readdir($d);
	closedir $d;
	
	if (!$new_profile) {

		my @profiles;

		foreach (@conlist) {
			next unless -d File::Spec->catdir($profile_folder, $_);
			next if ($_ =~ /^\./);
			push @profiles, $_;
		}

		@profiles = sort { $a cmp $b } @profiles;

		if (@profiles) {
			my $choice = $interface->showMenu(	#
				"Please choose a Profiles folder.",
				\@profiles,
				title => "Profiles Selector"
			);

			return $quit = 1 if $choice == -1;

			$new_profile = $profiles[$choice];
		} else {
			error "[profiles] There are no profiles in profiles folder\n";
			return;
		}
	} else {
		my $found = 0;
		foreach (@conlist) {
			next unless -d File::Spec->catdir($profile_folder, $_);
			next if ($_ =~ /^\./);
			$found = 1 if ($new_profile eq $_);
		}
		if (!$found) {
			error "[profiles] Provided profile not found in profiles folder\n";
			return;
		}
	}
	
	my $new_profile_folder = File::Spec->catdir($profile_folder, $new_profile);
	my %reloadFiles;
	
	message "[profiles] Looking for loaded files in old profile '".$profile."' to unload \n", "system";
	foreach my $file (@{$Settings::files->getItems}) {
		next if ($file->{'type'} != Settings::CONTROL_FILE_TYPE);
		my $filepath;
		if ($file->{'autoSearch'} == 1) {
			$filepath = Settings::_findFileFromFolders($file->{'name'}, \@Settings::controlFolders);
		} else {
			$filepath = $file->{'name'};
		}
		my (undef,$directories,$filename) = File::Spec->splitpath($filepath);
		my @dirs = File::Spec->splitdir($directories);
		
		if ($dirs[-2] eq $profile) {
			message "[profiles] Unloading file '".$filename."' from old profile '".$profile."'\n";
			$reloadFiles{$file->{'index'}} = $filename;
		}
	}
	
	opendir my $d, $new_profile_folder;
	my @newProfileFiles = readdir($d);
	closedir $d;

	message "[profiles] Looking for files in new profile '".$new_profile."'\n", "system";
	foreach my $filename (@newProfileFiles) {
		next unless -f File::Spec->catdir($new_profile_folder, $filename);
		next if ($filename =~ /^\./);
		foreach my $file (@{$Settings::files->getItems}) {
			next if ($file->{'type'} != Settings::CONTROL_FILE_TYPE);
			next if (exists $reloadFiles{$file->{'index'}});
			my $name = $file->{'autoSearch'} == 1 ? $file->{'name'} : $file->{'internalName'};
			if ($name eq $filename) {
				$reloadFiles{$file->{'index'}} = $filename;
				message "[profiles] Found control file '".$filename."' in new profile '".$new_profile."'\n";
			}
		}
	}
	
	@Settings::controlFolders = map { $_ eq File::Spec->catdir($profile_folder, $profile) ? $new_profile_folder : $_ } @Settings::controlFolders;

	my $progressHandler = sub {
		my ($filename) = @_;
		message "[profiles] Loading ".$filename."...\n";
	};
	
	message "[profiles] Loading files\n", "system";
	my @files;
	foreach my $file_index (keys %reloadFiles) {
		my $file = $Settings::files->get($file_index);
		if ($file->{'autoSearch'} == 0) {
			$file->{'name'} = Settings::_findFileFromFolders($file->{'internalName'}, \@Settings::controlFolders);
		}
		push (@files, $file);
	}
	
	Settings::loadFiles(\@files, $progressHandler);
	
	message "[profiles] Loading finished, profile '".$new_profile."' loaded\n", "system";
	$profile = $new_profile;
}

return 1;
