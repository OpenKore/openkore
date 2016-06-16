#########################################################################
#  OpenKore - UTF-8 text reader
#
#  Copryight (c) 2006 OpenKore Development Team
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#########################################################################
##
# MODULE DESCRIPTION: UTF-8 text reader.
#
# A convenience class for reading text files encoded in UTF-8. If you're
# not familiar with UTF-8, Unicode or character encoding in general, then you
# should read <a href="http://www.joelonsoftware.com/articles/Unicode.html">this article
# by Joel on Software</a>.
#
# If the text file is not valid UTF-8, then it will assume that the text file
# is in the system's default encoding. If that isn't correct either, then an
# exception will be thrown during reading.
#
# This class is to be used as follows:
# <pre class="example">
# use Utils::TextReader;
#
# my $reader = new Utils::TextReader("file.txt");
# while (!$reader->eof()) {
#    print $reader->readLine();
# }
# </pre>
package Utils::TextReader;

use strict;
use Encode;
use Translation qw( T TF );
use Utils::Exceptions;

my $supportsAutoConversion;
eval {
	$supportsAutoConversion = 0;
	require Translation;
	require Encode;
	$supportsAutoConversion = defined(&Translation::getLocaleCharset);
};

##
# Utils::TextReader->new(String filename)
# Throws: FileNotFoundException, IOException
#
# Create a new TextReader and open the given file for reading.
sub new {
	my ($class, $file, $options) = @_;

	my $self = bless {}, $class;
	$self->{files} = [];
	$self->add( $file );
	$self->{process_includes} = defined $options->{process_includes} ? $options->{process_includes} : 1;
	$self->{hide_includes} = defined $options->{hide_includes} ? $options->{hide_includes} : 1;
	$self->{hide_comments} = defined $options->{hide_comments} ? $options->{hide_comments} : 1;

	$self;
}

sub DESTROY {
	close $_->{handle} foreach @{ $_[0]->{files} };
}

##
# void $TextReader->add($file)
# Throws: FileNotFoundException, IOException
#
# Add a file to the list of files to be processed. Files are processed in a LIFO manner.
sub add {
	my ( $self, $file, $options ) = @_;

	if ( @{ $self->{files} } ) {
		my ( $vol, $dir ) = File::Spec->splitpath( $self->{files}->[-1]->{file} );
		$file = File::Spec->catpath( $vol, $dir, $file );
	}

	if ( grep { $_->{file} eq $file } @{ $self->{files} } ) {
		IOException->throw( TF( 'File [%s] cannot include itself.', $file ) );
	}

	my $handle;
	if (! -e $file && $options->{create_if_missing}) {
		if (!open($handle, '>', $file)) {
			IOException->throw( TF( 'File [%s] cannot be created: $!', $file, $! ) );
		}
	} elsif (! -e $file) {
		FileNotFoundException->throw( TF( 'File [%s] does not exist.', $file ) );
	} elsif (!open($handle, "<", $file)) {
		IOException->throw(error => $!);
	}

	push @{ $self->{files} }, { file => $file, line => 0, handle => $handle };
}

sub currentFile {
	$_[0]->{files}->[-1]->{file};
}

##
# boolean $TextReader->eof()
#
# Check whether end-of-file has been reached.
sub eof {
	my $self = shift;
	pop @{ $self->{files} } while @{ $self->{files} } && eof $self->{files}->[-1]->{handle};
	!@{ $self->{files} };
}

##
# String $TextReader->readLine()
# Requires: !$TextReader->eof()
# Throws: UTF8MalformedException
#
# Read one line from the file, including a possible newline character.
# UTF-8 BOM characters are automatically stripped.
sub readLine {
	my $self = $_[0];

	return if $self->eof;

	# Attempt to read a line from the current file.
	my $handle = $self->{files}->[-1]->{handle};
	my $line = <$handle>;
	$self->{files}->[-1]->{line}++;

	# Validate UTF-8.
	{
		use bytes;
		if ($line !~ m/^(
		     [\x09\x0A\x0D\x20-\x7E]            # ASCII
		   | [\xC2-\xDF][\x80-\xBF]             # non-overlong 2-byte
		   |  \xE0[\xA0-\xBF][\x80-\xBF]        # excluding overlongs
		   | [\xE1-\xEC\xEE\xEF][\x80-\xBF]{2}  # straight 3-byte
		   |  \xED[\x80-\x9F][\x80-\xBF]        # excluding surrogates
		   |  \xF0[\x90-\xBF][\x80-\xBF]{2}     # planes 1-3
		   | [\xF1-\xF3][\x80-\xBF]{3}          # planes 4-15
		   |  \xF4[\x80-\x8F][\x80-\xBF]{2}     # plane 16
		  )*$/x) {
			if ($supportsAutoConversion) {
				eval {
					$line = Encode::decode(Translation::getLocaleCharset(),
						$line, Encode::FB_CROAK);
				};
			}
			if (!$supportsAutoConversion || $@) {
				UTF8MalformedException->throw(
					error => "Malformed UTF-8 data at line $self->{files}->[-1]->{line}.",
					textfileline => $self->{files}->[-1]->{line},
					textfile => $self->{files}->[-1]->{file},
				);
			}
		}
	}

	# Convert to string and remove UTF-8 BOM characters.
	Encode::_utf8_on($line);
	$line =~ s/\x{FEFF}//g;

	# Handle "!include".
	if ( $self->{process_includes} && $line =~ /^\s*!include\s+(.*?)\s*$/os ) {
		$self->add( "$1" );
		$line = $self->readLine if $self->{hide_includes};
	}
	if ( $self->{process_includes} && $line =~ /^\s*!include_create_if_missing\s+(.*?)\s*$/os ) {
		$self->add( "$1", { create_if_missing => 1 } );
		$line = $self->readLine if $self->{hide_includes};
	}

	# Hide comments and blank lines.
	if ( $self->{hide_comments} && $line =~ /^\s*(#|$)/os ) {
		$line = $self->readLine;
	}

	return $line;
}

1;
