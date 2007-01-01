#########################################################################
#  OpenKore - Bus system
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#
#  $Revision: 1810 $
#  $Id: Client.pm 1810 2005-03-03 14:48:21Z hongli $
#
#########################################################################
package Bus::Server::Starter;

use strict;
use Time::HiRes qw(time);
use File::Spec::Functions qw(splitpath catfile);
use Cwd qw(realpath);

use Utils::PerlLauncher;
use Utils::Daemon;

use constant NOT_STARTED => 1;
use constant STARTING => 2;
use constant STARTED  => 3;
use constant FAILED   => 4;
our $busServerScript;

BEGIN {
	my (undef, $dirs) = splitpath(realpath(__FILE__));
	$busServerScript = realpath(catfile($dirs, "..", "bus-server.pl"));
}

sub new {
	my ($class) = @_;
	my %self = (
		state => NOT_STARTED,
		daemon => new Utils::Daemon('OpenKore-Bus')
	);
	return bless \%self, $class;
}

sub iterate {
	my ($self) = @_;
	if ($self->{state} == NOT_STARTED) {
		my $info = $self->{daemon}->getInfo();
		if ($info) {
			$self->{state} = STARTED;
			$self->{host} = $info->{host};
			$self->{port} = $info->{port};
		} else {
			my $launcher = new PerlLauncher(undef, $busServerScript);
			if ($launcher->launch(1)) {
				$self->{state} = STARTING;
				$self->{start_time} = time;
			} else {
				$self->{state} = FAILED;
				$self->{error} = $launcher->getError();
			}
		}

	} elsif ($self->{state} == STARTING) {
		my $info = $self->{daemon}->getInfo();
		if ($info) {
			$self->{state} = STARTED;
			$self->{host} = $info->{host};
			$self->{port} = $info->{port};
		} elsif (time - $self->{start_time} > 10) {
			# 10 seconds passed and bus server is still not started.
			$self->{state} = FAILED;
			$self->{error} = "Timeout when starting server.";
		}
	}
	return $self->{state};
}

sub getHost {
	return $_[0]->{host};
}

sub getPort {
	return $_[0]->{port};
}

sub getError {
	return $_[0]->{error};
}

1;