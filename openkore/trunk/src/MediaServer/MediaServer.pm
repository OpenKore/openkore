package mediaServer;

use strict;
use Base::Server;
use base qw(Base::Server);
use IPC::Messages qw(encode decode);
use SDL;
use SDL::Mixer;
use SDL::Music;
use SDL::Sound;
# to install sdl_perl bindings in ActiveState Perl:
# ppm install http://www.bribes.org/perl/ppm/SDL_Perl.ppd

use constant ALERT => 0;
use constant ALERT_MAX => 3;
use constant SFX => 4;
use constant SFX_MAX => 7;

sub new {
	my ($class, $port, $host) = @_;
	my $self = $class->SUPER::new($port, $host);
	$self->{mixer} = new SDL::Mixer;

	return $self;
}

sub onClientNew {
	my ($self, $client) = @_;
	$client->{data} = '';
}

sub onClientData {
	my ($self, $client, $msg) = @_;
	my ($ID, %args, $rest);

	$client->{data} .= $msg;
	$ID = decode($client->{data}, \%args, \$rest);
	if (defined($ID)) {
		$self->process($client, $ID, \%args);
	}
}

# internal
sub process {
	my ($self, $client, $ID, $args) = @_;

	if ($ID eq 'mediaServer playfile') {
		my $file = $args->{file};
		my $domain = $args->{domain};
		my $loop = $args->{loop};
		my $volume = $args->{volume};

		if ($domain eq 'BGM') {
			$self->{mixer}->fade_out_music(1250);
			#while ($self->{mixer}->fading_music()) { }
			$self->{"BGM"} = new SDL::Music($file);
			$self->{mixer}->fade_in_music($self->{"BGM"}, ($loop - 1), 1250);

		} elsif ($domain eq 'ALERT') {
			my $channel = ALERT;
			while ($self->{mixer}->playing($channel)) {
				$channel++;
				if ($channel > ALERT_MAX) {
					print "Not enough channels!\n";
					return;
				}
			}
			$self->{"ALERT $channel"} = new SDL::Sound($file);
			$self->{mixer}->play_channel($channel,$self->{"ALERT $channel"}, ($loop - 1));
			print "Playing $domain $file\n";

		} elsif ($domain eq 'SFX') {
			my $channel = SFX;
			while ($self->{mixer}->playing($channel)) {
				$channel++;
				if ($channel > SFX_MAX) {
					print "Not enough channels!\n";
					return;
				}
			}
			$self->{"SFX $channel"} = new SDL::Sound($file);
			$self->{mixer}->play_channel($channel,$self->{"SFX $channel"}, ($loop - 1));
			print "Playing $domain $file\n";
		}
	
	} elsif ($ID eq 'mediaServer speak') {
		my $message = $args->{message};
		my $domain = $args->{domain};
		my $loop = $args->{loop};
		my $volume = $args->{volume};
		# TODO: speak now, or forever hold your peace

	} elsif ($ID eq 'mediaServer command') {
		my $command = $args->{command};
		my $which = $args->{which};
		if ($command eq 'stop') {
			if ($which eq 'BGM') {
				$self->{mixer}->fade_out_music(2000);

			} elsif ($which eq 'SFX') {
				for (my $channel = SFX; $channel < SFX_MAX; $channel++) {
					$self->{mixer}->halt_channel($channel);
				}

			} elsif ($which eq 'ALERT') {
				for (my $channel = ALERT; $channel < ALERT_MAX; $channel++) {
					$self->{mixer}->halt_channel($channel);
				}

			} elsif ($which eq 'ALL') {
				$self->{mixer}->fade_out_music(2000);
				for (my $channel = SFX; $channel < SFX_MAX; $channel++) {
					$self->{mixer}->halt_channel($channel);
				}
				for (my $channel = ALERT; $channel < ALERT_MAX; $channel++) {
					$self->{mixer}->halt_channel($channel);
				}
			}			
		}

	} else {
		$client->close();
	}
}

sub iterate {
	my ($self) = @_;

	$self->SUPER::iterate();
	foreach my $key (%{$self}) {
		# TODO: remove unused hashes
	}
}

1;
