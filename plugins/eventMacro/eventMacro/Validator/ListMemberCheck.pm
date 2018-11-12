package eventMacro::Validator::ListMemberCheck;

use strict;
use base 'eventMacro::Validator';
use eventMacro::Data;
use eventMacro::Utilities qw(find_variable);

sub parse {
	my ( $self, $string_list ) = @_;
	
	$self->{list} = [];
	$self->{var_to_member_index} = {};
	
	my $has_member_any = 0;
	
	my @list_members = split(/\s*,\s*/, $string_list);
	
	foreach my $member (@list_members) {
		if (!$member) {
			$self->{error} = "A list member is undefined (empty)";
			$self->{parsed} = 0;
			return;
		} elsif (my $var = find_variable($member)) {
			if ($var =~ /^\./) {
				$self->{error} = "System variables should not be used in automacros (The ones starting with a dot '.')";
				$self->{parsed} = 0;
				return;
			}
			#During parsing all variables should be undefined
			push(@{$self->{var}}, $var) unless (exists $self->{var_to_member_index}{$var->{display_name}});
			push(@{$self->{list}}, undef);
			push(@{$self->{var_to_member_index}{$var->{display_name}}}, $#{$self->{list}});
		} else {
			push(@{$self->{list}}, $member);
			if ($member =~ /^any$/i) {
				$has_member_any = 1;
			}
		}
	}
	
	if ($has_member_any) {
		# If one list member is 'any' there's no sense in having more members, so return a error
		if (scalar(@list_members) > 1) {
			$self->{error} = "If 'any' is member of the list there should be no other list members";
			$self->{parsed} = 0;
		} else {
			$self->{list_is_any} = 1;
			$self->{parsed} = 1;
		}
	} else {
		$self->{list_is_any} = 0;
		$self->{parsed} = 1;
	}
}

sub update_vars {
	my ( $self, $var_name, $var_value ) = @_;
	foreach my $member_index (@{$self->{var_to_member_index}{$var_name}}) {
		@{$self->{list}}[$member_index] = $var_value;
	}
}

sub validate {
	my ( $self, $possible_member ) = @_;
	return 1 if ($self->{list_is_any});
	
	foreach my $list_member (@{$self->{list}}) {
		next unless (defined $list_member);
		return 1 if ($list_member eq $possible_member);
	}
	
	return 0;
}

sub validate_opposite {
	my ( $self, $possible_member ) = @_;
	return 0 if ($self->{list_is_any});
	
	foreach my $list_member (@{$self->{list}}) {
		next unless (defined $list_member);
		return 0 if ($list_member eq $possible_member);
	}
	
	return 1;
}

1;
