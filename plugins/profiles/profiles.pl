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
use FileParsers qw(parseConfigFile);
use Settings qw( %sys );

our $profile_folder = "profiles";
our $profile;
our %profile_extra_plugins;

return unless
Plugins::register('profiles', 'Profiles Selector', \&on_unload);

my $hooks = Plugins::addHooks(
      ['parse_command_line', \&onParseCommandLine],
      ['usage', \&onUsage],
      ['mainLoop::setTitle', \&setTitle,     undef],
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

sub setTitle {
	my (undef, $args) = @_;
	$args->{return} = ($profile) ? "[$profile] " . $args->{return} : $args->{return};
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
      next if ($_ =~ /^\.|^#/);
      push @profiles, $_;
   }
   
   if (!@profiles) {
		message "No profiles found, using standard control folder\n";
		return;
	}

   @profiles = sort { $a cmp $b } @profiles;
   push @profiles, 'Use standard control folder';
   
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

		my $num = @profiles;
		return 0 if $choice == $num - 1;
		return $quit = 1 if $choice == -1;

		$profile = $profiles[$choice];
	}

	unshift @Settings::controlFolders, File::Spec->catdir( $profile_folder, $profile ) if $profile;
	
	my %requested_plugins = map { $_ => 1 } getProfileRequestedPlugins($profile);
	my @loaded_plugins = loadMissingProfilePlugins($profile, \%requested_plugins);
	%profile_extra_plugins = map { $_ => 1 } @loaded_plugins;
}

sub getProfileRequestedPlugins {
	my ($profile_name) = @_;
	return unless $profile_name;

	my $profile_sys = File::Spec->catfile($profile_folder, $profile_name, 'sys.txt');
	return unless -f $profile_sys;

	my %profile_sys_config;
	parseConfigFile($profile_sys, \%profile_sys_config);

	my @requested_plugins = split /\s*,\s*/, ($profile_sys_config{'loadPlugins_list'} || '');
	return grep { $_ } @requested_plugins;
}

sub loadMissingProfilePlugins {
	my ($profile_name, $requested_plugins_ref) = @_;
	return unless $profile_name;

	my %requested_plugins = $requested_plugins_ref ? %{$requested_plugins_ref} : map { $_ => 1 } getProfileRequestedPlugins($profile_name);
	return unless keys %requested_plugins;

	my $profile_sys = File::Spec->catfile($profile_folder, $profile_name, 'sys.txt');
	my %loaded_plugins = map { ($_ && $_->{name}) ? ($_->{name} => 1) : () } @Plugins::plugins;
	my %plugins_by_name = map { $_->{name} => "$$_{dir}/$$_{name}$$_{ext}" } Plugins::getPluginsFiles();

	my (@plugins_to_load, @loaded_plugin_names);
	foreach my $plugin_name (keys %requested_plugins) {
		next if $loaded_plugins{$plugin_name};
		if (exists $plugins_by_name{$plugin_name}) {
			push @plugins_to_load, $plugins_by_name{$plugin_name};
			push @loaded_plugin_names, $plugin_name;
		} else {
			warning "[profiles] Plugin '$plugin_name' from '$profile_sys' was not found in plugins folders\n";
		}
	}

	if (@plugins_to_load) {
		message "[profiles] Loading additional profile plugins from '$profile_sys'\n", 'system';
		Plugins::loadPlugins(\@plugins_to_load);
	}

	return @loaded_plugin_names;
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
			next if ($_ =~ /^\.|^#/);
			push @profiles, $_;
		}

		@profiles = sort { $a cmp $b } @profiles;
   		push @profiles, 'Use standard control folder';
   
		if (@profiles) {
			my $choice = $interface->showMenu(	#
				"Please choose a Profiles folder.",
				\@profiles,
				title => "Profiles Selector"
			);

			my $num = @profiles;
			return 0 if $choice == $num - 1;
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
			next if ($_ =~ /^\.|^#/);
			$found = 1 if ($new_profile eq $_);
		}
		if (!$found) {
			error "[profiles] Provided profile not found in profiles folder\n";
			return;
		}
	}
	
	my %new_requested_plugins = map { $_ => 1 } getProfileRequestedPlugins($new_profile);
	foreach my $plugin_name (keys %profile_extra_plugins) {
		next if $new_requested_plugins{$plugin_name};
		next unless grep { $_ && $_->{name} && $_->{name} eq $plugin_name } @Plugins::plugins;
		message "[profiles] Unloading extra plugin '$plugin_name' from old profile '$profile'\n", 'system';
		Plugins::unload($plugin_name);
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
	
	my @loaded_plugins = loadMissingProfilePlugins($new_profile, \%new_requested_plugins);
	my %kept_plugins = map { $_ => 1 } grep { $new_requested_plugins{$_} } keys %profile_extra_plugins;
	%profile_extra_plugins = (%kept_plugins, map { $_ => 1 } @loaded_plugins);
	
	message "[profiles] Loading finished, profile '".$new_profile."' loaded\n", "system";
	$profile = $new_profile;
}

return 1;
