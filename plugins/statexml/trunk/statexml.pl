package statexml;
use strict;

use Bus::Client ();
use Globals qw/$bus %config $net %field $char %jobs_lut %sex_lut $taskManager $npcsList $playersList $monstersList $slavesList/;
use Utils qw/calcPosition timeOut/;

use Cwd qw/cwd/;
use File::Copy::Recursive qw/dircopy fmove/;
use IO::File ();
use XML::Writer ();

my $timeout;

dircopy cwd . '/' . $Plugins::current_plugin_folder . '/styles', "$Settings::logs_folder/.statexml-styles";
my $dir = $Plugins::current_plugin_folder;

my $hook = Plugins::addHook('mainLoop_post', sub {
	return unless timeOut($timeout, 0.5); $timeout = time;
	
	my $writer = new XML::Writer(
		OUTPUT => (my $output = new IO::File(">$Settings::logs_folder/.state_".$config{'username'}.".xml")),
		ENCODING => 'utf-8',
		DATA_MODE => 1,
		DATA_INDENT => 2,
	);
	$writer->xmlDecl;
	$writer->pi('xml-stylesheet', 'type="text/xsl" href=".statexml-styles/state.xsl"');
	$writer->startTag('state');
	
	my $tag; $tag = sub {
		$writer->startTag(shift);
		$writer->characters(shift) unless ref $_[0];
		$tag->(@$_) for @_;
		$writer->endTag;
	};
	
	map $tag->(@$_), (
		[connectionState => {
			Network::NOT_CONNECTED              => 'not connected',
			Network::CONNECTED_TO_MASTER_SERVER => 'connected to master server',
			Network::CONNECTED_TO_LOGIN_SERVER  => 'connected to login server',
			Network::CONNECTED_TO_CHAR_SERVER   => 'connected to char server',
			Network::IN_GAME                    => 'in game',
			Network::IN_GAME_BUT_UNINITIALIZED  => 'in game (uninitialized)',
		}->{$net->getState}],
		
		$char && $field{name} && $net->getState == Network::IN_GAME ? (
			[field =>
				[name =>$field{name}],
				[baseName => $field{baseName}],
				-f cwd . "/map/$field{baseName}.png" ? ['image' => cwd . "/map/$field{baseName}.png"] : (),
			],
			[char =>
				[name => $char->{name}],
				[job => $jobs_lut{$char->{jobID}}],
				[sex => $sex_lut{$char->{sex}}],
				[zeny => $char->{zeny}],
				[x => $char->{pos_to}{x}],
				[y => $char->{pos_to}{y}],
				[lv => $char->{lv}],
				[lv_job => $char->{lv_job}],
				[hp => $char->{hp}],
				[hp_max => $char->{hp_max}],
				[sp => $char->{sp}],
				[sp_max => $char->{sp_max}],
				[exp => $char->{exp}],
				[exp_max => $char->{exp_max}],
				[exp_job=> $char->{exp_job}],
				[exp_job_max => $char->{exp_job_max}],
				[weight => $char->{weight}],
				[weight_max => $char->{weight_max}],
				[statuses => $char->{statuses} && %{$char->{statuses}} ? map {
					[status => $_]
				} keys %{$char->{statuses}} : ()],
			],
		) : (),
		
		[actors => map {[
			actor =>
				[name => $_->name],
				[actorType => $_->{actorType}],
				[x => $_->{pos_to}{x}],
				[y => $_->{pos_to}{y}],
				[binID => $_->{binID}],
				[nameID => $_->{nameID}],
		]} @{$npcsList->getItems}, @{$monstersList->getItems}, @{$playersList->getItems}, @{$slavesList->getItems}],
		
		$bus && $bus->getState == Bus::Client::CONNECTED ? (
			['bus' =>
				[host => $bus->serverHost],
				[port => $bus->serverPort],
				[clientID => $bus->ID],
			],
		) : (),
		
		[application =>
			[name => $Settings::NAME],
			[version => $Settings::VERSION],
			[website => $Settings::WEBSITE],
		],
		
		[time => scalar localtime time],
	);
	
	$writer->endTag;
	$writer->end;
	$output->close;
	
	fmove "$Settings::logs_folder/.state_".$config{'username'}.".xml", "$Settings::logs_folder/state_".$config{'username'}.".xml";
});

Plugins::register('statexml', 'state.xml updater', sub {
	Plugins::delHook($hook);
});
