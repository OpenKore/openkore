package ExamplePlugin3;

use Plugins;
use strict;

Plugins::register('example3', 'Example Plugin number 3', \&Unload, \&Reload);
Plugins::addHook('Command_post', \&Called);

sub Unload {
	print "I have just been unloaded\n";
}

sub Reload {
	print "I (#3) have just been reloaded\n";
}

sub Called {
	my $temp = shift;
	my $input = shift;
	my ($switch, $args) = split(' ', $input, 2);
	
	my %input_hash = (command => $switch, args => $args);
	print "A command ".$input_hash{command}." with the arguments ".$input_hash{args}." failed to meet any inbuilt command.\n";
}

# Important! Otherwise plugin will appear to fail to load.
return 1;
