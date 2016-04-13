package WebMonitor::WebSocketServer;
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#############################################

use strict;
use base qw(Base::WebSocketServer);
use JSON;

use Globals qw($char $field);

sub new {
	my $class = shift;

	my $self = $class->SUPER::new(@_);

	Scalar::Util::weaken(my $weak = $self);

	my $data = [$weak];
	$self->{logHook} = Log::addHook(\&console, $data);

	$self->{hooks} = Plugins::addHooks(
		['packet/hp_sp_changed' => sub { $weak->values(qw(char_hp char_sp)) } ],
		['packet/stat_info' => sub { $weak->values } ],
		['packet/stat_info2' => sub { $weak->values(qw(char_str char_str_bonus char_agi char_agi_bonus char_vit char_vit_bonus char_int char_int_bonus char_dex char_dex_bonus char_luk char_luk_bonus)) } ],
		['packet/map_loaded' => sub { $weak->values(qw(char_pos_x char_pos_y)) } ],
		['packet/actor_movement_interrupted' => sub { $weak->values(qw(char_pos_x char_pos_y)) } ],
		['packet/character_moves' => sub { $weak->values(qw(char_pos_x char_pos_y)) } ],
		['packet/high_jump' => sub { $weak->values(qw(char_pos_x char_pos_y)) } ],
		['packet/map_change' => sub { $weak->values(qw(field_description field_image char_pos_x char_pos_y)) } ],
		['packet/map_changed' => sub { $weak->values(qw(field_description field_image char_pos_x char_pos_y)) } ],
	);

	$self
}

sub console {
	my ($type, $domain, $level, $currentVerbosity, $message, $data) = @_;
	my $self = $data->[0] or return;

	if ($level <= $currentVerbosity) {
		$self->broadcast(encode_json({type => 'console', data => {
			message => $message,
			domain => $domain,
			class => webMonitorServer::messageClass($type, $domain),
		}}));
	}
}

my %valueSources = (
	char_lv => sub { $char->{lv} },
	char_lv_job => sub { $char->{lv_job} },
	char_hp => sub { $char->{hp} },
	char_hp_max => sub { $char->{hp_max} },
	char_sp => sub { $char->{sp} },
	char_sp_max => sub { $char->{sp_max} },
	char_exp => sub { $char->{exp} },
	char_exp_max => sub { $char->{exp_max} },
	char_exp_job => sub { $char->{exp_job} },
	char_exp_job_max => sub { $char->{exp_job_max} },
	char_weight => sub { $char->{weight} },
	char_weight_max => sub { $char->{weight_max} },
	char_zeny => sub { $char->{zeny} },
	char_str => sub { $char->{str} },
	char_str_bonus => sub { $char->{str_bonus} },
	char_agi => sub { $char->{agi} },
	char_agi_bonus => sub { $char->{agi_bonus} },
	char_vit => sub { $char->{vit} },
	char_vit_bonus => sub { $char->{vit_bonus} },
	char_int => sub { $char->{int} },
	char_int_bonus => sub { $char->{int_bonus} },
	char_dex => sub { $char->{dex} },
	char_dex_bonus => sub { $char->{dex_bonus} },
	char_luk => sub { $char->{luk} },
	char_luk_bonus => sub { $char->{luk_bonus} },
	char_attack => sub { $char->{attack} },
	char_attack_bonus => sub { $char->{attack_bonus} },
	char_attack_magic_min => sub { $char->{attack_magic_min} },
	char_attack_magic_max => sub { $char->{attack_magic_max} },
	char_hit => sub { $char->{hit} },
	char_critical => sub { $char->{critical} },
	char_def => sub { $char->{def} },
	char_def_bonus => sub { $char->{def_bonus} },
	char_def_magic => sub { $char->{def_magic} },
	char_def_magic_bonus => sub { $char->{def_magic_bonus} },
	char_flee => sub { $char->{flee} },
	char_flee_bonus => sub { $char->{flee_bonus} },
	char_attack_speed => sub { $char->{attack_speed} },
	char_points_free => sub { $char->{points_free} },
	char_points_skill => sub { $char->{points_skill} },
	char_walk_speed => sub { sprintf '%.2f', 1 / $char->{walk_speed} },
	char_pos_x => sub { $char->{pos_to}{x} },
	char_pos_y => sub { $char->{pos_to}{y} },
	field_description => sub { $field->descString },
	field_image => sub { '/map/' . $field->name },
);

my %oldValues;

sub values {
	my ($self, @keys) = @_;
	@keys = keys %valueSources unless @keys;

	my %values = map { $_ => &{$valueSources{$_}} } @keys;
	%values = map { $_ => $values{$_} } grep { $values{$_} ne $oldValues{$_} } keys %values;
	$oldValues{$_} = $values{$_} for keys %values;
	return unless %values;

	$self->broadcast(encode_json({type => 'values', data => \%values}));
}

1;
