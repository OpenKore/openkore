package Poseidon::RagnaServerHolder;

use strict;
use Misc;
use Poseidon::RagnarokServer;
use FileParsers;

sub new {
	my ($class, $number_of_clients, $host, $first_ragna_port) = @_;
	my $self;
	
	$self->{username_to_index} = {};
	$self->{index_to_username} = {};
	
	$self->{clients_num} = $number_of_clients;
	
	$self->{clients_servers} = [];
	
	foreach my $server_index (0..($number_of_clients - 1)) {
		my $current_ragna_port = ($first_ragna_port + $server_index);
		
		my $server = Poseidon::RagnarokServer->new($current_ragna_port, $host, $self, $server_index);
		
		push(@{$self->{clients_servers}}, $server);
		
		print "Ragnarok Online Server Opened port ".$current_ragna_port." for a client\n";
	}

	return bless($self, $class);
}

sub find_bounded_client {
	my ($self, $username) = @_;
	if (exists $self->{username_to_index}{$username}) {
		return $self->{username_to_index}{$username};
	} else {
		return -1;
	}
}

sub find_free_client {
	my ($self) = @_;
	
	foreach my $server_index (0..$#{$self->{clients_servers}}) {
		my $server = $self->{clients_servers}[$server_index];
		
		next unless ($server);
		next unless ($server->{client});
		next unless ($server->{client}->{connectedToMap});
		next if (defined $server->{boundUsername});
		return $server_index;
	}
	
	return -1;
}

sub bound_client {
	my ($self, $index, $username) = @_;
	my $ragserver = $self->{clients_servers}[$index];
	$ragserver->{boundUsername} = $username;
	$self->{username_to_index}{$username} = $index;
	$self->{index_to_username}{$index} = $username;
	print "[PoseidonServer]-> Ragnarok Online Client of index: ".$index." was bounded to username: ".$username."\n";
}

sub iterate {
	my ($self) = @_;
	
	foreach my $server_index (0..$#{$self->{clients_servers}}) {
		my $server = $self->{clients_servers}[$server_index];
		$server->iterate;
	}
}

1;

