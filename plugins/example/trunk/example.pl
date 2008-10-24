package ExamplePlugin;

use strict;
use Plugins;
my $count = 0 if (!defined my $count);


Plugins::register('example', 'Example Plugin', \&Unload, \&Reload);
Plugins::addHook('AI_pre', \&Called);

sub Unload {
	print "I have just been unloaded\n";
}

sub Reload {
	print "I have just been reloaded\n";
}

sub Called {
	if ($count == 0) {
		$count++;
		print "I am example.pl and I will spam this message the first time the AI sequence is started.\n";
	}
}


# Important! Otherwise plugin will appear to fail to load.
return 1;
