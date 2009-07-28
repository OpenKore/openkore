# A basic implementation of an RO account server.
# One should implement the abstract methods to implement a fully functional RO account server.
package Base::Ragnarok::AccountServer;

use strict;
use Exception::Class qw(
	Base::Ragnarok::AccountServer::AccountNotFound
	Base::Ragnarok::AccountServer::PasswordIncorrect
	Base::Ragnarok::AccountServer::AccountBanned
);

use Modules 'register';
use Base::RagnarokServer;
use base qw(Base::RagnarokServer);
use Socket qw(inet_aton);
use Utils::Exceptions;

use enum qw(LOGIN_SUCCESS ACCOUNT_NOT_FOUND PASSWORD_INCORRECT ACCOUNT_BANNED);


sub new {
	my $class = shift;
	my %options = @_;
	my $self = $class->SUPER::new(
		$options{host},
		$options{port},
		$options{serverType},
		$options{rpackets}
	);
	$self->{sessionStore} = $options{sessionStore};
	$self->{charServers} = [$options{charServer}];
	return $self;
}

##
# abstract int $Base_Ragnarok_AccountServer->login(Hash* session, String username, String password)
#
# This method is called whenever an RO client tries to login. It authenticates the
# specified user with the specified password, and fills the session hash with necessary
# session information upon success.
#
# Upon calling this method, the session hash already contains two members:
# `l
# - sessionID - A unique 32-bit integer for this login session.
# - sessionID2 - Another unique 32-bit integer for this login session.
# `l`
#
# If the username is incorrect, then ACCOUNT_NOT_FOUND is returned.
# If the password is incorrect, then PASSWORD_INCORRECT is returned.
# If the account is banned, then ACCOUNT_BANNED is returned.
#
# Otherwise (that is, login is successful) LOGIN_SUCCESS is returned. The session
# information hash must be filled with at least the following members:
# `l
# - accountID - The account's ID, as a raw byte string.
# - sex - Specifies the gender of this account. 0 means female, 1 means male.
# `l`
sub login {
	die "This is an abstract method and has not been implemented.";
}

sub process_0064 {
	my ($self, $client, $message) = @_;
	my ($version, $username, $password, $master_version) = unpack("x2 V Z24 Z24 C1", $message);

	my $sessionID = $self->{sessionStore}->generateSessionID();
	my %session = (
		sessionID => $sessionID,
		sessionID2 => $sessionID
	);
	my $result = $self->login(\%session, $username, $password);
	if ($result == LOGIN_SUCCESS) {
		my $output = pack('V a4 V x30 C',
			$session{sessionID},	# session ID
			$session{accountID},	# account ID
			$session{sessionID2},	# session ID 2
			$session{sex}		# gender
		);
		$self->{sessionStore}->add(\%session);
		$session{state} = 'About to select character';

		# Show list of character servers.
		foreach my $charServer (@{$self->{charServers}}) {
			my $host = inet_aton($charServer->getHost());

			$output .= pack('a4 v Z20 v C1 x3',
				$host,				# host
				$charServer->getPort(),		# port
				$charServer->getName(),		# character server name
				$charServer->getPlayersCount(),	# number of players
				5				# display (5 = "don't show number of players)
			);
		}
		$client->send(pack('C2 v', 0x69, 0x00, length($output) + 4) . $output);
		$client->close();

	} elsif ($result == ACCOUNT_NOT_FOUND) {
		$client->send(pack('C*', 0x6A, 0x00, 0));
		$client->close();
	} elsif ($result == PASSWORD_INCORRECT) {
		$client->send(pack('C*', 0x6A, 0x00, 1));
		$client->close();
	} elsif ($result == ACCOUNT_BANNED) {
		$client->send(pack('C*', 0x6A, 0x00, 4));
		$client->close();
	} else {
		die "Unexpected result $result.";
	}
}

sub unhandledMessage {
	my ($self, $client) = @_;
	$client->close();
}

1;
