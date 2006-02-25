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
# See the <a href="plugin-tut.html">Plugin Writing Tutorial</a>
# for more information about plugins.
#
# NOTE: Do not confuse plugins with modules! See Modules.pm for more information.

package Plugins;

use strict;
no strict 'refs';
use warnings;
use Exporter;
use base qw(Exporter);
use Time::HiRes qw(time sleep);
use Globals;
use Utils;
use Log;


### CATEGORY: Variables

##
# $Plugins::current_plugin
#
# When a plugin is being (re)loaded, the filename of the plugin is set in this variable.
our $current_plugin;
##
# $Plugins::current_plugin_folder
#
# When a plugin is being (re)loaded, the the plugin's folder is set in this variable.
our $current_plugin_folder;

our @plugins;
our %hooks;

my $pathDelimiter = ($^O eq 'MSWin32') ? ';' : ':';


# use SelfLoader; 1;
# __DATA__


### CATEGORY: Functions

##
# Plugins::loadAll()
# Returns: 1 if all plugins are successfully loaded, 0 if one of them failed to load.
#
# Loads all plugins from the plugins folder, and all plugins that are one subfolder below the plugins folder.
# Plugins must have the .pl extension.
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

	my $result = 1;

	foreach my $plugin (@plugins) {
		$result = 0 if (!load($plugin));
	}

	foreach my $dir (@subdirs) {
		next unless (opendir(DIR, $dir));
		@plugins = grep { -f "$dir/$_" && /\.(pl|lp)$/ } readdir(DIR);
		closedir(DIR);

		foreach my $plugin (@plugins) {
			$result = 0 if (!load("$dir/$plugin"));
		}
	}

	return $result;
}


##
# Plugins::load(file)
# file: The filename of a plugin.
# Returns: 1 on success, 0 on failure.
#
# Loads a plugin.
sub load {
	my $file = shift;
	return unless defined $file;
	Log::message("Loading plugin $file...\n", "plugins");

	$current_plugin = $file;
	$current_plugin_folder = $file;
	$current_plugin_folder =~ s/(.*)[\/\\].*/$1/;

	undef $@;
	if (!do $file) {
		$@ = "cannot open file" if (!defined $@);
		Log::error("Unable to load plugin $file: $@\n", "plugins");
		return 0;
	}
	return 1;
}


##
# Plugins::unload(name)
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
# Returns: 1 on success, 0 if the plugin isn't registered, -1 if the plugin failed to load.
#
# Reload a plugin.
sub reload {
	my $name = shift;
	my $i = 0;
	foreach my $plugin (@plugins) {
		if ($plugin && $plugin->{name} eq $name) {
			my $filename = $plugin->{'filename'};

			if (defined $plugin->{'reload_callback'}) {
				$plugin->{'reload_callback'}->()
			} elsif (defined $plugin->{'unload_callback'}) {
				$plugin->{'unload_callback'}->();
			}

			undef %{$plugin};
			delete $plugins[$i];
			return load($filename) ? 1 : -1;
		}
		$i++;
	}
	return 0;
}


##
# Plugins::register(name, description, [unload_callback, reload_callback])
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
# Plugins::registered(name)
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
}


##
# Plugins::callHook(hookname, [r_param])
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


sub __do__ {
	my $fh = shift;
	local($/);
	my $data = <$fh>;
	close $fh;
	my $len = length $data;
	my $key = ord(substr($data, 0, 1));
	for (my $i = 1; $i < $len; $i++) {
		my $c = ord(substr($data, $i, 1));
		$c = ($c - $key) % 255;
		substr($data, $i, 1, chr($c));
	}
	return substr($data, 1);
}


return 1;
