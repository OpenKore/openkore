#  OpenKore - CRAM: Challenge Response Authentication Mechanism
#
#  Copyright (c) 2006 OpenKore Development Team
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#########################################################################
##
# MODULE DESCRIPTION: Challenge Response Authentication Mechanism
#

package Utils::CRAM;

use strict;
use Utils;

# ppm install Digest-SHA-PurePerl
# $digest = hmac_sha256_hex($data, $key);
use Digest::SHA::PurePerl qw(hmac_sha256_hex);

sub new {
	my ($class) = @_;
	my %self;
	return bless \%self, $class;
}

#########################################################################
#
# Server functions
#

##
# String CRAM::challengeString(String accountName, int length)
# accountName: the account name, as it exists in the server's database
# length: the length of the challenge string to be made
# Requires: defined($response)
#
# Returns a randomly generated challenge string
sub challengeString {
	my ($self, $accountName, $length) = @_;
	$length = 32 unless ($length);

	# NOTE: preferably other random-string generators would be used here
	my $challengeString = vocalString($length);

	# store the challenge string into a hash element for later retrieval
	# NOTE: a database entry may also be used here
	$self->{$accountName} = $challengeString;

	return $challengeString;
}

##
# boolean CRAM::authenticate(String response)
# response: the response as sent by the party being challenged
# Requires: defined($response)
#
# Returns true if the digest computed matches the digest sent by the party being challenged
sub authenticate {
	my ($self, $response) = @_;

	my ($accountName, $digest) = split(/ /, $response);
	my $challengeString = $self->{$accountName};

	# get password from database
	my $password = "poseidon"; # temporarily hardcoded - ideally grabbed from a database

	# calculate our own notion  of the digest using the provided account name, the password
	# as retrieved from the database, and the challengeString that was sent before
	my $ownDigest = hmac_sha256_hex($challengeString, $password);

	return ($ownDigest eq $digest);
}

#########################################################################
#
# Client functions
#

##
# String CRAM::encrypt(String accountName, String password, String challengeString)
# accountName: the account name, as it exists in the server's database
# password: the password matching the account name
# challengeString: the challenge string, as sent by the server
# Requires:
#	defined($accountName)
#	defined($password)
#	defined($challengeString)
# Ensures: defined($response)
#
# Encrypt the challenge string sent by the server using the accout name and password.
# Returns a string in this format: <accountName><space><challenge string hashed using the password>
sub encrypt {
	my ($self, $accountName, $password, $challengeString) = @_;

	# calculate a digest using the password as the key
	my $digest = hmac_sha256_hex($challengeString, $password);

	# prepend the account name and a space to the digest
	my $response = $accountName . ' ' . $digest;

	return ($response);
}

1;
