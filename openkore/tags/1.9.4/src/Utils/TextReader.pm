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
use Utils::Exceptions;

##
# Utils::TextReader->new(String filename)
# Throws: FileNotFoundException, IOException
#
# Create a new TextReader and open the given file for reading.
sub new {
	my ($class, $file) = @_;
	my %self;

	if (! -e $file) {
		FileNotFoundException->throw("File does not exist.");
	} elsif (!open($self{handle}, "<", $file)) {
		IOException->throw(error => $!);
	}
	$self{line} = 1;

	return bless \%self, $class;
}

sub DESTROY {
	close($_[0]->{handle});
}

##
# boolean $TextReader->eof()
#
# Check whether end-of-file has been reached.
sub eof {
	return eof($_[0]->{handle});
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
	my $handle = $self->{handle};
	my $line = <$handle>;

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
			UTF8MalformedException->throw(
				error => "Malformed UTF-8 data at line $_[0]->{line}.",
				line => $self->{line}
			);
		}
	}

	# Convert to string and remove UTF-8 BOM characters.
	Encode::_utf8_on($line);
	$line =~ s/\x{FEFF}//g;

	$self->{line}++;
	return $line;
}

1;
