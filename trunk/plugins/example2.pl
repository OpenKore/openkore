package ExamplePlugin3;

use strict;
use Plugins;
use Log;


my $command_hook;

Plugins::register('example3', 'Example Plugin #3', \&on_unload, \&on_reload);
$command_hook = Plugins::addHook('Command_post', \&command_called);


sub on_unload {
	Plugins::delHook('Command_post', $command_hook);
	Log::message "Example Plugin #3 unloaded\n";
}

sub on_reload {
	&on_unload;
}

sub command_called {
	my $temp = shift;
	my $input = shift;
	my ($switch, $args) = split(' ', $input, 2);

	my %input_hash = (command => $switch, args => $args);
	print "A command ".$input_hash{command}." with the arguments ".$input_hash{args}." failed to meet any inbuilt command.\n";
}

# Important! Otherwise plugin will appear to fail to load.
return 1;
