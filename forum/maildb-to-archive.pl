#!/usr/bin/env perl
use strict;
use DBI;

my $dbhost = 'localhost';
my $database = 'openkore';
my $user = 'openkore';
my $password = 'fheuigu834thgnjkler';
my $tempfile = 'mail.archive.tmp';
my $archive = 'mail.archive';

# Fetch all pending emails from the database and serialize the data in an archive.

if (-f $archive) {
	print "Archive $archive still exists, aborting...\n";
	exit 2;
}

my $db = DBI->connect("DBI:mysql:database=$database;host=$dbhost", $user, $password);
if (!$db) {
	print STDERR "Cannot connect to database.\n";
	exit 1;
}
my $sth = $db->prepare("SELECT mailto,subject,body,UNIX_TIMESTAMP(time) as time FROM mailer;");
if (!$sth) {
	print STDERR "Cannot prepare SQL statement.\n";
	exit 1;
}
$sth->execute;

if (!open(F, "> $tempfile")) {
	print STDERR "Cannot open $tempfile for writing.\n";
	exit 1;
}

my $count = 0;
while (my $row = $sth->fetchrow_hashref()) {
	print "$row->{mailto}\n";
	print F packstr($row->{mailto}) . packstr($row->{subject})
	  . packstr($row->{body}) . pack("V", $row->{time});
	$count++;
}
close F;

if ($count == 0) {
	print "No pending emails.\n";
	unlink $tempfile;
} else {
	print "$count emails saved to archive.\n";
	rename $tempfile, $archive;
	$db->do("TRUNCATE TABLE mailer;");
}


sub packstr {
	return pack("V", length($_[0])) . $_[0];
}
