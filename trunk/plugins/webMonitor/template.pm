package template;

use strict;

my %fields = {
	template		=> '',
	markF			=> '',
	markB			=> '',
	debug			=> 0,
};

# $template = new template ("filename");
sub new {
	my ($that, $template) = @_;
	my $class = ref($that) || $that;
	my $self = {
		_permitted => \%fields,
		%fields,
	};
	
	bless $self, $class;
	$self->_initialize($template);
	return $self;
}

sub _initialize {
	my ($self, $template) = @_;

	$self->_loadTemplate($template);
}

sub _loadTemplate {
	my ($self, $filename) = @_;

	if (open (TEMPLATE, "<" . $filename)) {
		binmode TEMPLATE;
		while (read TEMPLATE, my $buffer, 1024) {
			$self->{template} .= $buffer;
		}
		close FILE;
	}
}

# $replacement = $template->replace(\%keywords, $markF, $markB);
sub replace {
	my ($self, $keywords, $markF, $markB) = @_;
	my $replacement = $self->{template};
	$self->{markF} = quotemeta $markF;
	$self->{markB} = quotemeta $markB;
	$markF = $self->{markF};
	$markB = $self->{markB};
	my @arrays;
	
	my @keys = keys %{$keywords};
	foreach my $key (@keys) {
		my $value = $keywords->{$key};
		if (ref($value) eq 'ARRAY') {
			push(@arrays, $key);
			# kludge until proper looping is written
			my $array;
			foreach my $val (@{$value}) {
				$array .= $val . '/ ';
			}
			if ($array) {
				$replacement =~ s/$markF$key$markB/$array/sg;
			} else {
				$array = 'none';
				$replacement =~ s/$markF$key$markB/$array/sg;
			} # end kludge

		} else {			
			$replacement =~ s/$markF$key$markB/$value/sg;
		}
	}
	
	#print $self->_expand('$characterStatuses$<br>', \@arrays, $keywords) . "\n";
	
	return $replacement;
}
	
# $expanded = _expand($text, \@keys, \%keywords);
sub _expand {
	my ($self, $text, $keys, $keywords) = @_;
	my $markF = $self->{markF};
	my $markB = $self->{markB};
	my $replacement;
	my $expanded;
	
	foreach my $key (@{$keys}) {
		foreach my $value (@{$keywords->{$key}}) {
			$replacement = $text;
			$replacement =~ s/$markF$key$markB/$value/sg;
			$expanded .= $replacement;
		}
	}
	return $expanded;
}