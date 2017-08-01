package eventMacro::Lists;

use strict;
use Carp::Assert;
use Utils::ObjectList;
use base qw(ObjectList);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new();

	$self->{nameIndex} = {};

	return $self;
}

sub DESTROY {
	my ($self) = @_;
	$self->clear();
}

sub add {
	my ($self, $member) = @_;

	my $listIndex = $self->SUPER::add($member);
	$member->{listIndex} = $listIndex;

	my $indexSlot = $self->getNameIndexSlot($member->get_name());
	push @{$indexSlot}, $listIndex;

	return $listIndex;
}

sub getByName {
	my ($self, $name) = @_;
	my $indexSlot = $self->{nameIndex}{lc($name)};
	if ($indexSlot) {
		return $self->get($indexSlot->[0]);
	} else {
		return undef;
	}
}

sub remove {
	my ($self, $member) = @_;

	my $result = $self->SUPER::remove($member);
	if ($result) {
		my $indexSlot = $self->getNameIndexSlot($member->get_name());
		for (my $i = 0; $i < @{$indexSlot}; $i++) {
			if ($indexSlot->[$i] == $member->{listIndex}) {
				splice(@{$indexSlot}, $i, 1);
				last;
			}
		}
		if (@{$indexSlot} == 0) {
			delete $self->{nameIndex}{lc($member->get_name())};
		}
	}
	return $result;
}

sub removeByName {
	my ($self, $name) = @_;
	my $member = $self->getByName($name);
	if (defined $member) {
		return $self->remove($member);
	} else {
		return 0;
	}
}

# overloaded
sub doClear {
	my ($self) = @_;
	$self->SUPER::doClear();
	$self->{nameIndex} = {};
}

# overloaded
sub checkValidity {
	my ($self) = @_;
	$self->SUPER::checkValidity();
	foreach my $k (keys %{$self->{nameIndex}}) {
		should(lc($self->getByName($k)->get_name()), $k);
		should(lc $k, $k);
	}
}

sub getNameIndexSlot {
	my ($self, $name) = @_;
	return $self->{nameIndex}{lc($name)} ||= [];
}

1;
