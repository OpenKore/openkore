package Utils::StringScanner;

use strict;
use warnings;

sub new {
	my ($class, $string) = @_;
	my %self = (str => $string);
	return bless \%self, $class;
}

sub scan {
	my ($self, $regex) = @_;
	if (ref($regex) ne 'Regexp') {
		$regex = quotemeta $regex;
	}
	if ($self->{str} =~ /^$regex/sx) {
		return substr($self->{str}, 0, $+[0], '');
	} else {
		return;
	}
}

sub scanUntil {
	my ($self, $regex) = @_;
	if (ref($regex) ne 'Regexp') {
		$regex = quotemeta $regex;
	}
	if ($self->{str} =~ /$regex/sx) {
		return substr($self->{str}, 0, $-[0], '');
	} else {
		return;
	}
}

sub peek {
	my ($self, $regex) = @_;
	if (ref($regex) ne 'Regexp') {
		$regex = quotemeta $regex;
	}
	if ($self->{str} =~ /^$regex/sx) {
		return substr($self->{str}, 0, $+[0]);
	} else {
		return;
	}
}

sub peekUntil {
	my ($self, $regex) = @_;
	if (ref($regex) ne 'Regexp') {
		$regex = quotemeta $regex;
	}
	if ($self->{str} =~ /$regex/sx) {
		return substr($self->{str}, 0, $-[0]);
	} else {
		return;
	}
}

sub skip {
	my ($self, $regex) = @_;
	if (ref($regex) ne 'Regexp') {
		$regex = quotemeta $regex;
	}
	if ($self->{str} =~ /^$regex/sx) {
		substr($self->{str}, 0, $+[0], '');
		return $+[0];
	} else {
		return;
	}
}

sub skipUntil {
	my ($self, $regex) = @_;
	if (ref($regex) ne 'Regexp') {
		$regex = quotemeta $regex;
	}
	if ($self->{str} =~ /$regex/sx) {
		substr($self->{str}, 0, $-[0], '');
		return $+[0];
	} else {
		return;
	}
}

sub rest {
	my ($self) = @_;
	return $self->{str};
}

sub terminate {
	$_[0]->{str} = '';
}

sub eos {
	my ($self) = @_;
	return length($self->{str}) == 0;
}

1;