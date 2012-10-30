# richLogWebMonitor plugin by imikelance/marcelofoxes/KeplerBR
# Acknowledgments: EternalHarvest 
#########################################################
# [EN] This plugin was originally richLog (old name: logDaBandaRestart)
# and adapted by KeplerBR to WebMonitor plugin
# Official's link in Brazilian Community :
# * http://openkore.com.br/index.php?/topic/2027-richlog-logdabandarestart-by-imikelance/
# International :
#* http://forums.openkore.com/viewtopic.php?f=34&t=16866

# [PT-BR] Esse plugin originalmente era o richLog (antigo nome: logDaBandaRestart)
# e foi adaptado por KeplerBR para o plugin WebMonitor
# Link na comunidade oficial brasileira:
# * http://openkore.com.br/index.php?/topic/2027-richlog-logdabandarestart-by-imikelance/
# Link na comunidade internacional:
# * http://forums.openkore.com/viewtopic.php?f=34&t=16866


package chatLogWebMonitor;

use strict;

use Plugins;
use Commands;
use Log qw( warning message error );
use Settings;
use Globals;
use Misc;
use Utils qw( getFormattedDate );

use constant {
    PLUGINNAME                =>    "logDaBandaRestart",
};

#-----------------
# Plugin: settings
#-----------------
# Log hook
my $logHook = Log::addHook(\&on_Log, PLUGINNAME);

#---------------
# Plugin: unload
#---------------
sub unload {
   Log::delHook($logHook);
   undef $logHook;
}

#------------------
# [PT-BR] Iniciando
#------------------
my $caminho = $webMonitorPlugin::path . '/WWW/chatlog.html.template';


# [PT-BR] Caso o arquivo já exista, será deletado
if (-e $caminho){
unlink($caminho);
}

#-------------
# Log: handler
#-------------

sub on_Log {
    my ($type, $domain, $level, $globalVerbosity, $message, $user_data) = @_;
    my (@messageSplit, @messageSplit2);
    if ($level <= $globalVerbosity) {
    my $msgColor;
    if (defined $consoleColors{$type}{$domain}) {
		my $message2;
		$message =~ s/(\r\n|\n|\r)+/<\/br>/g;
		if ($domain eq "selfchat") {
			@messageSplit = split(/ : /, $message, 2);
			$message2 = "<span class=\"selfchat\">[" . getFormattedDate(time) . "] [You]  <b>" . @messageSplit[0] . ":</b> " . @messageSplit[1] . "</span>";
		} elsif ($domain eq "publicchat") {
			@messageSplit = split(/] /, $message, 2);
			@messageSplit2 = split(/: /, $messageSplit[1], 2);
			$message2 = "<span class=\"publicchat\">[" . getFormattedDate(time) . "] [Public Chat]  <b>". @messageSplit2[0] .":</b> "  . @messageSplit2[1] . "</span>";
		} elsif ($domain eq "partychat") {
			$message2 = "<span class=\"partychat\">[" . getFormattedDate(time) . "] [Party Chat]  ". $message ."</span>";
		} elsif ($domain eq "guildchat") {
			$message2 = "<span class=\"guildchat\">[" . getFormattedDate(time) . "] [Party Chat]  ". $message ."</span>";
		} elsif ($domain eq "pm") {
			@messageSplit = split(/ : /, $message, 2);
			$message2 = "<span class=\"pm\">[" . getFormattedDate(time) . "] [PM]  <b>" . @messageSplit[0] . ":</b> " . @messageSplit[1] . "</span>";
		} elsif ($domain eq "pm/sent") {
			@messageSplit = split(/ : /, $message, 2);
			$message2 = "<span class=\"pm/sent\">[" . getFormattedDate(time) . "] [PM You]  <b>" . @messageSplit[0] . ":</b> " . @messageSplit[1] . "</span>";
		}

		open(F, ">>:utf8", $caminho);
			if(-z $caminho) {
			print F q(
<head><style type="text/css">

body {
    background-color: white;
    font-family: "Lucida Console";
    font-size: 12px;
}

.selfchat {
    color: #62893f;
}

.publicchat {
    color: #8ac358;
}

.partychat {
    color: #c39758;
}

.guildchat {
    color: #58c365;
}

.pm {
    color: #c9c02a;
}

.pm/sent {
    color: #b1a925;
}

 </style>
 <meta http-equiv="refresh" content="2">
 <meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
 </head>
 
<script type="application/javascript">
	function descer() {
		window.scrollTo(0,99999);
	}
</script>

<input type="button" onclick="descer()" value="Jump down" /><br>
 );
			}
			print F $message2."\n";
			close(F);
		}
	 
    }
}

1;