package template;

use strict;

my %fields = {
	template		=> '',
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
	
	my @keys = keys %{$keywords};
	foreach my $key (@keys) {
		my $value = $keywords->{$key};
		if (ref($value) eq 'ARRAY') {
			my $array;

			# kludge until proper looping is written
			foreach my $val (@{$value}) {
				$array .= $val . ' ';
			}
			if ($array) {
				$replacement =~ s/$markF$key$markB/$array/sg;
			} else {
				$array = 'none';
				$replacement =~ s/$markF$key$markB/$array/sg;
			}

		} else {			
			$replacement =~ s/$markF$key$markB/$value/sg;
		}
	}
	
	return $replacement;
}
	
	
	
	
	
