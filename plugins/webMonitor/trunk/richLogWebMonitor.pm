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


package richLogWebMonitor;

use strict;

use Plugins;
use Commands;
use Log qw( warning message error );
use Settings;
use Globals;
use Misc;

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
my $caminho = 'plugins/webMonitor/WWW/log.html.template';

# [PT-BR] Caso o arquivo já exista, será deletado
if (-e $caminho){
unlink($caminho);
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
	
    my $message2 ="<span class=\"".$msgColor."\">[" . $domain . "] ".$message."</span>";
	
    open(F, ">>:utf8", $caminho);
        if(-z $caminho) {
            print F q(
<head><style type="text/css">

body {
    background-color: black;
    font-family: "Lucida Console";
    font-weight: bold;
    font-size: 12px;
}

.grey {
    color: #c0c0c0;
}

.yellow {
    color: #ffff00;
}

.darkgreen {
    color: #008000;
}

.green {
    color: #00FF00;
}

.white {
    color: #FFFFFF;
}

.red {
    color: #FF0000;
}

.cyan {
    color: #00FFFF;
}

.darkmagenta {
    color: #800080;
}

.magenta {
    color: #ff00ff;
}

.blue {
    color: #0000ff;
}

.darkcyan {
    color: #008080;
}

.brown {
    color: #808000;
}

 </style>
 <meta http-equiv="refresh" content="2">
 <meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
 <SCRIPT language=JavaScript1.2> 
//change 1 to another integer to alter the scroll speed. Greater is faster
var speed=50
var currentpos=0,alt=1,curpos1=0,curpos2=-1
function initialize(){
startit()
}
function scrollwindow(){
if (document.all &&
!document.getElementById)
temp=document.body.scrollTop
else
temp=window.pageYOffset
if (alt==0)
alt=2
else
alt=1
if (alt==0)
curpos1=temp
else
curpos2=temp
if (curpos1!=curpos2){
if (document.all)
currentpos=document.body.scrollTop+speed
else
currentpos=window.pageYOffset+speed
window.scroll(0,currentpos)
}
else{
currentpos=0
window.scroll(0,currentpos)
}
}
function startit(){
setInterval("scrollwindow()",1)
}
window.onload=initialize
</SCRIPT>
 </head>


 );
        }
        
		print F $message2."\n";
        close(F);
		
    }
    
}

1;