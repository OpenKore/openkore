# $Header$
#
# patchconnect by Arachno
#
# This source code is licensed under the
# GNU General Public License, Version 2.
# See http://www.gnu.org/licenses/gpl.html

package patchconnect;

our $Version = "0.1";
my $cvs = 1;

use strict;
use IO::Socket;
use Plugins;
use Globals;
use Utils;
use Log qw(message error warning);

if (defined $cvs) {
  open(MF, "< $Plugins::current_plugin" )
      or die "Can't open $Plugins::current_plugin: $!";
  while (<MF>) {
    if (/Header:/) {
      my ($rev) = $_ =~ /\.pl,v (.*?) [0-9]{4}/i;
      $Version .= "cvs rev ".$rev;
      last;
    }
  }
  close MF;
};
                                        
undef $cvs if defined $cvs;
                                        
our %cache = (timeout => 30);

Plugins::register('patchconnect', 'asks patchserver for login permission', \&Unload, \&Unload);

my $hooks = Plugins::addHooks(
            ['start3', \&checkConfig, undef],
            ['Network::connectTo', \&patchCheck, undef],
            ['Command_post', \&commandHandler, undef]
);
    
sub Unload {
  Plugins::delHooks($hooks);
  message "patchconnect unloaded.\n";
};

# checks configuration
sub checkConfig {
  my $master = $masterServers{$config{master}};
  if (!$master->{patchserver}) {
    warning "No patchserver specified. Login will always be granted.\n";
    return;
  };
  warning "No path for patch_allow.txt specified. Using ".
    "default value: /patch02\n" unless $master->{patchpath};
};

# just a facade for "patchserver"
sub commandHandler {
  my (undef, $arg) = @_;
  my ($cmd, $param) = split(/ /, $arg->{input});
  if ($cmd eq 'patch') {
    if ($param eq 'check') {patchCheckCmd()}
    elsif ($param eq 'version') {showVersion()}
    else {usage()}
    $arg->{return} = 1;
  };
};

# prints patchconnect version
sub showVersion {
  message "patchconnect plugin version ".$Version."\n", "list";
};
  
# prints a little usage text
sub usage {
  message "usage: patch [check|version]\n", "list";
};

# patchClient
# returns:
#   0 if login is prohibited
#   1 if login is allowed or no patchserver is specified
#   2 if patchserver could not be reached or neither
#     'allow' nor "deny" are sent
sub patchClient {
  my $master = $masterServers{$config{master}};
  return 1 unless ($master->{patchserver});
  my $patch;
  if ($master->{patchpath}) {$patch = $master->{patchpath}}
  else {$patch = "/patch02"};
  $patch .= "/patch_allow.txt";

  my $sock = IO::Socket::INET->new(
          PeerAddr => $master->{patchserver},
          PeerPort => 'http(80)',
          Proto => 'tcp');
  return 2 unless $sock;

  print $sock "GET $patch HTTP/1.0\r\nAccept: */*\r\n".
    "User-Agent: Patch Client\r\nCookie: MtrxTrackingID=" . "0123456789" x 3 .
    "01\r\nHost: " . $master->{patchserver} . "\r\n\r\n";
  foreach (<$sock>) {
    return 1 if /^allow$/;
    return 0 if /^deny$/;
  };
  return 2;
};

sub patchCheckCmd {
  message "checking patchserver...\n";
  my $access = patchClient();
  if ($access == 0) {message "patchserver prohibits login.\n"}
  elsif ($access == 1) {message "patchserver grants login.\n"}
  else {message "could not connect to patchserver or reply is neither allow nor deny.\n"};
};

sub patchCheck {
  my (undef, $arg) = @_;
  my $access;
  if (timeOut($timeout{patchserver})) {
    message "checking patchserver access control...\n";
    my $access;
    if (timeOut(\%cache)) {
      message "contacting patchserver...\n";
      $access = $cache{response} = patchClient();
      $cache{time} = time;
    } else {
      message "answer is still in cache.\n";
      $access = $cache{response};
    };
    if ($access == 1) {
      message "patchserver grants login.\n";
      ${$arg->{return}} = 0; return;
    } elsif ($access == 0) {
      warning "patchserver prohibits login.\n";
      $timeout{patchserver}{time} = time;
    } else {
      error "unable to connect to patchserver or neither 'allow' nor 'deny' received.\n";
      error "disallowing connect.\n";
    };
  } else {
    warning "disallowing connect until next check.\n";
  };
  ${$arg->{return}} = 1;
};

return 1;
