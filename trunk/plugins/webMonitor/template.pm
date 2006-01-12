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
	
	my @keys = keys %{$keywords};
	foreach my $key (@keys) {
		my $value = $keywords->{$key};
		if (ref($value) eq 'ARRAY') {
			push(@arrays, $key);

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
	
	foreach my $replace (@replacements) {
		my $text = $self->_expand($replace, \@arrays);
		$replacement =~ s/$replace/$text/g;
	}
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
	
	foreach my $key (@{$keys}) {
		foreach my $value (@{$keywords->{$key}}) {
			$replacement = $text;
			$replacement =~ s/\{startLoop\}//sg;
			$replacement =~ s/\{endLoop\}//sg;
			next if !($replacement =~ s/$markF$key$markB/$value/sg);
			$expanded .= $replacement;
		}
	}
	if ($expanded) {
		return $expanded;
	} else {
		return "none";
	}
}