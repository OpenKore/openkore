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
# See the <a href="http://openkore.sourceforge.net/srcdoc/plugin-tut.html">Plugin Writing Tutorial</a>
# for more information about plugins.
#
# NOTE: Do not confuse plugins with modules! See Modules.pm for more information.

# TODO: use events instead of printing log information directly.

package Plugins;

use strict;
use warnings;
use Time::HiRes qw(time sleep);
use Exception::Class ('Plugin::LoadException');

use Modules 'register';
use Globals;
use Utils;
use Log qw(message);
use Translation qw(T TF);


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

my $pathDelimiter = ($^O eq 'MSWin32') ? ';' : ':';


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
sub loadAll {
	my (@plugins, @subdirs);

	foreach my $dir (split /($pathDelimiter)+/, $Settings::plugins_folder) {
		my @items;

		next if (!opendir(DIR, $dir));
		@items = readdir DIR;
		closedir DIR;

		foreach my $file (@items) {
			push @plugins, "$dir/$file" if (-f "$dir/$file" && $file =~ /\.(pl|lp)$/);
		}
		foreach my $subdir (@items) {
			push @subdirs, "$dir/$subdir" if (-d "$dir/$subdir" && $subdir !~ /^(\.|CVS$)/i);
		}
	}

	foreach my $plugin (@plugins) {
		load($plugin);
	}

	foreach my $dir (@subdirs) {
		next unless (opendir(DIR, $dir));
		@plugins = grep { -f "$dir/$_" && /\.(pl|lp)$/ } readdir(DIR);
		closedir(DIR);

		foreach my $plugin (@plugins) {
			load("$dir/$plugin");
		}
	}
}


##
# void Plugins::load(String file)
# file: The filename of a plugin.
#
# Loads a plugin.
#
# Throws Plugin::LoadException if it failed to load.
sub load {
	my $file = shift;
	message(TF("Loading plugin %s...\n", $file), "plugins");

	$current_plugin = $file;
	$current_plugin_folder = $file;
	$current_plugin_folder =~ s/(.*)[\/\\].*/$1/;

	if (! -f $file) {
		Plugin::LoadException->throw(TF("File %s does not exist.", $file));
	}

	undef $!;
	undef $@;
	if (!defined(do $file)) {
		if ($@) {
			Plugin::LoadException->throw(TF("Plugin contains syntax errors:\n%s", $@));
		} else {
			message "aaaa\n";
			Plugin::LoadException->throw("$!");
		}
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
	my $i = 0;
	foreach my $plugin (@plugins) {
		if ($plugin && $plugin->{name} eq $name) {
			$plugin->{unload_callback}->() if (defined $plugin->{unload_callback});
			delete $plugins[$i];
			return 1;
		}
		$i++;
	}
	return 0;
}


##
# Plugins::unloadAll()
#
# Unloads all registered plugins.
sub unloadAll {
	my $name = shift;
	foreach my $plugin (@plugins) {
		next if (!$plugin);
		$plugin->{unload_callback}->() if (defined $plugin->{unload_callback});
		undef %{$plugin};
	}
	undef @plugins;
	return 0;
}


##
# Plugins::reload(name)
# name: The name of the plugin to reload.
# Returns: 1 on success, 0 if the plugin isn't registered.
#
# Reload a plugin.
#
# Throws Plugin::LoadException if it failed to load.
sub reload {
	my $name = shift;
	my $i = 0;
	foreach my $plugin (@plugins) {
		if ($plugin && $plugin->{name} eq $name) {
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
# void Plugins::registered(String name)
# name: The plugin's name.
# Returns: 1 if the plugin's registered, 0 if it isn't.
#
# Checks whether a plugin is registered.
sub registered {
	my $name = shift;
	foreach (@plugins) {
		return 1 if ($_ && $_->{'name'} eq $name);
	}
	return 0;
}


##
# Plugins::addHook(hookname, r_func, [user_data])
# hookname: Name of a hook.
# r_func: Reference to the function to call.
# user_data: Additional data to pass to r_func.
# Returns: An ID which can be used to remove this hook.
#
# Add a hook for $hookname. Whenever Kore calls Plugins::callHook('foo'),
# r_func is also called.
#
# See also Plugins::callHook() for information about how r_func is called.
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
	my $hookname = shift;
	my $r_func = shift;
	my $user_data = shift;

	my %hook = (
		r_func => $r_func,
		user_data => $user_data
	);
	$hooks{$hookname} = [] if (!defined $hooks{$hookname});
	return binAdd($hooks{$hookname}, \%hook);
}

##
# Plugins::addHooks( [hookname, r_func, user_data], ... )
# Returns: a reference to an array. You need it for Plugins::delHooks()
#
# A convenience function for adding many hooks with one function.
#
# See also: Plugins::addHook(), Plugins::delHooks()
#
# Example:
# $hooks = Plugins::addHooks(
# 	['AI_pre',       \&onAI_pre, undef],
# 	['mainLoop_pre', \&onMainLoop_pre, undef]
# );
# Plugins::delHooks($hooks);
#
# # The above is the same as:
# $hook1 = Plugins::addHook('AI_pre', \&onAI_pre);
# $hook2 = Plugins::addHook('mainLoop_pre', \&onMainLoop_pre);
# Plugins::delHook('AI_pre', $hook1);
# Plugins::delHook('mainLoop_pre', $hook2);
sub addHooks {
	my @hooks;
	for my $hook (@_) {
		my %hash = (
			name => $hook->[0],
			ID => addHook(@{$hook})
		);
		push @hooks, \%hash;
	}
	return \@hooks;
}

##
# Plugins::delHook(hookname, ID)
# hookname: Name of a hook.
# ID: The ID of the hook, as returned by Plugins::addHook()
#
# Removes a hook. r_func will not be called anymore.
#
# See also: Plugins::addHook()
#
# Example:
# Plugins::register('example', 'Example Plugin', \&on_unload, \&on_reload);
# my $hook = Plugins::addHook('AI_pre', \&ai_called);
#
# sub on_unload {
#     Plugins::delHook('AI_pre', $hook);
#     Log::message "Example plugin unloaded.\n";
# }
sub delHook {
	my $hookname = shift;
	my $ID = shift;
	delete $hooks{$hookname}[$ID] if ($hookname && $hooks{$hookname});
}

##
# Plugins::delHooks($hooks)
# $hooks: the return value Plugins::addHooks()
#
# Removes all hooks that are registered by Plugins::addHook().
#
# See also: Plugins::addHooks(), Plugins::delHook()
sub delHooks {
	delHook($_->{name}, $_->{ID}) foreach (@{$_[0]});
	@{$_[0]} = ();
}


##
# void Plugins::callHook(hookname, [r_param])
# hookname: Name of the hook.
# r_param: A reference to a hash that will be passed to the hook functions.
#
# Call all functions which are associated with the hook $hookname.
#
# r_hook is called as follows: $r_hook->($hookname, $r_param, userdata as passed to addHook);
#
# See also: Plugins::addHook()
sub callHook {
	my $hookname = shift;
	my $r_param = shift;
	return if (!$hooks{$hookname});

	foreach my $hook (@{$hooks{$hookname}}) {
		next if (!$hook);
		$hook->{r_func}->($hookname, $r_param, $hook->{user_data});
	}
}


return 1;