package eventMacro::FileParser;

use strict;

require Exporter;
our @ISA        = qw(Exporter);
our @EXPORT     = qw(parseMacroFile isNewCommandBlock);
our @EKSPORT_OK = qw(isNewCommandBlock);

use Globals;
use Utils qw/existsInList/;
use Utils::Exceptions;
use List::Util     qw(max min sum);
use Log            qw(message error warning debug);
use Text::Balanced qw/extract_bracketed/;
use Translation    qw( T TF );

use eventMacro::Core;
use eventMacro::Data;
use eventMacro::Lists;
use eventMacro::Automacro;
use eventMacro::FileParser;
use eventMacro::Macro;

my %macro;
my %automacro;

sub parseMacroFile {
	my ( $file, $recursive ) = @_;
	unless ( $recursive ) {
		undef %macro;
		undef %automacro;
		undef @perl_name;
	}

	my %block;
	my $inBlock             = 0;
	my $macroCountOpenBlock = 0;
	my ( $macro_subs, @perl_lines );
	my $reader = Utils::TextReader->new( $file, { debug => 1 } );
	while ( $_ = $reader->readLine ) {
		s/\s+#.*$//os;       # remove last comments
		s/^\s+|\s+$//gos;    # trim leading and trailing whitespace
		s/  +/ /g;           # trim down spaces - very cool for user's string data?
		next unless ( $_ );
		if ( !%block && /{$/ ) {
			my ( $key, $value ) = $_ =~ /^(.*?)\s+(.*?)\s*{$/;
			if ( $key eq 'macro' ) {
				%block = ( name => $value, type => "macro" );
				if ( exists $macro{$value} ) {
					$macro{$value}{'duplicatedMacro'} = 1;
				} else {
					$macro{$value} = {};
				}
			} elsif ( $key eq 'automacro' ) {
				if ( exists $automacro{$value} ) {

					#this is to detect automacros that have same name
					$automacro{$value}{'duplicatedAutomacro'} = 1;
				}
				%block = ( name => $value, type => "automacro" );
			} elsif ( $key eq 'sub' ) {
				%block = ( name => $value, type => "sub" );
			} else {
				%block = ( type => "bogus" );
				error "$file: ignoring line '$_' in line $. (munch, munch, strange block)\n";
			}
			next;

		} elsif ( %block && $block{type} eq "bogus" ) {
			if ( $_ eq "}" ) { undef %block }
			next;

		} elsif ( %block && $block{type} eq "macro" ) {
			if ( $_ eq "}" ) {
				if ( $macroCountOpenBlock ) {
					push( @{ $macro{ $block{name} }{lines} }, '}' );
					$macroCountOpenBlock--;
				} else {
					undef %block;
				}
			} else {
				if ( isNewCommandBlock( $_ ) ) {
					$macroCountOpenBlock++;
				} elsif ( !$macroCountOpenBlock && isNewWrongCommandBlock( $_ ) ) {
					error "$file: ignoring '$_' in line $. (munch, munch, not found the open block command)\n";
					next;
				}
				push( @{ $macro{ $block{name} }{lines} }, $_ );
			}

			next;

		} elsif ( %block && $block{type} eq "automacro" ) {
			if ( $_ eq "}" ) {
				if ( $block{loadmacro} ) {
					if ( $macroCountOpenBlock ) {
						push( @{ $macro{ $block{loadmacro_name} }{lines} }, '}' );

						if ( $macroCountOpenBlock ) {
							$macroCountOpenBlock--;
						}
					} else {
						undef $block{loadmacro};
					}
				} else {
					undef %block;
				}

			} elsif ( /call [^{]/ && !$macro{ $block{loadmacro_name} } ) {
				my ( $key, $value, $param ) = $_ =~ /^(call)\s+(\S+)(?:\s*(.*))?/;
				if ( !defined $key || !defined $value ) {
					error "$file: ignoring '$_' in line $. (munch, munch, not a pair)\n";
					next;
				}

				#check if macro is being called with params or not
				if ( defined $param ) {
					$value = join( ' ', $value, $param );
				}
				push( @{ $automacro{ $block{name} }{parameters} }, { key => 'call', value => $value } );
			} elsif ( $_ eq "call {" ) {
				$block{loadmacro}      = 1;
				$block{loadmacro_name} = "automacro_" . $block{name} . "_call_block";
				push( @{ $automacro{ $block{name} }{parameters} }, { key => 'call', value => $block{loadmacro_name} } );
				$macro{ $block{loadmacro_name} } = {};
			} elsif ( $block{loadmacro} ) {
				if ( isNewCommandBlock( $_ ) ) {
					$macroCountOpenBlock++;
				} elsif ( !$macroCountOpenBlock && isNewWrongCommandBlock( $_ ) ) {
					error "$file: ignoring '$_' in line $. (munch, munch, not found the open block command)\n";
					next;
				}

				push( @{ $macro{ $block{loadmacro_name} }{lines} }, $_ );
			} else {
				my ( $key, $value ) = $_ =~ /^(.*?)\s+(.*)/;
				my $blockName = $block{name};

				if ( defined $value && $value =~ /\{\s*$/ ) {
					my $block = $value . "\n";
					my $depth = 1;

					while ( defined( my $line = $reader->readLine ) ) {
						my $in_str   = 0;
						my $str_char = '';
						my $escaped  = 0;

						my $line_depth = $depth;

						for ( my $i = 0 ; $i < length( $line ) ; $i++ ) {
							my $c = substr( $line, $i, 1 );

							if ( $in_str ) {
								if ( $c eq '\\' ) {
									$escaped = !$escaped;
								} elsif ( $c eq $str_char && !$escaped ) {
									$in_str   = 0;
									$str_char = '';
								} else {
									$escaped = 0;
								}
							} else {
								if ( $c eq '"' || $c eq "'" ) {
									$in_str   = 1;
									$str_char = $c;
								} elsif ( $c eq '#' && !$in_str ) {
									last;    # comentário
								} elsif ( substr( $line, $i, 2 ) eq 'q{' ) {
									$line_depth++;
									$i++;    # pula o {
								} elsif ( $c eq '{' ) {
									$line_depth++;
								} elsif ( $c eq '}' ) {
									$line_depth--;
								}
							}
						}

						$depth = $line_depth;

						# If depth is zero, do not include this last line (it contained the closing brace)
						last if $depth == 0;

						$block .= "$line\n";
					}

					if ( $depth != 0 ) {
						error "[$file] [$blockName] [$key]: unterminated or misbalanced block at line $.";
						next;
					}

					$value = $block . "}";
				}

				if ( !defined $key || !defined $value ) {
					error "$file: ignoring '$_' in line $. (munch, munch, not a pair)\n";
					next;
				}
				if ( exists $parameters{$key} ) {
					push( @{ $automacro{ $block{name} }{parameters} }, { key => $key, value => $value } );
				} else {
					push( @{ $automacro{ $block{name} }{conditions} }, { key => $key, value => $value } );
				}
			}

			next;

		} elsif ( %block && $block{type} eq "sub" ) {
			if ( $_ eq "}" ) {
				if ( $inBlock > 0 ) {
					push( @perl_lines, $_ );
					$inBlock--;
					next;
				}
				$macro_subs = join( '', @perl_lines );
				sub_execute( $block{name}, $macro_subs );
				push( @perl_name, $block{name} ) unless existsInList( join( ',', @perl_name ), $block{name} );
				undef %block;
				undef @perl_lines;
				undef $macro_subs;
				$inBlock = 0;
			} elsif ( $_ =~ /^}.*?{$/ && $inBlock > 0 ) {
				push( @perl_lines, $_ );
			} elsif ( $_ =~ /{$/ ) {
				$inBlock++;
				push( @perl_lines, $_ );
			} elsif ( $_ =~ /^}.*/ && $inBlock > 0 ) {
				$inBlock--;
				push( @perl_lines, $_ );
			} else {
				push( @perl_lines, $_ );
			}
			next;

		}

		my ( $key, $value ) = $_ =~ /(?:^(.*?)\s|})+(.*)/;
		unless ( defined $key ) {
			error "$file: ignoring '$_' in line $. (munch, munch, strange food)\n";
			next;
		}
	}

	if ( %block ) {
		error TF( "%s: unclosed %s block '%s'\n", $file, $block{type}, $block{name} );
		return 0;
	}
	return { macros => \%macro, automacros => \%automacro, subs => \@perl_name };
}

sub sub_execute {
	return if $Settings::lockdown;

	my ( $name, $arg ) = @_;
	my $run = "sub " . $name . " {" . $arg . "}";
	eval( $run );    # cycle the macro sub between macros only
	$run = "eval " . $run;

	# exporting sub to the &main::sub, becarefull on your sub name
	# dont name your new sub equal to any &main::sub, you should take
	# the risk yourself.
	Commands::run( $run );

	message "[eventMacro] registering sub '" . $name . "'.\n", "menu";
}

# check if on the line there commands that open new command blocks
sub isNewCommandBlock {
	my ( $line ) = @_;

	if ( $line =~ /^if.*{$/ || $line =~ /^case.*{$/ || $line =~ /^switch.*{$/ || $line =~ /^else.*{$/ || $line =~ /^while.*{$/ ) {
		return 1;
	} else {
		return 0;
	}
}

sub isNewWrongCommandBlock {
	my ( $line ) = @_;

	if ( $_ =~ /^}\s*else\s*{$/ || $_ =~ /}\s*elsif.*{$/ || $_ =~ /^case.*{$/ || $_ =~ /^else*{$/ ) {
		return 1;
	} else {
		return 0;
	}
}

1;
