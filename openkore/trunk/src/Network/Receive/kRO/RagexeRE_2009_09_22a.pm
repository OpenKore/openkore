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

package Network::Receive::kRO::RagexeRE_2009_09_22a;

use strict;
use base qw(Network::Receive::kRO::RagexeRE_2009_08_25a);

use Log qw(message warning error debug);

use Globals qw($captcha_state);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	my %packets = (
		# 0x07e5 is sent packet
		'07E6' => ['captcha_session_ID', 'v V', [qw(ID generation_time)]], # 8
		# 0x07e7 is sent packet
		'07E8' => ['captcha_image', 'v a*', [qw(len image)]], # -1
		'07E9' => ['captcha_answer', 'v C', [qw(code flag)]], # 5	
	);

	foreach my $switch (keys %packets) {
		$self->{packet_list}{$switch} = $packets{$switch};
	}

	return $self;
}

# 07E6
sub captcha_session_ID {
	my ($self, $args) = @_;
	debug $self->{packet_list}{$args->{switch}}->[0] . " " . join(', ', @{$args}{@{$self->{packet_list}{$args->{switch}}->[2]}}) . "\n";
}

# 0x07e8,-1
# todo: debug + remove debug message
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

# 0x07e9,5
# todo: debug + remove debug message
sub captcha_answer {
	my ($self, $args) = @_;
	debug $self->{packet_list}{$args->{switch}}->[0] . " " . join(', ', @{$args}{@{$self->{packet_list}{$args->{switch}}->[2]}}) . "\n";
	debug ($args->{flag} ? "good" : "bad") . " answer\n";
	$captcha_state = $args->{flag};
	
	Plugins::callHook ('captcha_answer', {flag => $args->{flag}});
}

=pod
//2009-09-22aRagexeRE
0x07e5,8
//0x07e6,8
0x07e7,32
0x07e8,-1
0x07e9,5
=cut

1;