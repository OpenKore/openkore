package eventMacro;

use lib $Plugins::current_plugin_folder;

use strict;
use Getopt::Long qw( GetOptionsFromArray );
use Time::HiRes qw( &time );
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
use eventMacro::Runner;


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
	$config{eventMacro_orphans} = 'terminate' unless defined $config{eventMacro_orphans};
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
			"eventMacro stop: stops current macro\n".
			"eventMacro status [macro|automacro]: shows current status of automacro, macro or both\n".
			"eventMacro unpause: unpauses running macro\n".
			"eventMacro pause: pauses running macro\n".
			"eventMacro automacro [force_stop|force_start|resume]: Sets the state of automacros checking\n".
			"eventMacro variables_value: show list of variables and their values\n".
			"eventMacro reset [automacro]: resets run-once status for all or given automacro(s)\n";
		return
	}
	my ( $arg, @params ) = parseArgs( $_[1] );
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
		if (defined $params[0] && $params[0] ne 'macro' && $params[0] ne 'automacro') {
			message "[eventMacro] '".$params[0]."' is not a valid option\n";
			return;
		}
		if (!defined $params[0] || $params[0] eq 'macro') {
			my $macro = $eventMacro->{Macro_Runner};
			if ( $macro ) {
				message( sprintf( "macro %s\n", $macro->name ), "list" );
				message( sprintf( "status: %s\n", $macro->registered ? "running" : "waiting" ) );
				message( sprintf( "paused: %s\n", $macro->is_paused ? "yes" : "no" ) );
				for ( my $m = $macro ; $m ; $m = $m->{subcall} ) {
					my @flags = ();
					my $t     = $m->timeout->{time} + $m->timeout->{timeout};
					push @flags, sprintf( 'delay=%.1fs (%s)', $t - time, scalar localtime( $t ) ) if $t > time;
					push @flags, 'ai_overridden' if $m->overrideAI;
					push @flags, 'finished'      if $m->finished;
					message( sprintf( "%s (line %d) : %s\n", $m->name, $m->line_number, $m->line_script($m->line_number) ) );
					message( sprintf( "  %s\n", "@flags" ) ) if @flags;
				}
			} else {
				message "There's no macro currently running.\n";
			}
		}
		if (!defined $params[0] || $params[0] eq 'automacro') {
			my $status = $eventMacro->get_automacro_checking_status();
			if ($status == CHECKING_AUTOMACROS) {
				message "Automacros are being checked normally.\n";
			} elsif ($status == PAUSED_BY_EXCLUSIVE_MACRO) {
				message "Automacros are not being checked because there's an uninterruptible macro running ('".$eventMacro->{Macro_Runner}->last_subcall_name."').\n";
			} elsif ($status == PAUSE_FORCED_BY_USER) {
				message "Automacros checking is stopped because the user forced it.\n";
			} else {
				message "Automacros checking is active because the user forced it.\n";
			}
		}
	### parameter: pause
	} elsif ($arg eq 'pause') {
		my $macro = $eventMacro->{Macro_Runner};
		if ( $macro ) {
			if ($macro->is_paused()) {
				message "Macro '".$eventMacro->{Macro_Runner}->last_subcall_name."' is already paused.\n";
			} else {
				message "Pausing macro '".$eventMacro->{Macro_Runner}->last_subcall_name."'.\n";
				$eventMacro->{Macro_Runner}->pause();
			}
		} else {
			message "There's no macro currently running.\n";
		}
	### parameter: unpause
	} elsif ($arg eq 'unpause') {
		my $macro = $eventMacro->{Macro_Runner};
		if ( $macro ) {
			if ($macro->is_paused()) {
				message "Unpausing macro '".$eventMacro->{Macro_Runner}->last_subcall_name."'.\n";
				$eventMacro->{Macro_Runner}->unpause();
			} else {
				message "Macro '".$eventMacro->{Macro_Runner}->last_subcall_name."' is not paused.\n";
			}
		} else {
			message "There's no macro currently running.\n";
		}
	### parameter: stop
	} elsif ($arg eq 'stop') {
		my $macro = $eventMacro->{Macro_Runner};
		if ( $macro ) {
			message "Stopping macro '".$eventMacro->{Macro_Runner}->last_subcall_name."'.\n";
			$eventMacro->clear_queue();
		} else {
			message "There's no macro currently running.\n";
		}
	#TODO: only enable macros which haven't 'disable 1' in eventMacros.txt
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
	### parameter: automacro
	} elsif ($arg eq 'automacro') {
		if (!defined $params[0] || (defined $params[0] && $params[0] ne 'force_stop' && $params[0] ne 'force_start' && $params[0] ne 'resume')) {
			message "usage: eventMacro automacro [force_stop|force_start|resume]\n", "list";
			message 
				"eventMacro automacro force_stop: forces the stop of automacros checking\n".
				"eventMacro automacro force_start: forces the start of automacros checking\n".
				"eventMacro automacro resume: return automacros checking to the normal state\n";
			return;
		}
		my $status = $eventMacro->get_automacro_checking_status();
		debug "[eventMacro] Command 'eventMacro automacro' used with parameter '".$params[0]."'.\n", "eventMacro", 2;
		debug "[eventMacro] Previous automacro status '".$status."'.\n", "eventMacro", 2;
		if ($params[0] eq 'force_stop') {
			if ($status == CHECKING_AUTOMACROS) {
				message "[eventMacro] Automacros checking forcely stopped.\n";
				$eventMacro->set_automacro_checking_status(PAUSE_FORCED_BY_USER);
			} elsif ($status == PAUSED_BY_EXCLUSIVE_MACRO) {
				message "[eventMacro] Automacros were not being checked because there's an uninterruptible macro running ('".$eventMacro->{Macro_Runner}->last_subcall_name."').".
				        "Now they will be forcely stopped even after macro ends (caution).\n";
				$eventMacro->set_automacro_checking_status(PAUSE_FORCED_BY_USER);
			} elsif ($status == PAUSE_FORCED_BY_USER) {
				message "[eventMacro] Automacros checking is already forcely stopped.\n";
			} else {
				message "[eventMacro] Automacros checking is forcely active, now it will be forcely stopped.\n";
				$eventMacro->set_automacro_checking_status(PAUSE_FORCED_BY_USER);
			}
		} elsif ($params[0] eq 'force_start') {
			if ($status == CHECKING_AUTOMACROS) {
				message "[eventMacro] Automacros are already being checked, now it will be forcely kept this way.\n";
				$eventMacro->set_automacro_checking_status(CHECKING_FORCED_BY_USER);
			} elsif ($status == PAUSED_BY_EXCLUSIVE_MACRO) {
				message "[eventMacro] Automacros were not being checked because there's an uninterruptible macro running ('".$eventMacro->{Macro_Runner}->last_subcall_name."').".
				        "Now automacros checking will be forcely activated (caution).\n";
				$eventMacro->set_automacro_checking_status(CHECKING_FORCED_BY_USER);
			} elsif ($status == PAUSE_FORCED_BY_USER) {
				message "[eventMacro] Automacros checking is forcely stopped, now it will be forcely activated.\n";
				$eventMacro->set_automacro_checking_status(CHECKING_FORCED_BY_USER);
			} else {
				message "[eventMacro] Automacros checking is already forcely active.\n";
			}
		} else {
			if ($status == CHECKING_AUTOMACROS || $status == PAUSED_BY_EXCLUSIVE_MACRO) {
				message "[eventMacro] Automacros checking is not forced by the user to be able to resume.\n";
			} else {
				if (!defined $eventMacro->{Macro_Runner}) {
					message "[eventMacro] Since there's no macro in execution automacros will resume to being normally checked.\n";
					$eventMacro->set_automacro_checking_status(CHECKING_AUTOMACROS);
				} elsif ($eventMacro->{Macro_Runner}->last_subcall_interruptible == 1) {
					message "[eventMacro] Since there's a macro in execution, and it is interruptible, automacros will resume to being normally checked.\n";
					$eventMacro->set_automacro_checking_status(CHECKING_AUTOMACROS);
				} elsif ($eventMacro->{Macro_Runner}->last_subcall_interruptible == 0) {
					message "[eventMacro] Since there's a macro in execution ('".$eventMacro->{Macro_Runner}->last_subcall_name."') , and it is not interruptible, automacros won't resume to being checked until it ends.\n";
					$eventMacro->set_automacro_checking_status(PAUSED_BY_EXCLUSIVE_MACRO);
				}
			}
		}
	### parameter: variables_value
	} elsif ($arg eq 'variables_value') {
		message "[eventMacro] Varstack List\n", "menu";
		my $counter = 1;
		foreach my $variable_name (keys %{$eventMacro->{Variable_List_Hash}}) {
			message $counter."- '".$variable_name."' = '".$eventMacro->{Variable_List_Hash}->{$variable_name}."'\n", "menu"
		} continue {
			$counter++;
		}
	### if nothing triggered until here it's probably a macro name
	} elsif ( !$eventMacro->{Macro_List}->getByName( $arg ) ) {
		error "[eventMacro] Macro $arg not found\n";
	} elsif ( $eventMacro->{Macro_Runner} ) {
		warning "[eventMacro] A macro is already running. Wait until the macro has finished or call 'eventMacro stop'\n";
		return;
	} else {
		my $opt = {};
		GetOptionsFromArray( \@params, $opt, 'repeat|r=i', 'override_ai', 'exclusive', 'macro_delay=f', 'orphan=s' );
		
		# TODO: Determine if this is reasonably efficient for macro sets which define a lot of variables. (A regex is slow.)
		foreach my $variable_name ( keys %{ $eventMacro->{Variable_List_Hash} } ) {
			next if $variable_name !~ /^\.param\d+$/o;
			$eventMacro->set_var( $variable_name, undef );
		}
		$eventMacro->set_var( ".param$_", $params[ $_ - 1 ] ) foreach 1 .. @params;
		
		$eventMacro->{Macro_Runner} = new eventMacro::Runner(
			$arg,
			defined $opt->{repeat} ? $opt->{repeat} : undef,
			undef,
			undef,
			defined $opt->{exclusive} ? $opt->{exclusive} ? 0 : 1 : undef,
			defined $opt->{override_ai} ? $opt->{override_ai} : undef,
			defined $opt->{orphan} ? $opt->{orphan} : undef,
			undef,
			defined $opt->{macro_delay} ? $opt->{macro_delay} : undef,
			0
		);

		if ( defined $eventMacro->{Macro_Runner} ) {
			$eventMacro->{mainLoop_Hook_Handle} = Plugins::addHook( 'mainLoop_pre', sub { $eventMacro->iterate_macro }, undef );
		} else {
			error "[eventMacro] unable to create macro queue.\n";
		}
	}
}

1;