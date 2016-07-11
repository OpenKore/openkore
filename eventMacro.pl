package eventMacro;

use lib $Plugins::current_plugin_folder;

use strict;
use Plugins;
use Settings;
use Globals;
use Utils;
use Misc;
use Log qw(message error warning debug);
use Translation qw( T TF );

use eventMacro::Core;
use eventMacro::Data;
use eventMacro::Lists;
use eventMacro::Automacro;
use eventMacro::FileParser;
use eventMacro::Macro;


Plugins::register('eventMacro', 'allows usage of eventMacros', \&Unload);

my $hooks = Plugins::addHooks(
	['configModify', \&onconfigModify, undef],
	['start3',       \&onstart3, undef]
);

my $chooks = Commands::register(
	['eventMacro', "eventMacro plugin", \&commandHandler]
);

my $file_handle;
my $file;

sub Unload {
	message "[eventMacro] Plugin unloading\n", "system";
	Settings::removeFile($file_handle) if defined $file_handle;
	undef $file_handle;
	undef $file;
	if (defined $eventMacro) {
		$eventMacro->unload();
		undef $eventMacro;
	}
	Plugins::delHooks($hooks);
	Commands::unregister($chooks);
}

sub onstart3 {
	debug "[eventMacro] Loading start\n", "eventMacro", 2;
	&checkConfig;
	$file_handle = Settings::addControlFile($file,loader => [\&parseAndHook], mustExist => 0);
	Settings::loadByHandle($file_handle);
}

sub checkConfig {
	$timeout{eventMacro_delay}{timeout} = 1 unless defined $timeout{eventMacro_delay};
	$file = (defined $config{eventMacro_file}) ? $config{eventMacro_file} : "eventMacros.txt";
	return 1;
}

sub onconfigModify {
	my (undef, $args) = @_;
	if ($args->{key} eq 'eventMacro_file') {
		Settings::removeFile($file_handle);
		$file_handle = Settings::addControlFile($args->{val}, loader => [ \&parseAndHook]);
		Settings::loadByHandle($file_handle);
	}
}

sub parseAndHook {
	my $file = shift;
	if (defined $eventMacro) {
		$eventMacro->unload();
		undef $eventMacro;
	}
	$eventMacro = new eventMacro::Core($file);
	if (defined $eventMacro) {
		debug "[eventMacro] Loading success\n", "eventMacro", 2;
	} else {
		debug "[eventMacro] Loading error\n", "eventMacro", 2;
	}
}

sub commandHandler {
	### no parameter given
	if (!defined $_[1]) {
		message "usage: eventMacro [MACRO|list|status|stop|pause|resume|reset] [automacro]\n", "list";
		message 
			"eventMacro MACRO: run macro MACRO\n".
			"eventMacro list: list available macros\n".
			"eventMacro status: shows current status\n".
			"eventMacro stop: stop current macro\n".
			"eventMacro pause: interrupt current macro\n".
			"eventMacro resume: resume interrupted macro\n".
			"eventMacro variables_value: show list of variables and their values\n".
			"eventMacro reset [automacro]: resets run-once status for all or given automacro(s)\n";
		return
	}
	my ($arg, @params) = split(/\s+/, $_[1]);
	### parameter: list
	if ($arg eq 'list') {
		message( "The following macros are available:\n" );

		message( center( T( ' Macros ' ), 25, '-' ) . "\n", 'list' );
		message( $_->get_name . "\n" ) foreach sort { $a->get_name cmp $b->get_name } @{ $eventMacro->{Macro_List}->getItems };

		message( center( T( ' Auto Macros ' ), 25, '-' ) . "\n", 'list' );
		message( $_->get_name . "\n" ) foreach sort { $a->get_name cmp $b->get_name } @{ $eventMacro->{Automacro_List}->getItems };

		message( center( T( ' Perl Subs ' ), 25, '-' ) . "\n", 'list' );
		message( "$_\n" ) foreach sort @perl_name;

		message( center( '', 25, '-' ) . "\n", 'list' );
	### parameter: status
	} elsif ($arg eq 'status') {
			message(sprintf("paused: %s\n", $eventMacro->is_paused()?"yes":"no"));
		if (defined $eventMacro->{Macro_Runner}) {
			message(sprintf("macro %s\n", $eventMacro->{Macro_Runner}->name), "list");
			message(sprintf("status: %s\n", $eventMacro->{Macro_Runner}->registered?"running":"waiting"));
			my %tmp = $eventMacro->{Macro_Runner}->timeout;
			message(sprintf("delay: %ds\n", $tmp{timeout}));
			message(sprintf("line: %d\n", $eventMacro->{Macro_Runner}->line));
			message(sprintf("override AI: %s\n", $eventMacro->{Macro_Runner}->overrideAI?"yes":"no"));
			message(sprintf("finished: %s\n", $eventMacro->{Macro_Runner}->finished?"yes":"no"));
		} else {
			message "There's no macro currently running.\n"
		}
	### parameter: stop
	} elsif ($arg eq 'stop') {
		$eventMacro->clear_queue();
	### parameter: pause
	} elsif ($arg eq 'pause') {
		$eventMacro->pause()
	### parameter: resume
	} elsif ($arg eq 'resume') {
		$eventMacro->unpause()
	### parameter: reset
	} elsif ($arg eq 'reset') {
		if (!defined $params[0]) {
			foreach my $automacro (@{$eventMacro->{Automacro_List}->getItems()}) {
				$automacro->enable();
			}
			message "[eventMacro] Automacros run-once cleared.\n";
			return;
		}
		for my $automacro_name (@params) {
			my $automacro = $eventMacro->{Automacro_List}->getByName($automacro_name);
			if (!$automacro) {
				error "[eventMacro] Automacro '".$automacro_name."' not found.\n"
			} else {
				$automacro->enable();
			}
		}
	} elsif ($arg eq 'variables_value') {
		message "[eventMacro] Varstack List\n", "menu";
		my $counter = 1;
		foreach my $variable_name (keys %{$eventMacro->{Variable_List_Hash}}) {
			message $counter."- '".$variable_name."' = '".$eventMacro->{Variable_List_Hash}->{$variable_name}."'\n", "menu"
		} continue {
			$counter++;
		}
	### parameter: probably a macro
	} else {
		if (defined $eventMacro->{Macro_Runner}) {
			warning "[eventMacro] A macro is already running. Wait until the macro has finished or call 'eventMacro stop'\n";
			return;
		}
		my ($repeat, $oAI, $exclusive, $mdelay, $orphan) = (1, 0, 0, undef, undef);
		my $cparms;
		for (my $idx = 0; $idx <= @params; $idx++) {
			if ($params[$idx] eq '-repeat') {$repeat += $params[++$idx]}
			if ($params[$idx] eq '-overrideAI') {$oAI = 1}
			if ($params[$idx] eq '-exclusive') {$exclusive = 1}
			if ($params[$idx] eq '-macro_delay') {$mdelay = $params[++$idx]}
			if ($params[$idx] eq '-orphan') {$orphan = $params[++$idx]}
			if ($params[$idx] =~ /^--/) {$cparms = substr(join(' ', map { "$_" } @params), 2); last}
		}
		
		foreach my $variable_name (keys %{$eventMacro->{Variable_List_Hash}}) {
			if ($variable_name =~ /^\.param\d+$/) {
				$eventMacro->set_var($variable_name, undef);
			}
		}
		
		if ($cparms) {
			#parse macro parameters
			my @new_params = $cparms =~ /"[^"]+"|\S+/g;
			foreach my $p (1..@new_params) {
				$eventMacro->set_var((".param".$p), ($new_params[$p-1]));
				if ($eventMacro->get_var(".param".$p) =~ /^".*"$/) {
					$eventMacro->set_var((".param".$p), (substr($eventMacro->get_var(".param".$p), 1, -1)));
				}
			}
		}
		
		unless ($eventMacro->{Macro_List}->getByName($arg)) {
			error "[eventMacro] Macro $arg not found\n";
			return;
		}
		
		$eventMacro->{Macro_Runner} =  new eventMacro::Runner($arg, $repeat);
		
		if (defined $eventMacro->{Macro_Runner}) {
			if ($oAI) {$eventMacro->{Macro_Runner}->overrideAI(1)}
			if ($exclusive) {$eventMacro->{Macro_Runner}->interruptible(0)}
			if (defined $mdelay) {$eventMacro->{Macro_Runner}->setMacro_delay($mdelay)}
			if (defined $orphan) {$eventMacro->{Macro_Runner}->orphan($orphan)}
			$eventMacro->unpause();
			my $iterate_macro_sub = sub {$eventMacro->iterate_macro(); };
			$eventMacro->{mainLoop_Hook_Handle} = Plugins::addHook( 'mainLoop_pre', $iterate_macro_sub, undef );
		} else {
			error "[eventMacro] unable to create macro queue.\n"
		}
	}
}

1;