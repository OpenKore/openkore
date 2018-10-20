#########################################################################
#  OpenKore - Packet Receiveing
#  This module contains functions for Receiveing packets to the server.
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
########################################################################
# Korea (kRO)
# The majority of private servers use eAthena, this is a clone of kRO

package Network::Receive::kRO::RagexeRE_2015_11_04a;

use strict;
use base qw(Network::Receive::kRO::RagexeRE_2015_10_29a);

# TODO: remove 'use Globals' from here, instead pass vars on
use Globals qw($rodexWrite);
use Log qw(message warning error debug);
use Misc;
use Utils;

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	
	my %packets = (
		'0A14' => ['rodex_check_player', 'V v2', [qw(char_id class base_level)]],
	);
	
	$self->{packet_list}{$_} = $packets{$_} for keys %packets;
	
	return $self;
}

sub rodex_open_write {
	my ( $self, $args ) = @_;
	$rodexWrite = {};
	
	$rodexWrite->{items} = new InventoryList;
	$rodexWrite->{name} = $args->{name};
}

sub rodex_check_player {
	my ( $self, $args ) = @_;
	if (!$args->{char_id}) {
		error "Could not find player with name '".$args->{name}."'.";
		return;
	}
	
	my $print_msg = center(" " . "Rodex Mail Target" . " ", 79, '-') . "\n";
	
	$print_msg .= swrite("@<<<<< @<<<<<<<<<<<<<<<<<<<<<<<< @<<<<<<<<<<< @<<< @<<<<<< @<<<<<<<<<<<<<<< @<<<<<<<< @<<<<<<<<<", ["Name:", $rodexWrite->{name}, "Base Level:", $args->{base_level}, "Class:", $args->{class}, "Char ID:", $args->{char_id}]);
	
	$print_msg .= sprintf("%s\n", ('-'x79));
	message $print_msg, "list";
	@{$rodexWrite->{target}}{qw(char_id class base_level)} = @{$args}{qw(char_id class base_level)};
}

1;

