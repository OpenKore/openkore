package eventMacro::Validator::ListMemberCheck;

use strict;
use base 'eventMacro::Validator';
use eventMacro::Data;

#should be used only for event_only conditions 

sub parse {
	my ( $self, $str ) = @_;
	
	$self->{list} = [];
	
	foreach my $member (split(/\s*,\s*/, $str)) {
		push(@{$self->{list}}, lc($member));
	}
}

sub validate {
	my ( $self, $possible_member ) = @_;

	foreach (@{$self->{list}}) {
		return 1 if ($_ eq $possible_member || $_ eq 'any');
	}
	
	
	
	return 0;
}

1;
