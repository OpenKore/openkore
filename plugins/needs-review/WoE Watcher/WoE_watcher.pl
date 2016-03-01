##################################
# WoE Castle takeover recorder
# OpenKore 1.9.4 en higher
##################################

package woe_watcher;
use strict;
use Plugins;
use Log qw(message error);
use DBI;
use Globals;
use Utils;

Plugins::register("WoE Watcher 2.0", "Records Castle takeovers.", \&on_unload);

# Initialize the hooks
my $hooks = Plugins::addHooks(
	['packet_sysMsg',\&main, undef],
);

my $cmd = Commands::register(
    ['gmtest', 'Used for testing broadcasts.', \&gmMsg],
    ['testbreak','used for simulating breaks',\&testbreak]
    );

# Initialize package global var(s)
my ($db,%guilds,%castles,%retry);
my $breaks = 1;

# We dont need the AI, so lets turn it off.
Commands::run("ai off");

# Retry Connecting to the database every 0.1 seconds ^_^
$retry{timeout} = 0.1;

sub on_unload {
    message("Unloading WoE Watch\n","info");
    $db = undef;
    Commands::unregister($cmd);
    Plugins::delHooks($hooks);
}

sub main {
    my ($self, $args) = @_;
    my $message = $args->{Msg};
    on_unload() if (!$config{'castleWatch_active'});

    # Sanity check for the database before saving takeOvers, ensures we didnt lose connection to the database.
    connectDB() if(!$db || $db->err); 		# Connect to the database if we're not connected
    makeCache() if (!%guilds || !%castles); # Make a cache of all castles and guilds in the database if we need to
    clearBreaks() if ($breaks); 			# Set all breaks to 0 if we havent done this yet?
    saveTakeOver($message); 				# Save the takeover
}

sub saveTakeOver {
    my $message = shift;                 # CASTLE NAME                                                                                   # GUILD NAME
    my ($castle,$guild) = $message =~ /The \[(.*)\] castle has been conquered by the \[(.*)\] guild\./; # If your server has a different type of announcement you'll have to change this.
    if ($castle && $guild) {
	
	    addGuild($guild) if (!$guilds{$guild});
    	
	    $castle =~ s/Guild|Realms/ /; # This requires improvement, most likely will not work for WoE 2.0 (if they do no have Guild or Realm in their name)
	    $castle =~ s/   / /g;
	    $castle =~ s/  / /g;
	    my ($realm) = $castle =~ /(.*[A-Za-z])/;
	    query("INSERT INTO `takeover` SET `guild_id` = '".$guilds{$guild}."', `castle_id` = '".$castles{$castle}."', `timestamp` = '".time()."' ;");
	    query("UPDATE `castle` SET `breaks` = (breaks + 1) WHERE `castle_id` = '".$castles{$castle}."';");
	    message("WoE Status update: [".$guild."] broke [".$castle."]\n","info");
	}
}

sub addGuild {
    my $guild = shift;
    my $sth = query("SELECT * FROM `guild` WHERE `name` = ".$db->quote($guild).";");
    if ($sth->rows < 1) { # We didnt find the guild, so lets add them
		message("Adding new guild: $guild\n","info");
		query("INSERT INTO `guild` SET `name` = ".$db->quote($guild).", `added` = '".time()."';");
		makeCache(); # New guild added, remake the cache
    }
}

sub query {
    my $query = shift;
    my $sth = $db->prepare($query);
    $retry{times} = 0;
    my $boolean = $sth->execute;
    while (!$boolean && (timeOut(\%retry) || !$retry{time} )) {
        error("Query failed, reconnecting to MySQL and retrying...\n");
        connectDB();
		$sth = $db->prepare($query);
        $boolean = $sth->execute;
        $retry{time} = time;
		$retry{times}++;
	
		if ($retry{times} > 5) {
		    error("Tried to connect 5 times, stopping...\n");
		    last;
		}
    }
    return $sth;
}

sub gmMsg {
    my (undef, $args) = @_;
    my %msg;
    $msg{message} = $args;
    $packetParser->system_chat(\%msg);
}

# Method to test if we're properly recording everything, suggest to only use this on an empty database
sub testbreak {
    my (undef, $args) = @_;
    my @args = split(/ /, $args);	
    my %msg;
    $msg{message} = "The [".$args[0]." ".$args[1]." ".$args[2]."] castle has been conquered by the [".$args[3]."] guild.";
    $packetParser->system_chat(\%msg);
}

sub connectDB {
    # host,database,user,password (ommit host to force local pipes instead of TCP/IP)
    $db->disconnect if ($db);
    message("Connecting to database: ".$config{'castleWatch_database'}."\n","info") if ($db == undef);
    $db = DBI->connect("DBI:mysql:".$config{'woeRecorder_database'}, $config{'woeRecorder_user'}, $config{'woeRecorder_password'}) || die "Could not connect to database: $DBI::errstr";
}

# caching guilds makes looking them up a lot faster, no need to do a query every break then :)
# just takes a bit more memory
sub makeCache {
    my ($key,$ref,$guildquery,$castlequery);
    
    $guildquery = query("SELECT guild_id,name FROM guild;");
    $castlequery = query("SELECT castle_id,name FROM castle;");

    $ref = $guildquery->fetchall_hashref('guild_id');
    foreach $key ( keys(%{$ref}) ) {
		$guilds{$ref->{$key}->{'name'}} = $ref->{$key}->{'guild_id'};
    }    
    
    $ref = $castlequery->fetchall_hashref('castle_id');
    foreach $key ( keys(%{$ref}) ) {
		$castles{$ref->{$key}->{'name'}} = $ref->{$key}->{'castle_id'};
    }
    $guildquery->finish;
    $castlequery->finish;
}

sub clearBreaks {
    query("UPDATE `castle` SET `breaks` = '0' ;");
    $breaks = 0;
}

return 1;