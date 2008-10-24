package ExamplePlugin2;

use strict;
use Plugins;
my $count = 0 if (!defined my $count);

Plugins::register('example2', 'Example Plugin number 2', \&Unload, \&Reload);
Plugins::addHook('AI_pre', \&Called);

sub Unload {
	print "I (#2) have just been unloaded\n";
}

sub Reload {
	print "I (#2) have just been reloaded\n";
}

sub Called {
	if ($count == 0) {
		$count++;
		print "I am example2.pl and I will spam this message every time the AI sequence is started\n";
	}
}


# Important! Otherwise plugin will appear to fail to load.
return 1;
