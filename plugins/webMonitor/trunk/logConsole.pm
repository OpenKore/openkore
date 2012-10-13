# logDaBandaRestart plugin by iMikeLance
#
# Lite version for webMonitor - BonScott

package logConsoleWebMonitor;

use strict;
use Plugins;
use Settings;
use Globals;
use Misc;
use constant {
	PLUGINNAME				=>	"logDaBandaRestartLite",
};


#-----------------
# Plugin: settings
#-----------------
Plugins::register(PLUGINNAME, "webMonitor logConsole", \&unload);

# Log hook
my $logHook = Log::addHook(\&on_Log, PLUGINNAME);
my $caminho = 'plugins/webMonitor/WWW/logConsole.html';
if (-e $caminho){
unlink($caminho);
}
#---------------
# Plugin: unload
#---------------
sub unload {
   Log::delHook($logHook);
   undef $logHook;
}
#-------------
# Log: handler
#-------------
sub on_Log {
	my ($type, $domain, $level, $globalVerbosity, $message, $user_data) = @_;
	
	if ($level <= $globalVerbosity) {
	my $msgColor;
	if (defined $consoleColors{$type}{$domain}) {
			$msgColor = $consoleColors{$type}{$domain};
		} elsif ($type eq "warning") {
			$msgColor = $consoleColors{warning}{default};
		} elsif ($type eq "error") {
			$msgColor = $consoleColors{error}{default};
        } elsif ($type eq "debug") {
            $msgColor = $consoleColors{debug}{default};
		} else {
			$msgColor = 'grey';
	}
	$message =~ s/(\r\n|\n|\r)+/<\/br>/g;
	my $message2 ="<span class=\"".$msgColor."\">".$message."</span>";
	
    open(F, ">>:utf8", $caminho);
        if(-z $caminho) {
			print F q(
<head>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
<meta http-equiv="refresh" content="1">
<link href="css/custom.css" rel="stylesheet">
<script type='text/javascript' src='js/custom.js'></script>
</head><body class="bodyConsole">
 );
		}
		print F $message2."\n";
		close(F);
	}
	
}

1;