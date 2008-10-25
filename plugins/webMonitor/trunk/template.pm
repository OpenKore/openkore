package template;

use strict;

my %fields = {
	template		=> '',
	markF			=> '',
	markB			=> '',
	keywords		=> '',
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
	$self->{keywords} = $keywords;
	$self->{markF} = quotemeta $markF;
	$self->{markB} = quotemeta $markB;
	$markF = $self->{markF};
	$markB = $self->{markB};
	my @arrays;
	
	$replacement =~ s/\?/\x08/sg;
	
	my @keys = keys %{$keywords};
	foreach my $key (@keys) {
		my $value = $keywords->{$key};
		pos($replacement) = 0;
		if (ref($value) eq 'ARRAY') {
			push(@arrays, $key) if ($replacement =~ m/$markF$key$markB/sg);
			
		} else {
			$replacement =~ s/$markF$key$markB/$value/sg;
		}
	}
	pos($replacement) = 0;
	my (@startOffsets, @endOffsets);
	my $startLoop = 'startLoop';
	my $endLoop = 'endLoop';
	while ($replacement =~ /$markF$startLoop$markB/g) {
		push @startOffsets, ((pos $replacement) - length '{startLoop}');
		$replacement =~ /$markF$endLoop$markB/g;
		push @endOffsets, (pos $replacement);
	}
	
	my @replacements;
	for (my $i; $i < @startOffsets; $i++) {
		push @replacements, substr $replacement, $startOffsets[$i], $endOffsets[$i]-$startOffsets[$i];
	}

	for (my $i; $i < @replacements; $i++) {
		my $replace = $replacements[$i];
		my $text = $self->_expand($replace, \@arrays);
		$replacement =~ s/$replace/$text/sg;
	}
	$replacement =~ s/\x08/\?/sg;
	return $replacement;
}
	
# $expanded = _expand($text, \@keys);
sub _expand {
	my ($self, $text, $keys) = @_;
	my $keywords = $self->{keywords};
	my $markF = $self->{markF};
	my $markB = $self->{markB};
	my $replacement;
	my $expanded;
	my $firstFound;
	
	for (my $i; $i < @{$keys}; $i++) {
		my $key = $keys->[$i];
		if (quotemeta $text =~ /$markF$key$markB/sg) {
			$firstFound = $key;
			last;
		}
	}
	my $array = $keywords->{$firstFound};
	my $i;
	foreach my $value (@{$array}) {
		$replacement = $text;
		$replacement =~ s/\{startLoop\}//sg;
		$replacement =~ s/\{endLoop\}//sg;
		next if !($replacement =~ s/$markF$firstFound$markB/$value/sg);
		foreach my $key (@{$keys}) {
			next if ($key eq $firstFound);
			$replacement =~ s/$markF$key$markB/$keywords->{$key}->[$i]/sg;
		}
		$expanded .= $replacement;
		$i++;
	}
	

	if ($expanded) {
		return $expanded;
	} else {
		foreach my $key (@{$keys}) {
			$text =~ s/\{startLoop\}//sg;
			$text =~ s/\{endLoop\}//sg;
			$text =~ s/$markF$key$markB/none/sg;;
		}
		return $text;
	}
}
