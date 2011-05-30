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
	my ($switch, $version, $username, $password, $master_version) = unpack("v V Z24 Z24 C1", $message);

	if ($switch == 0x02B0) {
		# TODO: merge back with sendMasterHANLogin
		my $key = pack('C24', (6, 169, 33, 64, 54, 184, 161, 91, 81, 46, 3, 213, 52, 18, 0, 6, 61, 175, 186, 66, 157, 158, 180, 48));
		my $chain = pack('C24', (61, 175, 186, 66, 157, 158, 180, 48, 180, 34, 218, 128, 44, 159, 172, 65, 1, 2, 4, 8, 16, 32, 128));
		my $in = pack('a24', $password);
		my $rijndael = Utils::Rijndael->new();
		$rijndael->MakeKey($key, $chain, 24, 24);
		$password = unpack("Z24", $rijndael->Decrypt($in, undef, 24, 0));
	}

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
		$client->send(pack('v C Z20', 0x006A, 0, 'x'x20));
		$client->close();
	} elsif ($result == PASSWORD_INCORRECT) {
		$client->send(pack('v C Z20', 0x006A, 1, 'x'x20));
		$client->close();
	} elsif ($result == ACCOUNT_BANNED) {
		$client->send(pack('v C Z20', 0x006A, 4, 'x'x20));
		$client->close();
	} else {
		die "Unexpected result $result.";
	}
}

# sendClientMD5Hash
sub process_0204 {}

sub unhandledMessage {
	my ($self, $client) = @_;
	$client->close();
}

1;
