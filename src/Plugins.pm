#########################################################################
#  OpenKore - Plugin system
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#
#  $Revision$
#  $Id$
#
#########################################################################
##
# MODULE DESCRIPTION: Plugin system
#
# This module provides an interface for handling plugins.
# See the <a href="http://wiki.openkore.com/index.php/How_to_write_plugins_for_OpenKore">Plugin
# Writing Tutorial</a> for more information about plugins.
#
# NOTE: Do not confuse plugins with modules! See Modules.pm for more information.

# TODO: use events instead of printing log information directly.

package Plugins;

use strict;
use warnings;
use Time::HiRes qw(time sleep);
use Exception::Class ('Plugin::LoadException', 'Plugin::DeniedException');

use Modules 'register';
use Globals;
use Utils qw(stringToQuark quarkToString);
use Utils::DataStructures qw(binAdd existsInList);
use Utils::ObjectList;
use Utils::Exceptions;
use Log qw(message warning);
use Translation qw(T TF);
use Settings qw(%sys);


#############################
### CATEGORY: Variables
#############################

##
# String $Plugins::current_plugin
#
# When a plugin is being (re)loaded, the filename of the plugin is set in this variable.
our $current_plugin;

##
# String $Plugins::current_plugin_folder
#
# When a plugin is being (re)loaded, the the plugin's folder is set in this variable.
our $current_plugin_folder;

our @plugins;
our %hooks;

use enum qw(HOOKNAME INDEX);
use enum qw(CALLBACK USER_DATA);


#############################
### CATEGORY: Functions
#############################

##
# void Plugins::loadAll()
#
# Loads all plugins from the plugins folder, and all plugins that are one subfolder below
# the plugins folder. Plugins must have the .pl extension.
#
# Throws Plugin::LoadException if a plugin failed to load.
# Throws Plugin::DeniedException if the plugin system refused to load a plugin. This can
# happen, for example, if it detects that a plugin is incompatible.
sub loadAll {
	my $condition;
	if (!exists $sys{'loadPlugins'}) {
		message T("Loading all plugins (by default)...\n", 'plugins');
		$condition = \&c_loadAll;
	} elsif (!$sys{'loadPlugins'}) {
		message T("Automatic loading of plugins disabled\n", 'plugins');
		return;
	} elsif ($sys{'loadPlugins'} eq '1') {
		message T("Loading all plugins...\n", 'plugins');
		$condition = \&c_loadAll;
	} elsif ($sys{'loadPlugins'} eq '2') {
		message T("Selectively loading plugins...\n", 'plugins');
		$condition = \&c_loadSelected;
	} elsif ($sys{'loadPlugins'} eq '3') {
		message T("Selectively skipping plugins...\n", 'plugins');
		$condition = \&c_loadNotSelected;
	}

	my @folders = Settings::getPluginsFolders();
	foreach my $file (getFilesFromDirs(\@folders, 'pl|lp', 'cvs', 1)) {
		load("$file->{dir}/$file->{name}$file->{ext}") if (&$condition($file->{name}));
		return if $quit;
	}
}

sub c_loadAll { return 1 };
sub c_loadSelected { return existsInList($sys{'loadPlugins_list'}, shift)};
sub c_loadNotSelected { return !existsInList($sys{'skipPlugins_list'}, shift)};

sub getFilesFromDirs {
	my ($dirs, $f_exts, $d_ignores, $recurse_lv) = @_;
	my @files;
	foreach my $dir (@{$dirs}) {
		next if (!opendir(DIR, $dir));
		my @items = readdir DIR;
		closedir DIR;
		foreach my $item (@items) {
			if (-f "$dir/$item" && $item =~ /(.*)(\.($f_exts))$/) {
				push @files, {dir => $dir, name => $1, ext => $2};
				#message "dir:$dir file:$1 ext:$2\n";
			} elsif (-d "$dir/$item" && $item !~ /^(\.|$d_ignores$)/i && $recurse_lv) {
				push @files, getFilesFromDirs(["$dir/$item"], $f_exts, $d_ignores, $recurse_lv-1);
			}
		}
	}
	return @files;
}

##
# void Plugins::load(String file)
# file: The filename of a plugin.
#
# Loads a plugin.
#
# Throws Plugin::LoadException if it failed to load.
# Throws Plugin::DeniedException if the plugin system refused to load this plugin. This can
# happen, for example, if it detects that a plugin is incompatible.
sub load {
	my $file = shift;
	message(TF("Loading plugin %s...\n", $file), "plugins");

	if (! -f $file) {
		warning TF("File %s does not exist. (usage ex: plugin load plugins/macro/macro.pl)\n", $file);
	} elsif ($file =~ /(^|\/)ropp\.pl$/i) {
		Plugin::DeniedException->throw(TF("The ROPP plugin (ropp.pl) is obsolete and is " .
			"no longer necessary. Please remove it, or %s will not work correctly.",
			$Settings::NAME || "OpenKore"));
	} else {
		$current_plugin = $file;
		$current_plugin_folder = $file;
		$current_plugin_folder =~ s/(.*)[\/\\].*/$1/;

		undef $!;
		undef $@;
		if (!defined(do $file)) {
			if ($@) {
				Plugin::LoadException->throw(TF("Plugin contains syntax errors:\n%s", $@));
			} else {
				Plugin::LoadException->throw("$!");
			}
		}
		undef $current_plugin;
		undef $current_plugin_folder;		
	}
}


##
# boolean Plugins::unload(name)
# name: The name of the plugin to unload.
# Returns: 1 if the plugin has been successfully unloaded, 0 if the plugin isn't registered.
#
# Unloads a registered plugin.
sub unload {
	my $name = shift;
	return 0 if (!defined $name);
	my $i = 0;
	foreach my $plugin (@plugins) {
		if ($plugin && $plugin->{name} && $plugin->{name} eq $name) {
			$plugin->{unload_callback}->() if (defined $plugin->{unload_callback});
			delete $plugins[$i];
			return 1;
		}
		$i++;
	}
	return 0;
}


##
# void Plugins::unloadAll()
#
# Unloads all registered plugins.
sub unloadAll {
	foreach my $plugin (@plugins) {
		next if (!$plugin);
		$plugin->{unload_callback}->() if (defined $plugin->{unload_callback});
	}
	@plugins = ();
}


##
# boolean Plugins::reload(String name)
# name: The name of the plugin to reload.
# Returns: 1 on success, 0 if the plugin isn't registered.
#
# Reload a plugin.
#
# Throws Plugin::LoadException if it failed to load.
sub reload {
	my $name = shift;
	return 0 if(!defined $name);
	my $i = 0;
	foreach my $plugin (@plugins) {
		if ($plugin && $plugin->{name} && $plugin->{name} eq $name) {
			my $filename = $plugin->{filename};

			if (defined $plugin->{reload_callback}) {
				$plugin->{reload_callback}->()
			} elsif (defined $plugin->{unload_callback}) {
				$plugin->{unload_callback}->();
			}

			undef %{$plugin};
			delete $plugins[$i];
			load($filename);
			return 1;
		}
		$i++;
	}
	return 0;
}


##
# void Plugins::register(String name, String description, [unload_callback, reload_callback])
# name: The plugin's name.
# description: A short one-line description of the plugin.
# unload_callback: Reference to a function that will be called when the plugin is being unloaded.
# reload_callback: Reference to a function that will be called when the plugin is being reloaded.
# Returns: 1 if the plugin has been successfully registered, 0 if a plugin with the same name is already registered.
#
# Plugins should call this function when they are loaded. This function registers
# the plugin in the plugin database. Registered plugins can be unloaded by the user.
#
# In the unload/reload callback functions, plugins should delete any hook functions they added.
# See also: Plugins::addHook(), Plugins::delHook()
sub register {
	my $name = shift;
	return 0 if registered($name);

	my %plugin_info = (
		name => $name,
		description => shift,
		unload_callback => shift,
		reload_callback => shift,
		filename => $current_plugin
	);

	binAdd(\@plugins, \%plugin_info);
	return 1;
}


##
# boolean Plugins::registered(String name)
# name: The plugin's name.
# Returns: 1 if the plugin's registered, 0 if it isn't.
#
# Checks whether a plugin is registered.
sub registered {
	my $name = shift;
	return 0 if (!defined $name);
	foreach (@plugins) {
		return 1 if ($_ && $_->{name} && $_->{name} eq $name);
	}
	return 0;
}

##
# Plugins::addHook(String hookname, callback, [user_data])
# hookname: Name of a hook.
# callback: Reference to the function to call.
# user_data: Additional data to pass to callback.
# Returns: A handle which can be used to remove this hook.
#
# Add a hook for $hookname. Whenever Kore calls Plugins::callHook('foo'),
# callback is also called.
#
# See also Plugins::callHook() for information about how callback is called.
#
# Example:
# # Somewhere in your plugin:
# use Plugins;
# use Log;
#
# my $hook = Plugins::addHook('AI_pre', \&ai_called);
#
# sub ai_called {
#     Log::message("Kore's AI() function has been called.\n");
# }
#
# # Somewhere in the Kore source code:
# sub AI {
#     ...
#     Plugins::callHook('AI_pre');   # <-- ai_called() is now also called.
#     ...
# }
sub addHook {
	my ($hookName, $callback, $user_data) = @_;
	my $hookList = $hooks{$hookName} ||= new ObjectList();

	my @entry;
	$entry[CALLBACK] = $callback;
	$entry[USER_DATA] = $user_data if defined($user_data);

	my @handle;
	$handle[HOOKNAME] = stringToQuark($hookName);
	$handle[INDEX] = $hookList->add(bless(\@entry, "Plugins::HookEntry"));
	return bless(\@handle, 'Plugins::HookHandle');
}

##
# Plugins::addHooks( [hookName, callback, user_data], ... )
# Returns: A handle, which can be used with Plugins::delHook()
#
# A convenience function for adding many hooks with one function.
#
# See also: Plugins::addHook(), Plugins::delHook()
#
# Example:
# $hooks = Plugins::addHooks(
# 	['AI_pre',       \&onAI_pre],
# 	['mainLoop_pre', \&onMainLoop_pre, $some_user_data]
# );
# Plugins::delHook($hooks);
#
# # The above is the same as:
# $hook1 = Plugins::addHook('AI_pre', \&onAI_pre);
# $hook2 = Plugins::addHook('mainLoop_pre', \&onMainLoop_pre);
# Plugins::delHook($hook1);
# Plugins::delHook($hook2);
sub addHooks {
	my @hooks;
	foreach my $params (@_) {
		push @hooks, addHook(@{$params});
	}
	return bless(\@hooks, "Plugins::HookHandles");
}

##
# Plugins::delHook(hookname, handle)
# hookname: Name of a hook.
# handle: A hook handle, as returned by Plugins::addHook()
#
# Removes a registered hook. $callback will not be called anymore.
#
# See also: Plugins::addHook()
#
# Example:
# Plugins::register('example', 'Example Plugin', \&on_unload, \&on_reload);
# my $hook = Plugins::addHook('AI_pre', \&ai_called);
#
# sub on_unload {
#     Plugins::delHook($hook);
#     Log::message "Example plugin unloaded.\n";
# }
sub delHook {
	my ($handle) = @_;
	if (@_ > 1) {
		# More than one parameter was passed. This means that the plugin
		# is still using the old API. Make sure things are backwards
		# compatible.
		shift;
		($handle) = @_;
	}

	if (UNIVERSAL::isa($handle, 'Plugins::HookHandles')) {
		foreach my $singleHandle (@{$handle}) {
			delHook($singleHandle);
		}
		undef @{$handle};

	} elsif (UNIVERSAL::isa($handle, 'Plugins::HookHandle') && defined $handle->[HOOKNAME]) {
		my $hookName = quarkToString($handle->[HOOKNAME]);
		my $hookList = $hooks{$hookName};
		if ($hookList) {
			my $entry = $hookList->get($handle->[INDEX]);
			$hookList->remove($entry);
		}
		delete $handle->[HOOKNAME];
		delete $handle->[INDEX];
		undef $handle;

		if ($hookList && $hookList->size() == 0) {
			delete $hooks{$hookName};
		}

	} else {
		ArgumentException->throw("Invalid hook handle passed to Plugins::delHook().");
	}
}

##
# Plugins::delHooks(hooks)
#
# An alias for Plugins::delHook(), for backwards compatibility reasons.
sub delHooks {
	&delHook;
}


##
# void Plugins::callHook(String hookName, [argument])
# hookName: Name of the hook.
# argument: An argument to pass to the hook's callback functions.
#
# Call all callback functions which are associated with the hook $hookName.
# Adding or removing callbacks during callHook will not affect the current call.
#
# The hook's callback function is called as follows:
# <pre class="example">
# $callback->($hookName, $argument, userdata as passed to addHook);
# </pre>
#
# See also: Plugins::addHook()
sub callHook {
	my ($hookName, $argument) = @_;
	my $hookList = $hooks{$hookName};
	if ($hookList) {
		my @items = @{ $hookList->getItems };
		foreach my $entry (@items) {
			$entry->[CALLBACK]->($hookName, $argument, $entry->[USER_DATA]);
		}
	}
}

##
# boolean Plugins::hasHook(String hookName)
#
# Check whether there are any hooks registered for the specified hook name.
sub hasHook {
	my ($hookName) = @_;
	return defined $hooks{$hookName};
}

1;
