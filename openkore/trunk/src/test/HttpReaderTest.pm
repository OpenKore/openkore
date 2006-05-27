package HttpReaderTest;

use strict;
use Test::More;
use Utils::HttpReader;
use Time::HiRes qw(time sleep);

use constant SMALL_TEST_URL => "http://www.openkore.com/misc/testHttpReader.txt";
use constant SMALL_TEST_CONTENT => "Hello world!\n";
use constant SMALL_TEST_SIZE => 13;
use constant SMALL_TEST_CHECKSUM => 2773980202;

use constant ERROR_URL => "http://www.openkore.com/FileNotFound.txt";
use constant INVALID_URL => "http://111.111.111.111:82";

sub start {
	print "### Starting HttpReaderTest\n";
	HttpReaderTest->new()->run();
}

################

sub new {
	return bless {}, $_[0];
}

sub calcChecksum {
	use bytes;
	my ($data, $seed) = @_;
	$seed = 0 if (!defined $seed);
	my $max = 2 ** 32; # Warning: this assumes we're on a 32-bit system
	for (my $i = 0; $i < length($data); $i++) {
		$seed = ($seed * 32 + ord(substr($data, $i, 1))) % $max;
	}
	return $seed;
}

sub run {
	my ($self) = @_;
	$self->test1();
	$self->test2();
}

sub test1 {
	use constant TIMEOUT => 3000;

	my @urls = (ERROR_URL, INVALID_URL, SMALL_TEST_URL);
	my $beginTime = time;
	my $http = new MirrorHttpReader(\@urls, TIMEOUT);
	while ($http->getStatus != HttpReader::DONE && $http->getStatus != HttpReader::ERROR) {
		sleep 0.01;
	}
	
	ok(time - $beginTime < TIMEOUT * scalar(@urls) + 1,
		"Mirror selection timeout works properly");

	is($http->getStatus, HttpReader::DONE,
		"Status is HTTP_READER_DONE");
	my $len;
	my $data = $http->getData($len);
	is(calcChecksum($data), SMALL_TEST_CHECKSUM,
		"Downloaded data is correct");
}

sub test2 {
	my @urls = (SMALL_TEST_URL);
	my $http = new MirrorHttpReader(\@urls);
	while ($http->getStatus == HttpReader::CONNECTING) {
		sleep 0.01;
	}

	isnt($http->getStatus, HttpReader::CONNECTING,
		"Status is not HTTP_READER_CONNECTING");

	my $done;
	my $checksum = 0;
	my $totalSize = 0;
	while (!$done) {
		my $buf;
		my $ret = $http->pullData($buf, 2);
		ok($ret == int($ret), "pullData() returns an integer");
		ok($ret >= -2, "pullData() returns >= -2");
		isnt($ret, -2, "pullData() never fails for valid test URL");

		if ($ret == -1) {
			# Try again
			sleep 0.01;
		} elsif ($ret > 0) {
			# There is data
			is(length($buf), $ret, "Size of buffer equals pullData() return value");
			$checksum = calcChecksum($buf, $checksum);
			$totalSize += $ret;
		} else {
			# $ret == 0: EOF
			$done = 1;
		}
	}
	is($http->getStatus, HttpReader::DONE, "Status is HTTP_READER_DONE");
	is($checksum, SMALL_TEST_CHECKSUM, "Checksum is OK");
	is($totalSize, SMALL_TEST_SIZE, "Size is OK");
}

1;
