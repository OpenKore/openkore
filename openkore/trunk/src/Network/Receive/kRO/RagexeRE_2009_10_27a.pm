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

package Network::Receive::kRO::RagexeRE_2009_10_27a;

use strict;
use base qw(Network::Receive::kRO::RagexeRE_2009_10_06a);
use Globals qw($char);
use Log qw(message);
use Translation qw(T TF);

use constant {
   EXP_FROM_BATTLE => 0x0,
   EXP_FROM_QUEST => 0x1,
   VAR_EXP => 0x1,
   VAR_JOBEXP => 0x2,
};

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	my %packets = (
		# 0x07f5 is sent packet
		'07F6' => ['exp', 'a4 V v2', [qw(ID val type flag)]], # 14 # type: 1 base, 2 job; flag: 0 normal, 1 quest # TODO: use. I think this replaces the exp gained message trough guildchat hack
	);

	foreach my $switch (keys %packets) {
		$self->{packet_list}{$switch} = $packets{$switch};
	}

	return $self;
}

# 07F6 (exp) doesn't change any exp information because 00B1 (exp_zeny_info) is always sent with it
# r7643 - copy-pasted from ServerType0.pm
sub exp {
   my ($self, $args) = @_;
   my $max = {VAR_EXP, $char->{exp_max}, VAR_JOBEXP, $char->{exp_job_max}}->{$args->{type}};
   $args->{percent} = $max ? $args->{val} / $max * 100 : 0;
   if ($args->{flag} == EXP_FROM_BATTLE) {
      if ($args->{type} == VAR_EXP) {
         message TF("Base Exp gained: %d (%.2f%%)n", @{$args}{qw(val percent)}), 'exp2', 2;
      } elsif ($args->{type} == VAR_JOBEXP) {
         message TF("Job Exp gained: %d (%.2f%%)n", @{$args}{qw(val percent)}), 'exp2', 2;
      } else {
         message TF("Unknown (type=%d) Exp gained: %dn", @{$args}{qw(type val)}), 'exp2', 2;
      }
   } elsif ($args->{flag} == EXP_FROM_QUEST) {
      if ($args->{type} == VAR_EXP) {
         message TF("Base Quest Exp gained: %d (%.2f%%)n", @{$args}{qw(val percent)}), 'exp2', 2;
      } elsif ($args->{type} == VAR_JOBEXP) {
         message TF("Job Quest Exp gained: %d (%.2f%%)n", @{$args}{qw(val percent)}), 'exp2', 2;
      } else {
         message TF("Unknown (type=%d) Quest Exp gained: %dn", @{$args}{qw(type val)}), 'exp2', 2;
      }
   } else {
      if ($args->{type} == VAR_EXP) {
         message TF("Base Unknown (flag=%d) Exp gained: %d (%.2f%%)n", @{$args}{qw(flag val percent)}), 'exp2', 2;
      } elsif ($args->{type} == VAR_JOBEXP) {
         message TF("Job Unknown (flag=%d) Exp gained: %d (%.2f%%)n", @{$args}{qw(flag val percent)}), 'exp2', 2;
      } else {
         message TF("Unknown (type=%d) Unknown (flag=%d) Exp gained: %dn", @{$args}{qw(type flag val)}), 'exp2', 2;
      }
   }
}

=pod
//2009-10-27aRagexeRE
0x07f5,6
0x07f6,14
=cut

1;