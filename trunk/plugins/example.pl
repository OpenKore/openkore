package ExamplePlugin;

use strict;
use Plugins;
use Log;

my $ai_hook;

# Take a look at http://openkore.sourceforge.net/srcdoc/Plugins.html
# for more info about these functions
Plugins::register('example', 'Example Plugin', \&on_unload, \&on_reload);
$ai_hook = Plugins::addHook('AI_pre', \&ai_alled);


sub on_unload {
	Plugins::delHook('AI_pre', $ai_hook);
	Log::message "Example plugin unloaded\n";
}

sub on_reload {
	# For now, do the same thing as unload
	&on_unload;
}


my $count = 0;
sub Called {
	if ($count == 0) {
		$count++;
		Log::message "I am example.pl and I will spam this message the first time the AI() function is called.\n";
	}
}


# Important! Otherwise plugin will appear to fail to load.
return 1;
