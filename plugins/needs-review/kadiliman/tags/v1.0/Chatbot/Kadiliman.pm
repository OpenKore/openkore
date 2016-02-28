# Inspired by perlBorg, pyBorg, and seeBorg
# Licensed under the GPL
# Copyright by kaliwanagan

package Chatbot::Kadiliman;

use strict;

use vars qw($VERSION @ISA $AUTOLOAD) ;

$VERSION = '0.06';
sub Version { $VERSION; }

my %fields;

%fields = {
	name			=> 'Kadiliman',
	scriptfile		=> '',
	depth			=> 3,
	learn			=> 0,
	reply			=> 1,

	debug			=> 0,
	debug_text		=> '',
	quit			=> undef
};

sub new {
	my ($that, $name, $scriptfile) = @_;
	my $class = ref($that) || $that;
	my $self = {
		_permitted => \%fields,
		%fields,
	};
	
	bless $self, $class;
	$self->_initialize($name, $scriptfile);
	return $self;
}

sub _initialize {
	my ($self, $name, $scriptfile) = @_;
	
	if (defined $name and ref $name eq "HASH") {

		# Allow the calling program to pass in intial parameters
		# as an anonymous hash
		map { $self->{$_} = $name->{$_}; } keys %$name;

		$self->parseScriptData( $self->{scriptfile} );

	} else {
		$self->{name} = $name if $name;
		$self->parseScriptData($scriptfile);
	} 
}

sub parseScriptData {
	my ($self, $scriptfile) = @_;

	$self->debug("Parsing $scriptfile... ");
	my @scriptlines;
	if ($scriptfile) {
		# If we have an external script file, open it 
		# and read it in (the whole thing, all at once). 
		if (open (SCRIPTFILE, "<$scriptfile")) {
			@scriptlines = <SCRIPTFILE>; # read in script data 
			$self->{scriptfile} = $scriptfile;
			close (SCRIPTFILE);
		} else {
			print "Could not read from file $scriptfile : $!\n";
			print "Creating default lines.txt ...\n";
			$self->{scriptfile} = "lines.txt";
		}
		$self->debug("done\n");
	}
	$self->debug("Learning $scriptfile... ");
	foreach my $line (@scriptlines) {
		my @sentences = split /\.+/, $line;
		foreach my $sentence (@sentences) {
			$self->learn($sentence);
		}
	}
	$self->debug("done\n");
	$self->debug("I know ". scalar @{$self->{lines}} . " lines.\n") if (exists $self->{lines});
	$self->{parsed} = 1;
}

sub saveScriptData {
	my ($self) = @_;
	
	$self->debug("Saving script data... ");
	my $scriptfile = $self->{scriptfile};
	open (SCRIPTFILE, ">$scriptfile");
	foreach my $line (@{$self->{lines}}) {
		print SCRIPTFILE ("$line\n");
	}
	close (SCRIPTFILE);
	$self->debug("done.\n");
}

sub learn {
	my ($self, $string) = @_;
	my $numLines = (exists $self->{lines}) ? @{$self->{lines}} : '0';

	$string = $self->preProcess($string);
	my $tmp = $string;
	
	$tmp = lc $tmp; # convert to lowercase
	$tmp =~ s/[^A-Za-z_0-9 \']/ /g; # remove non alpha-numeric characters
	my @words = split /\s+/, $tmp;
	for (my $i = 0; $i < scalar @words; $i++) {
		$self->{count}{$words[$i]}++;
		$self->{after}{$words[$i]}{$words[$i+1]}++ if ($words[$i+1]);
		push @{$self->{linenum}{$words[$i]}}, $numLines;
	}
	push @{$self->{lines}}, $string if ($string);
	if ($self->{parsed}) {
		$self->debug("Learning: $string\n");
	}
}

sub preProcess {
	my ($self, $string) = @_;
	$string =~ s/\n//g; # remove newlines
	$string =~ s/\r//g; # remove cariage returns;
	$string =~ s/^_*//; #remove leading underscores
	$string =~ s/_*$//; #remove trailing underscores
	$string =~ s/^\s*//; #remove leading spaces
	$string =~ s/\s*$//; #remove trailing spaces
	
	return $string;
}

sub postProcess {
	my ($self, $string) = @_;
}

sub transform {
	my ($self, $inputString) = @_;
	my $reply;
	my $input = $self->preProcess($inputString);
	
	# Filter out all the words we haven't learned yet
	my @leftWords;
	$input = lc $input; # convert to lowercase
	$input =~ s/[^A-Za-z_0-9 \']/ /g; # remove non alpha-numeric characters
	my @words = split /\s+/, $input;
	foreach my $word (@words) {
		$self->debug("$word: $self->{count}{$word}\n");
		next if (!exists ($self->{count}{$word}));
		push @leftWords, $word;
	}
	undef @words;

	# Choose a word from the list of known words
	my $leftWord = $leftWords[int rand(@leftWords)];
	$self->debug("Chosen left word: $leftWord\n");
	undef @leftWords;
	
	if (!$leftWord) { # if all words are unknown
		$reply = $self->{lines}[int rand(@{$self->{lines}})];
	} else {

		my @rightWords = keys %{$self->{after}{$leftWord}};
		my $rightWord = $rightWords[int rand(@rightWords)];
		$self->debug("Chosen right word: $rightWord\n");
		undef @rightWords;

		my @leftLines;
		my @rightLines;
		my $string;
			
		# Cull from script data all lines containing the left word
		foreach my $linenum (@{$self->{linenum}{$leftWord}}) {
			push @leftLines, $self->{lines}[$linenum];
		}

		$self->debug("leftLines: " . scalar @leftLines . "\n");
		
		# Cull from script data all lines containing the right word
		foreach my $linenum (@{$self->{linenum}{$rightWord}}) {
			push @rightLines, $self->{lines}[$linenum];
		}
		
		$self->debug("rightLines: " . scalar @rightLines . "\n");

		my $rand;
		
		# Get a random line from those that contain the left word
		$rand = int rand(@leftLines);
		$string = $leftLines[$rand];
		
		# Build the left side
		my $leftSide;
	
		my @words = split /\s+/, $string;
		foreach my $word (@words) {
			$leftSide = $leftSide . $word . ' ';
			last if $word =~ /\b$leftWord\b/;
		}
		undef @words;
		$self->debug("Leftside: $leftSide line: $rand\n");

		# Get a random line from those that contain the right word
		$rand = int rand(@rightLines);
		$string = $rightLines[$rand];

		# Build the right side
		my $rightSide;

		my @words = split /\s+/, $string;
		foreach my $word (@words) {
			last if $word =~ /\b$rightWord\b/;
			$word = '';
		}
		foreach my $word (@words) {
			$rightSide .= $word ? $word . ' ' : '';
		}
		undef @words;
		$self->debug("Rightside: $rightSide line: $rand\n");

		# Build the reply
		$reply = $leftSide . $rightSide;
	}
	$self->learn($inputString) if ($self->{learn});
	$self->saveScriptData if ($self->{learn});
	return $reply;
}

sub _testquit {
	my ($self, $string) = @_;
	return 1 if ($string =~ /\bquit\b/i);
}

sub command_interface {
	my $self = shift;
	my $userInput;
	while (1) {
		chomp($userInput = <STDIN>);
		if($self->_testquit($userInput)) { 
			last;
		}
		print "Reply: ".$self->transform($userInput)."\n";
	}
}

sub debug {
	my ($self, $string) = @_;
	print "debug -> $string" if ($self->{debug});
}

return 1;

=head1 CHANGES

=over 4

= item * Version 0.06 (21 July 2005)

fix for regexp dying on unescaped characters (thanks Joseph)

= item * Version 0.05 (18 July 2005)

changed from a simple word selection into word + wordafter selection

= item * Version 0.04 (17 July 2005)

First release

= item * Version 0.03 (17 July 2005)

complete learn and transform functions
changed from rare word to random word selection

= item * Version 0.02 (15 July 2005)

preProcess function
learn function (partial)
transform function (partial)

= item * Version 0.01 (8 July 2005)

Created skeleton code

=back

=cut