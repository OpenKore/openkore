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
use eventMacro::Runner qw( %macro );


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
			"eventMacro stop: stops current macro\n".
			"eventMacro status [macro|automacro]: shows current status of automacro, macro or both\n".
			"eventMacro resume [macro|automacro]: resumes automacro, macro or both\n".
			"eventMacro pause [macro|automacro]: pauses automacro, macro or both\n".
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
					message( sprintf( "%s (line %d) : %s\n", $m->name, $m->line, $macro{ $m->name }->[ $m->line - 1 ] ) );
					message( sprintf( "  %s\n", "@flags" ) ) if @flags;
				}
			} else {
				message "There's no macro currently running.\n";
			}
		}
		if (!defined $params[0] || $params[0] eq 'automacro') {
			my $status = $eventMacro->get_automacro_checking_status();
			if ($status == 0) {
				message "Automacros are being checked.\n";
			} elsif ($status == 1) {
				message "Automacros are not being checked because there's an uninterruptible macro running ('".$eventMacro->{Macro_Runner}->get_name()."').\n";
			} else {
				message "Automacros are not being checked because the user stopped it.\n";
			}
		}
	### parameter: pause
	} elsif ($arg eq 'pause') {
		if (defined $params[0] && $params[0] ne 'macro' && $params[0] ne 'automacro') {
			message "[eventMacro] '".$params[0]."' is not a valid option\n";
			return;
		}
		if (!defined $params[0] || $params[0] eq 'macro') {
			my $macro = $eventMacro->{Macro_Runner};
			if ( $macro ) {
				if ($macro->is_paused()) {
					message "Macro '".$eventMacro->{Macro_Runner}->get_name()."' is already paused.\n";
				} else {
					message "Pausing macro '".$eventMacro->{Macro_Runner}->get_name()."'.\n";
					$eventMacro->{Macro_Runner}->pause();
				}
			} else {
				message "There's no macro currently running.\n";
			}
		}
		if (!defined $params[0] || $params[0] eq 'automacro') {
			my $status = $eventMacro->get_automacro_checking_status();
			if ($status == 0) {
				message "Automacros won't be checked anymore.\n";
				$eventMacro->set_automacro_checking_status(eventMacro::Core::PAUSED_BY_USER);
			} elsif ($status == 1) {
				message "Automacros were not being checked because there's an uninterruptible macro running ('".$eventMacro->{Macro_Runner}->get_name()."'). Now they won't return to being checked when this macro ends (caution)\n";
				$eventMacro->set_automacro_checking_status(eventMacro::Core::PAUSED_BY_USER);
			} else {
				message "Automacros checking is already paused.\n";
			}
		}
	### parameter: resume
	} elsif ($arg eq 'resume') {
		if (defined $params[0] && $params[0] ne 'macro' && $params[0] ne 'automacro') {
			message "[eventMacro] '".$params[0]."' is not a valid option\n";
			return;
		}
		if (!defined $params[0] || $params[0] eq 'macro') {
			my $macro = $eventMacro->{Macro_Runner};
			if ( $macro ) {
				if ($macro->is_paused()) {
					message "Unpausing macro '".$eventMacro->{Macro_Runner}->get_name()."'.\n";
					$eventMacro->{Macro_Runner}->unpause();
				} else {
					message "Macro '".$eventMacro->{Macro_Runner}->get_name()."' is not paused.\n";
				}
			} else {
				message "There's no macro currently running.\n";
			}
		}
		if (!defined $params[0] || $params[0] eq 'automacro') {
			my $status = $eventMacro->get_automacro_checking_status();
			if ($status == 0) {
				message "Automacros are already being checked.\n";
			} elsif ($status == 1) {
				message "Automacros were not being checked because there's an uninterruptible macro running ('".$eventMacro->{Macro_Runner}->get_name()."'). Now they will start being checked again (caution)\n";
				$eventMacro->set_automacro_checking_status(eventMacro::Core::CHECKING_AUTOMACROS);
			} else {
				message "Automacros will now start being checked again.\n";
				$eventMacro->set_automacro_checking_status(eventMacro::Core::CHECKING_AUTOMACROS);
			}
		}
	### parameter: stop
	} elsif ($arg eq 'stop') {
		my $macro = $eventMacro->{Macro_Runner};
		if ( $macro ) {
			message "Stopping macro '".$eventMacro->{Macro_Runner}->get_name()."'.\n";
			$eventMacro->clear_queue();
		} else {
			message "There's no macro currently running.\n";
		}
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

		$eventMacro->{Macro_Runner} = eventMacro::Runner->new( $arg, $opt->{repeat} );

		if ( defined $eventMacro->{Macro_Runner} ) {
			if ( defined $opt->{override_ai} ) { $eventMacro->{Macro_Runner}->overrideAI( 1 ); }
			if ( defined $opt->{exclusive} )   {
				$eventMacro->{Macro_Runner}->interruptible( 0 );
				message "[eventMacro] Calling uninterruptible macro '".$arg."'. Automacro checking will be paused until it ends.\n";
				$eventMacro->set_automacro_checking_status(eventMacro::Core::PAUSED_BY_EXCLUSIVE_MACRO);
			}
			if ( defined $opt->{macro_delay} ) { $eventMacro->{Macro_Runner}->setMacro_delay( $opt->{macro_delay} ); }
			if ( defined $opt->{orphan} )      { $eventMacro->{Macro_Runner}->orphan( $opt->{orphan} ); }
			
			$eventMacro->{mainLoop_Hook_Handle} = Plugins::addHook( 'mainLoop_pre', sub { $eventMacro->iterate_macro }, undef );
		} else {
			error "[eventMacro] unable to create macro queue.\n";
		}
	}
}

1;