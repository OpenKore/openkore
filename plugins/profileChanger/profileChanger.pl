package profileChanger;

use strict;
use File::Spec;
use Plugins;
use Globals qw($interface $quit);
use Log qw(debug message warning error);
use Settings;
use Misc;

return unless
Plugins::register('profileChanger', 'profileChanger', \&on_unload);

my $chooks = Commands::register(
	['changeProfile', "Changes profile", \&commandHandler]
);

sub on_unload {
	Commands::unregister($chooks);
}

sub commandHandler {
	my (undef, $new_profile) = @_;
	
	if (!$profiles::profile) {
		error "[PC] Profiles plugin not loaded\n";
		return;
	}
	
	opendir my $d, $profiles::profile_folder;
	my @conlist = readdir($d);
	closedir $d;
	
	if (!$new_profile) {

		my @profiles;

		foreach (@conlist) {
			next unless -d File::Spec->catdir($profiles::profile_folder, $_);
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
			error "[PC] There are no profiles in profiles folder\n";
			return;
		}
	} else {
		my $found = 0;
		foreach (@conlist) {
			next unless -d File::Spec->catdir($profiles::profile_folder, $_);
			next if ($_ =~ /^\./);
			$found = 1 if ($new_profile eq $_);
		}
		if (!$found) {
			error "[PC] Provided profile not found in profiles folder\n";
			return;
		}
	}
	
	my $new_profile_folder = File::Spec->catdir($profiles::profile_folder, $new_profile);
	my %reloadFiles;
	
	message "[PC] Looking for loaded files in old profile '".$profiles::profile."' to unload \n", "system";
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
		
		if ($dirs[-2] eq $profiles::profile) {
			message "[PC] Unloading '".$filename."' from '".$profiles::profile."'\n";
			$reloadFiles{$file->{'index'}} = $filename;
		}
	}
	
	opendir my $d, $new_profile_folder;
	my @newProfileFiles = readdir($d);
	closedir $d;

	message "[PC] Looking for files in new profile '".$new_profile."'\n", "system";
	foreach my $filename (@newProfileFiles) {
		next unless -f File::Spec->catdir($new_profile_folder, $filename);
		next if ($filename =~ /^\./);
		foreach my $file (@{$Settings::files->getItems}) {
			next if ($file->{'type'} != 0);
			next if (exists $reloadFiles{$file->{'index'}});
			my $name = $file->{'autoSearch'} == 1 ? $file->{'name'} : $file->{'internalName'};
			if ($name eq $filename) {
				$reloadFiles{$file->{'index'}} = $filename;
				message "[PC] Unloading '".$filename."' other control folder\n";
			}
		}
	}
	
	foreach my $folder (@Settings::controlFolders) {
		if ($folder eq $profiles::profile) {
			$folder = $new_profile_folder;
		}
	}

	my $progressHandler = sub {
		my ($filename) = @_;
		message "[PC] Loading ".$filename."...\n";
	};
	
	message "[PC] Loading files\n", "system";
	my @files;
	foreach my $file_index (keys %reloadFiles) {
		my $file = $Settings::files->get($file_index);
		if ($file->{'autoSearch'} == 0) {
			$file->{'name'} = Settings::_findFileFromFolders($file->{'internalName'}, \@Settings::controlFolders);
		}
		push (@files, $file);
	}
	
	Settings::loadFiles(\@files, $progressHandler);
	
	message "[PC] Loading over, profile '".$new_profile."' loaded\n", "system";
	$profiles::profile = $new_profile;
}

return 1;
