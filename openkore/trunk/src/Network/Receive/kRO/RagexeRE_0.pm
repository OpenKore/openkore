#########################################################################
#  OpenKore - Packet sending
#  This module contains functions for sending packets to the server.
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#
#  $Revision: 6687 $
#  $Id: kRO.pm 6687 2009-04-19 19:04:25Z technologyguild $
########################################################################
# Korea (kRO)
# The majority of private servers use eAthena, this is a clone of kRO

package Network::Receive::kRO::RagexeRE_0;

use strict;
use Network::Receive::kRO::RagexeRE_2009_01_21a;
use base qw(Network::Receive::kRO::RagexeRE_2009_01_21a);

use Log qw(message warning error debug);

use Globals qw($captcha_done);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	my %packets = (
		'07E6' => ['captcha_session_ID', 'v V', [qw(ID generation_time)]], # 8
		'07E8' => ['captcha_image', 'v a*', [qw(len image)]], # 0
		'07E9' => ['captcha_answer', 'v C', [qw(code flag)]], # 5
	);
	
	foreach my $switch (keys %packets) {
		$self->{packet_list}{$switch} = $packets{$switch};
	}

	return $self;
}

sub captcha_session_ID {
	my ($self, $args) = @_;
	debug $self->{packet_list}{$args->{switch}}->[0] . " " . join(', ', @{$args}{@{$self->{packet_list}{$args->{switch}}->[2]}}) . "\n";
}

sub captcha_image {
	my ($self, $args) = @_;
	debug $self->{packet_list}{$args->{switch}}->[0] . " " . join(', ', @{$args}{@{$self->{packet_list}{$args->{switch}}->[2]}}) . "\n";
	
	my $hookArgs = {image => $args->{image}};
	Plugins::callHook ('captcha_image', $hookArgs);
	return 1 if $hookArgs->{return};
	
	my $file = $Settings::logs_folder . "/captcha.bmp";
	open my $DUMP, '>', $file;
	print $DUMP $args->{image};
	close $DUMP;
	
	$hookArgs = {file => $file};
	Plugins::callHook ('captcha_file', $hookArgs);
	return 1 if $hookArgs->{return};
	
	warning "captcha.bmp has been saved to: " . $Settings::logs_folder . ", open it, solve it and use the command: captcha <text>\n";
}

sub captcha_answer {
	my ($self, $args) = @_;
	debug $self->{packet_list}{$args->{switch}}->[0] . " " . join(', ', @{$args}{@{$self->{packet_list}{$args->{switch}}->[2]}}) . "\n";
	debug ($args->{flag} ? "good" : "bad") . " answer\n";
	$captcha_done = $args->{flag};
	
	Plugins::callHook ('captcha_answer', {flag => $args->{flag}});
}

=pod
07E5 8
07E6 8
07E7 32
07E8 0
07E9 5
=cut

1;