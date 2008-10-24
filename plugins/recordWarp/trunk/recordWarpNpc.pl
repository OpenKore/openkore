############################
# recordWarpNpc plugin for OpenKore by Damokles
#
# This software is open source, licensed under the GNU General Public
# License, version 2.
#
# To use it just type 'warprec' before you talk to a warp npc. Don't do
# anything between it. It'll record the NPC and the conversation seq and
# destination. They'll be combined in warpportals.txt.
#
# You can use 'warprec save' to trigger the save routine. You may need this
# if you only warp on the same map. Eg. Guild Warp
#
# This plugin should be in a subfolder of plugins like 'plugins/recordWarpNpc'.
#
# Config Options:
#
# recordWarpNpc_integrate (flag) -	if is set to 1 it'll integrate the portals in
#									portals.txt
# recordWarpNpc_recompile (flag) -	integrate has to be enabled. Will reload and
#									recompile the portals and portalsLOS.
############################

package recordWarpNpc;

use strict;
use Plugins;
use Globals qw(%config %npcs @npcsID %field $char);
use Settings;
use Log qw(message warning error debug);
use Utils;


Plugins::register('recordWarpNpc', 'Records Warp Npcs', \&onUnload);

my $hooks = Plugins::addHooks(
	['packet/map_change', \&onMapChange, undef],
	['packet/map_changed', \&onMapChanged, undef],
	['packet/map_loaded', \&onMapLoaded, undef]
);

my $cmd = Commands::register(
	["warprec", ['Records Warpnpc and conversation seq.',['','toggles record on/off'],['save','triggers save routine']], \&cmdWarprec],
	["talk", "extends the Talk command", \&cmdTalk]
);

my $pluginDir = $Plugins::current_plugin_folder;
my %info;

sub onUnload {
    Plugins::delHooks($hooks);
    Commands::unregister($cmd);
    undef %info;
}

sub cmdWarprec {
	my ($self,$args) = @_;
	my ($arg1) = $args =~ /^(\w+)/;
	if ($info{recording}){
		if ($arg1 eq 'save') {
			saveDest({map=>$field{name},x=>$char->{pos}{x},y=>$char->{pos}{y}});
		} else {
			message "Warpnpc Recording OFF.\n",'recordWarpNpc';
			%info = undef;
		}
	} else {
		$info{recording} = 1;
		message "Warpnpc Recording ON.\n",'recordWarpNpc';
	}
}

sub onMapChange {
	my (undef,$args) = @_;
	return 1 unless $info{recording};
	my %param = %{$args};
	$param{map} =~ s/.gat$//;
	saveDest(\%param);
}

sub onMapChanged {
	$info{mapChanged} = 1 if $info{recording};
}

sub onMapLoaded {
	return 1 unless $info{recording};
	saveDest({map=>$field{name},x=>$char->{pos}{x},y=>$char->{pos}{y}});
}

sub cmdTalk {
	my ($switch,$args) = @_;

	return Commands::cmdTalk($switch,$args) unless $info{recording};

	my ($arg1) = $args =~ /^(\w+)/;
	my ($arg2) = $args =~ /^\w+ (\d+)/;

	if ($arg1 =~ /^\d+$/ && exists $npcsID[$arg1]){
		 open NPC, ">>$pluginDir/warpnpcs.txt";
		 print NPC "$field{name} $npcs{$npcsID[$arg1]}{pos}{x} $npcs{$npcsID[$arg1]}{pos}{y}\n";
		 close NPC;
		 debug "Warpnpc added: $field{name} $npcs{$npcsID[$arg1]}{pos}{x} $npcs{$npcsID[$arg1]}{pos}{y}\n",'recordWarpNpc',2;
	} elsif ($arg1 eq "resp" && $arg2 ne "") {
		$info{seq} .= " r$arg2";
		debug "Added conversation seq: r$arg2, compl:$info{seq}\n",'recordWarpNpc',2;
	}

	Commands::cmdTalk($switch,$args); #call real Handler
}

sub saveDest {
	my $args = shift;
	open DEST, ">>$pluginDir/dest.txt";
	print DEST "$args->{map} $args->{x} $args->{y} 0$info{seq}\n";
	close DEST;
	debug "Warpnpc Dest: $args->{map} $args->{x} $args->{y} 0$info{seq}\n",'recordWarpNpc',2;
	message "Warpnpc Recorded.\n",'recordWarpNpc';
	%info = undef;
	combine();
	if ($config{recordWarpNpc_integrate}) {
		integrate();
		message "Warpnpcs added to portals.txt.\n",'recordWarpNpc';
		if ($config{recordWarpNpc_recompile}) {
			message "Recompiling Portals.\n",'recordWarpNpc';
			Settings::parseReload("portals");
			Misc::compilePortals() if Misc::compilePortals_check();
		}
	}
}

sub combine {
	my @dest;
	my $source;
	my $src_tmp;
	my $desc_tmp;

	removeDupes("$pluginDir/dest.txt");
	removeDupes("$pluginDir/warpnpcs.txt");

	open (IN, "<$pluginDir/dest.txt");

	@dest = <IN>;
	chomp (@dest);

	close (IN);
	open (IN, "<$pluginDir/warpnpcs.txt");
	open (OUT, ">$pluginDir/warpportals.txt");

	while (<IN>){
		chomp ($_);
		$source	= $src_tmp = $_;
		$src_tmp =~ /(^\w+)\s/;
		$src_tmp = $1;
		foreach	(@dest){
			$desc_tmp = $_;
			$desc_tmp =~ /(^\w+)\s/;
			print OUT "$source $_\n" unless ($1 eq $src_tmp);
		}
	}
	close (IN);
	close (OUT);
}

sub removeDupes {
	my $file = shift;
	my @data;
	my @output;
	my $temp;
	my $dupe;

	open IN, "<$file";
	@data = <IN>;
	close IN;

	while ($temp = shift @data){
		$dupe = 0;
		foreach (@data){
			if ($temp eq $_){
				$dupe = 1;
				last;
			}
		}
		push (@output,$temp) unless $dupe;
	}

	@output = sort (@output);

	open OUT, ">$file";
	print OUT @output;
	close OUT;
}

sub integrate {
	my $start;
	my $portal;
	my @portals;
	my @portals_temp;

	open PORTALS, "<$Settings::tables_folder/portals.txt";
	@portals = <PORTALS>;
	close PORTALS;
	while($portal = shift @portals) {
		next if $portal eq "\n";
		if ($portal eq "#####[WarpNPCs]#####\n"){
			$start = 1;
		}
		if ($portal eq "#####[/WarpNPCs]#####\n"){
			push (@portals_temp,@portals);
			last;
		}
		push (@portals_temp,$portal) unless $start;
	}
	open PORTALS, ">$Settings::tables_folder/portals.txt";
	open WARP, "<$pluginDir/warpportals.txt";
	print PORTALS @portals_temp;
	print PORTALS "\n#####[WarpNPCs]#####\n";
	print PORTALS <WARP>;
	print PORTALS "#####[/WarpNPCs]#####\n";
	close PORTALS;
	close WARP;
}

1;