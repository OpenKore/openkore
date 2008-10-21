#########################################################################
#  OpenKore - Commandline
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#
#  $Revision: 6528 $
#  $Id: Commands.pm 6528 2008-09-11 06:38:55Z lastclick $
#
#########################################################################
##
# MODULE DESCRIPTION: Commandline input processing
#
# This module processes commandline input.

package Commands;

use strict;
use threads;
use threads::shared;
no warnings qw(redefine uninitialized);
use FindBin qw($RealBin);
use Time::HiRes qw(time);
use Scalar::Util qw(reftype refaddr blessed); 

use Modules 'register';
use Globals qw(%config $interface);
use Log qw(message debug error warning);
use Translation;
use I18N qw(stringToBytes);
use Utils qw(timeOut);

sub new {
	my $class = shift;
	my %args  = @_;
	my $dir = "$RealBin/src/Commands";
	my $self  = {};
	bless $self, $class;
	$self->{handlers}		= [];
	$self->{cmdQueue}		= 0;
	$self->{cmdQueueStartTime}	= 0;
	$self->{cmdQueueTime}		= 0;
	$self->{cmdQueueList}		= [];

	# Read Directory with Command's.
	return if ( !opendir( DIR, $dir ) );
	my @items;
	@items = readdir DIR;
	closedir DIR;

	# Add all avalable command interpretters
	foreach my $file (@items) {
		if ( -f "$dir/$file" && $file =~ /\.(pm)$/ ) {
			$file =~ s/\.(pm)$//;
			my $module = "Commands::$file";
			eval "use $module;";
			if ($@) {
				$interface->errorDialog(TF("Cannot load Command parser %s.\nError Message: \n%s", $module, $@ ) );
				next;
			}
			my $constructor = UNIVERSAL::can( $module, 'new' );
			if ( !$constructor ) {
				$interface->errorDialog(TF( "Class %s has no constructor.\n", $module ) );
				next;
			}
			# call "$module::new($self). So that module can use our functions
			$constructor->( $module, $self ); 
		}
	}

	return $self;
}

sub DESTROY {
	my ($self) = @_;
	$self->SUPER::DESTROY();
}

# Exported functions.

sub check_timed_out_cmd {
	my ($self) = @_;
	lock ($self) if (is_shared($self));

	if ($self->{cmdQueue} && timeOut($self->{cmdQueueStartTime}, $self->{cmdQueueTime})) {
		my $execCommand = '';
		if (@{$self->{cmdQueueList}}) {
			$execCommand = join (";;", @{$self->{cmdQueueList}});
		} else {
			$execCommand = $self->{cmdQueueList}[0];
		}	
		@{$self->{cmdQueueList}} = ();
		$self->{cmdQueue} = 0;
		$self->{cmdQueueTime} = 0;
		debug "Executing queued command: $execCommand\n", "cmd";
		$self->parse($execCommand);
	} 
}

##
# Commands::parse(input, force)
# input: a command.
# force: force interpretting command in paused state.
#
# Processes $input. See also <a href="http://openkore.sourceforge.net/docs.php">the user documentation</a>
# for a list of commands.
#
# Example:
# # Same effect as typing 's' in the console. Displays character status
# $interface->{cmd}->parse("s");
sub parse {
	my $self  = shift;
	my $input = shift;

	lock ($self) if (is_shared($self));

	# Resolve command aliases
	my ( $switch, $args ) = split( / +/, $input, 2 );
	if ( my $alias = $config{"alias_$switch"} ) {
		$input = $alias;
		$input .= " $args" if defined $args;
	}

	my @commands = split( ';;', $input );

	# Loop through all of the commands...
	foreach my $command (@commands) {
		my ( $switch, $args ) = split( / +/, $command, 2 );
		my $handler = $self->{handlers}[$switch] if ( $self->{handlers}[$switch] );

		if ( ( $switch eq 'pause' ) && ( !$self->{cmdQueue} ) ) {
			$self->{cmdQueue}     = 1;
			$self->{cmdQueueStartTime} = time;
			if ( $args > 0 ) {
				$self->{cmdQueueTime} = $args;
			} else {
				$self->{cmdQueueTime} = 1;
			}
			debug "Command queueing started\n", "cmd";
		} elsif ($self->{cmdQueue} > 0 ) {
		# } elsif ( ( $self->{cmdQueue} > 0 ) && ( $force != 1 ) ) {
			push( @{$self->{cmdQueueList}}, $command );
		} elsif ($handler) {
			my %params;
			if ( $handler->{self}) {
				# New style, to overide nesty global vars
				$handler->{callback}->call( $handler->{self}, $switch, $args );
			} else {
				# Old style
				$handler->{callback}->call( $switch, $args );
			}
			# undef the handler here, this is needed to make sure the other commands in the chain (if any) are run properly.
			undef $handler;
		} else {
			my %params = ( switch => $switch, input => $command );
			# Plugins::callHook( 'Command_post', \%params );
			if ( !$params{return} ) {
				error TF("Unknown command '%s'. Please read the documentation for a list of commands.\n", $switch);
			} else {
				return $params{return};
			}
		}
	}
	return 1;
}

##
# Commands::register([name, description, callback, selfpointer]...)
# Returns: an ID for use with Commands::unregister()
#
# Register new commands.
#
# Example:
# my $ID = Commands::register(
#     ["my_command", "My custom command's description", \&my_callback],
#     ["another_command", "Yet another command description", \&another_callback]
# );
# $command->unregister($ID);
sub register {
	my $self = shift;
	my @result;

	lock ($self) if (is_shared($self));

	foreach my $cmd (@_) {
		# Check if called used unknown params.
		next if (reftype($cmd) ne 'ARRAY');

		my $name = $cmd->[0];
		my %item = (
					desc     => $cmd->[1],
					callback => Utils::CodeRef->new( $cmd->[2] ),
					self     => $cmd->[3]
		);
		my $item_obj = \%item;
		$item_obj = shared_clone($item_obj) if (is_shared($self));
		
		$self->{handlers}[$name] = $item_obj;
		push @result, $name;
	}
	return \@result;
}

##
# Commands::unregister(ID)
# ID: an ID returned by Commands::register()
#
# Unregisters a registered command.
# Example:
# my $ID = Commands::register(
#     ["my_command", "My custom command's description", \&my_callback],
#     ["another_command", "Yet another command description", \&another_callback]
# );
# $command->unregister($ID);
sub unregister {
	my ( $self, $ID ) = @_;

	lock ($self) if (is_shared($self));

	foreach my $name ( @{$ID} ) {
		delete $self->{handlers}[$name];
	}
}

1;
