package eventMacro::Condition::NoPortalNear;

use strict;
use Globals qw( $portalsList );
use base 'eventMacro::Condition::Base::NoActorNear';

use Globals;

sub _hooks {
	my ( $self ) = @_;
	my $hooks = $self->SUPER::_hooks;
	my @other_hooks = ('add_portal_list','portal_disappeared');
	push(@{$hooks}, @other_hooks);
	return $hooks;
}

sub get_size {
	my ( $self ) = @_;
	return ($portalsList->size + $self->{change});
}

sub validate_condition {
	my ( $self, $callback_type, $callback_name, $args ) = @_;
	if ($callback_type eq 'hook' && $callback_name eq 'portal_disappeared') {
		$self->{change} = -1;
	} else {
		$self->{change} = 0;
	}
	return $self->SUPER::validate_condition( $callback_type, $callback_name, $args );
}

1;
