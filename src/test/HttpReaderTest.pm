package HttpReaderTest;

use strict;
use Test::More;
use Utils::HttpReader;
use Time::HiRes qw(time sleep);
use IO::Socket::INET;
use IO::Select;

use constant SMALL_TEST_CONTENT => "Hello world!\n";
use constant SMALL_TEST_SIZE => 13;
use constant SMALL_TEST_CHECKSUM => 2773980202;
use constant SMALL_TEST_DATA_CHECKSUM => 2773980202;

my $TEST_SERVER_PORT;
my $INVALID_PORT;
my $TEST_SERVER_SOCKET;
my $TEST_SERVER_SELECT;
my %TEST_SERVER_BUFFERS;

sub SMALL_TEST_URL { return "http://127.0.0.1:$TEST_SERVER_PORT/small.txt"; }
sub ERROR_URL { return "http://127.0.0.1:$TEST_SERVER_PORT/missing.txt"; }
sub ERROR_URL2 { return "http://127.0.0.1:$TEST_SERVER_PORT/also-missing.txt"; }
sub INVALID_URL { return "http://127.0.0.1:$INVALID_PORT/"; }

sub start {
	print "### Starting HttpReaderTest\n";
	StdHttpReader::init();
	$TEST_SERVER_PORT = startTestHttpServer();
	$INVALID_PORT = reserveUnusedPort();
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

END {
	stopTestHttpServer();
}

sub reserveUnusedPort {
	my $socket = IO::Socket::INET->new(
		LocalAddr => '127.0.0.1',
		LocalPort => 0,
		Proto => 'tcp',
		Listen => 1,
		ReuseAddr => 1,
	) or die "Unable to reserve an unused port: $!";
	my $port = $socket->sockport();
	close $socket;
	return $port;
}

sub startTestHttpServer {
	$TEST_SERVER_SOCKET = IO::Socket::INET->new(
		LocalAddr => '127.0.0.1',
		LocalPort => 0,
		Proto => 'tcp',
		Listen => 5,
		ReuseAddr => 1,
	) or die "Unable to start HTTP test server: $!";
	$TEST_SERVER_SOCKET->blocking(0);
	$TEST_SERVER_SELECT = IO::Select->new($TEST_SERVER_SOCKET);
	return $TEST_SERVER_SOCKET->sockport();
}

sub stopTestHttpServer {
	return unless $TEST_SERVER_SELECT;
	for my $handle ($TEST_SERVER_SELECT->handles()) {
		close $handle;
	}
	undef $TEST_SERVER_SELECT;
	undef $TEST_SERVER_SOCKET;
	%TEST_SERVER_BUFFERS = ();
}

sub pumpTestHttpServer {
	return unless $TEST_SERVER_SELECT;
	for my $handle ($TEST_SERVER_SELECT->can_read(0)) {
		if (fileno($handle) == fileno($TEST_SERVER_SOCKET)) {
			my $client = $TEST_SERVER_SOCKET->accept();
			next unless $client;
			$client->blocking(0);
			$client->autoflush(1);
			$TEST_SERVER_SELECT->add($client);
			$TEST_SERVER_BUFFERS{fileno($client)} = '';
			next;
		}

		my $buffer = '';
		my $read = sysread($handle, $buffer, 1024);
		if (defined $read && $read > 0) {
			$TEST_SERVER_BUFFERS{fileno($handle)} .= $buffer;
		}

		my $request = $TEST_SERVER_BUFFERS{fileno($handle)} || '';
		next if defined $read && $read > 0 && $request !~ /\r?\n\r?\n/s && length($request) <= 8192;

		my ($method, $path) = $request =~ /\A([A-Z]+)\s+(\S+)/;
		if (defined $method && $method eq 'GET' && defined $path && $path eq '/small.txt') {
			my $body = SMALL_TEST_CONTENT;
			print {$handle} "HTTP/1.0 200 OK\r\n";
			print {$handle} "Content-Length: " . length($body) . "\r\n";
			print {$handle} "Content-Type: text/plain\r\n";
			print {$handle} "Connection: close\r\n\r\n";
			print {$handle} $body;
		} else {
			my $body = "Not Found\n";
			print {$handle} "HTTP/1.0 404 Not Found\r\n";
			print {$handle} "Content-Length: " . length($body) . "\r\n";
			print {$handle} "Content-Type: text/plain\r\n";
			print {$handle} "Connection: close\r\n\r\n";
			print {$handle} $body;
		}

		$TEST_SERVER_SELECT->remove($handle);
		delete $TEST_SERVER_BUFFERS{fileno($handle)};
		close $handle;
	}
}

sub waitUntilFinished {
	my ($http) = @_;
	while ($http->getStatus != HttpReader::DONE && $http->getStatus != HttpReader::ERROR) {
		pumpTestHttpServer();
		sleep 0.01;
	}
	pumpTestHttpServer();
}

sub run {
	my ($self) = @_;
	$self->testMirrorSelection();
	$self->testDownload();
	$self->testFailedDownload();
}

sub testMirrorSelection {
	use constant TIMEOUT => 3000;

	my @urls = (ERROR_URL, INVALID_URL, SMALL_TEST_URL);
	my $beginTime = time;
	my $http = new MirrorHttpReader(\@urls, TIMEOUT);
	waitUntilFinished($http);

	# Note that this test isn't entirely reliable because
	# it assumes that your network connection can connect
	# to SMALL_TEST_URL within TIMEOUT miliseconds.
	ok(time - $beginTime < TIMEOUT * scalar(@urls) + 1,
		"Mirror selection timeout works properly");

	is($http->getStatus, HttpReader::DONE,
		"Status is HTTP_READER_DONE");
	my $len;
	my $data = $http->getData($len);
	is(calcChecksum($data), SMALL_TEST_DATA_CHECKSUM,
		"Downloaded data is correct");
}

sub testDownload {
	my @urls = (SMALL_TEST_URL);
	my $http = new MirrorHttpReader(\@urls);
	while ($http->getStatus == HttpReader::CONNECTING) {
		pumpTestHttpServer();
		sleep 0.01;
	}
	pumpTestHttpServer();

	isnt($http->getStatus, HttpReader::CONNECTING,
		"Status is not HTTP_READER_CONNECTING");

	my $done;
	my $checksum = 0;
	my $totalSize = 0;
	while (!$done) {
		my $buf;
		my $ret = $http->pullData($buf, 1024 * 32);

		ok($ret == int($ret), "pullData() returns an integer");
		ok($ret >= -2, "pullData() returns >= -2");
		isnt($ret, -2, "pullData() never fails for valid test URL");

		if ($ret == -1) {
			# Try again
			pumpTestHttpServer();
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

sub testFailedDownload {
	my @urls = (ERROR_URL2);
	my $http = new MirrorHttpReader(\@urls, 3000);
	waitUntilFinished($http);
	is($http->getStatus, HttpReader::ERROR, "Status for ERROR_URL is HTTP_READER_ERROR");

	my $buf;
	my $ret = $http->pullData($buf, 1024);
	is($ret, -2, "pullData() returns -2 for ERROR_URL");
}

1;
