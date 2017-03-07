######################################################################### 
#  OpenKore - Network subsystem 
#  This module contains functions for sending messages to the server. 
# 
#  This software is open source, licensed under the GNU General Public 
#  License, version 2. 
#  Basically, this means that you're allowed to modify and distribute 
#  this software. However, if you distribute modified versions, you MUST 
#  also distribute the source code. 
#  See http://www.gnu.org/licenses/gpl.html for the full license. 
######################################################################### 
package Network::Send::twRO; 
 
use strict; 
use Globals; 
use warnings;
use Network::Send::ServerType0; 
use base qw(Network::Send::ServerType0); 
use Log qw(error debug); 
use I18N qw(stringToBytes); 
use Utils qw(getTickCount getHex getCoordString); 
use Math::BigInt; 
 
sub new { 
	my ($class) = @_; 
	my $self = $class->SUPER::new(@_); 
	$self->{char_create_version} = 1; 
 	$self->{randomSyncClock} = int(rand(4294967296));#Ninja patch
	
	# Shuffle packets
	my %npShuffles;
	my $loadShuffles = Settings::addTableFile('shuffles.txt',loader => [\&parseShuffles,\%npShuffles], mustExist => 1);
	Settings::loadByHandle($loadShuffles);
	
	# Keys
	my @npKeys;
	my $loadKeys = Settings::addTableFile('keys.txt',loader => [\&parseKeys,\@npKeys], mustExist => 1);
	Settings::loadByHandle($loadKeys);

	$self->{packet_list}{$_} = $self->{packet_list}{$npShuffles{$_}{original}} for keys %npShuffles; #Shuffle handle header ID
	$self->{packet_lut}{$npShuffles{$_}{function}} = $_ for keys %npShuffles; #Shuffle reconstruct ID

	$self->cryptKeys($npKeys[0], $npKeys[1], $npKeys[2]);
	
	
	my %handlers = qw( 
		party_setting 07D7
		buy_bulk_vender 0801
		char_create 0970
		send_equip 0998
		actor_status_active 0983
		actor_status_active 0984
	); 
	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers; 
	
	my %packets = ( 
		'0064' => ['master_login', 'V Z24 a24 C', [qw(version username password_rijndael master_version)]], 
	); 
	$self->{packet_list}{$_} = $packets{$_} for keys %packets; 

	return $self; 
} 
 
sub parse_master_login {
	my ($self, $args) = @_;
	
	if (exists $args->{password_md5_hex}) {
		$args->{password_md5} = pack 'H*', $args->{password_md5_hex};
	}

	if (exists $args->{password_rijndael}) {
		my $key = pack('C24', (0x06, 0xA9, 0x21, 0x40, 0x36, 0xB8, 0xA1, 0x5B, 0x51, 0x2E, 0x03, 0xD5, 0x34, 0x12, 0x00, 0x06, 0x06, 0xA9, 0x21, 0x40, 0x36, 0xB8, 0xA1, 0x5B));
		my $chain = pack('C24', (0x3D, 0xAF, 0xBA, 0x42, 0x9D, 0x9E, 0xB4, 0x30, 0xB4, 0x22, 0xDA, 0x80, 0x2C, 0x9F, 0xAC, 0x41, 0x3D, 0xAF, 0xBA, 0x42, 0x9D, 0x9E, 0xB4, 0x30));
		my $in = pack('a24', $args->{password_rijndael});
		my $rijndael = Utils::Rijndael->new;
		$rijndael->MakeKey($key, $chain, 24, 24);
		$args->{password} = unpack("Z24", $rijndael->Decrypt($in, undef, 24, 0));
	}
}

sub reconstruct_master_login {
	my ($self, $args) = @_;
	
	$args->{ip} = '192.168.0.2' unless exists $args->{ip}; # gibberish
	$args->{mac} = '111111111111' unless exists $args->{mac}; # gibberish
	$args->{mac_hyphen_separated} = join '-', $args->{mac} =~ /(..)/g;
	$args->{isGravityID} = 0 unless exists $args->{isGravityID};
	
	if (exists $args->{password}) {
		for (Digest::MD5->new) {
			$_->add($args->{password});
			$args->{password_md5} = $_->clone->digest;
			$args->{password_md5_hex} = $_->hexdigest;
		}

		my $key = pack('C24', (0x06, 0xA9, 0x21, 0x40, 0x36, 0xB8, 0xA1, 0x5B, 0x51, 0x2E, 0x03, 0xD5, 0x34, 0x12, 0x00, 0x06, 0x06, 0xA9, 0x21, 0x40, 0x36, 0xB8, 0xA1, 0x5B));
		my $chain = pack('C24', (0x3D, 0xAF, 0xBA, 0x42, 0x9D, 0x9E, 0xB4, 0x30, 0xB4, 0x22, 0xDA, 0x80, 0x2C, 0x9F, 0xAC, 0x41, 0x3D, 0xAF, 0xBA, 0x42, 0x9D, 0x9E, 0xB4, 0x30));
		my $in = pack('a24', $args->{password});
		my $rijndael = Utils::Rijndael->new;
		$rijndael->MakeKey($key, $chain, 24, 24);
		$args->{password_rijndael} = $rijndael->Encrypt($in, undef, 24, 0);
	}
}
 
 
sub sell_result { 
	my ($self, $args) = @_; 
 
	$self->SUPER::sell_result($args); 
 
	# The server won't let us move until we send the sell complete packet. 
	$self->sendSellComplete; 
}

sub sendSellBulk {
	my ($self, $args) = @_; 
 
	$self->SUPER::sendSellBulk($args); 
	
	$self->sendSellComplete; #The server won't let us move until we send the sell complete packet. 
}

sub buy_result { 
	my ($self, $args) = @_; 
 
	$self->SUPER::buy_result($args); 
 
	# The server won't let us move until we send the sell complete packet. 
	$self->sendSellComplete; 
} 

sub sendCharCreate { 
	my ($self, $slot, $name, $hair_style, $hair_color) = @_; 
	$hair_color ||= 1; 
	$hair_style ||= 0; 
 
	my $msg = pack('C2 a24 C v2', 0x70, 0x09,  
		stringToBytes($name), $slot, $hair_color, $hair_style); 
	$self->sendToServer($msg); 
	debug "Sent sendCharCreate [0970]\n", "sendPacket", 2; 
} 

sub sendMapLoaded {
	my $self = shift;
	$syncSync = pack("V", $self->{randomSyncClock} + int(time - $startTime_EXP)); #Ninja patch
	debug "Sending Map Loaded\n", "sendPacket";
	$self->sendToServer($self->reconstruct({switch => 'map_loaded'}));
	Plugins::callHook('packet/sendMapLoaded');
}

sub reconstruct_sync {
	my ($self, $args) = @_;
	$args->{time} = $self->{randomSyncClock} + int(time - $startTime_EXP); #Ninja patch
}

sub sendSync {
	my ($self, $initialSync) = @_;
	# XKore mode 1 lets the client take care of syncing.
	return if ($self->{net}->version == 1);

	$self->sendToServer($self->reconstruct({switch => 'sync'}));
	debug "Sent Sync\n", "sendPacket", 2;
}

sub parseShuffles {
	my ($file, $r_hash) = @_;
	
	%{$r_hash} = ();
	my $reader = new Utils::TextReader($file);
	while (!$reader->eof()) {
		my $line = $reader->readLine();
		next if ($line =~ /^#/);
		$line =~ s/[\r\n]//g;
		next if (length($line) == 0);
		
		my ($shuffleID ,$oriID, $function) = split /\s+/, $line, 3;
		$shuffleID =~ s/^(0x[0-9a-f]+)$/hex $1/e;
		$oriID =~ s/^(0x[0-9a-f]+)$/hex $1/e;
		$r_hash->{$shuffleID}{function} = $function;
		$r_hash->{$shuffleID}{original} = $oriID;
	}
	close FILE;
	
	return 1;
}

sub parseKeys {
	my ($file, $keys) = @_;
	
	my $reader = new Utils::TextReader($file);
	while (!$reader->eof()) {
		my $line = $reader->readLine();
		next if ($line =~ /^#/);
		$line =~ s/[\r\n]//g;
		next if (length($line) == 0);

		push @$keys, hex($line);
	}
	close FILE;

	return 1;
}
 
1; 