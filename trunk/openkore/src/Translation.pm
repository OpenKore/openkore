#########################################################################
#  OpenKore - Ragnarok Online Assistent
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#
#  $Revision$
#  $Id$
#
#########################################################################
##
# MODULE DESCRIPTION: Message translation framework
#
# This module provides functions for translating messages in the user's
# native language. Translations are stored in
# <a href="http://www.gnu.org/software/gettext/">GNU gettext</a> translation
# files (*.gmo).
package Translation;

use strict;
use Exporter;
use base qw(Exporter);
use FindBin qw($RealBin);
use XSTools;
XSTools::bootModule("Translation");

our @EXPORT = qw(T);

# Note: some of the functions in this module are implemented in
# src/auto/XSTools/translation/wrapper.xs

##
# Translation::load(filename)
# filename: the filename to a translation file.
# Returns: 1 if the translation file was successfully loaded, undef otherwise.
#
# Load a translation file (.gmo file). If the translation file cannot be
# loaded, then no translation file will be used, even if you successfully
# loaded a translation file before.

##
# Translation::unload()
#
# Unload the currently loaded translation file.

##
# Translation::autodetect()
# Returns: 1 if the translation file was successfully loaded, undef otherwise.
#
# Autodetect the operating system's language, and load the correct
# translation (.gmo) file. If the translation file cannot be
# loaded, then no translation file will be used, even if you successfully
# loaded a translation file before.
sub autodetect {
	if ($^O eq 'win32') {
		# ???
		unload();
		return undef;

	} else {
		require POSIX;
		my $locale = POSIX::setlocale('LC_MESSAGES', undef);
		# $locale is in a format like this: en_US.UTF-8
		# Remove everything after the dot and all slashes.
		$locale =~ s/\..*//;
		$locale =~ s/\///g;

		# Load the .gmo file.
		my $podir = "$RealBin/src/po";
		if (-f "$podir/$locale.gmo") {
			return load("$podir/$locale.gmo");
		}

		# That didn't work. Try removing the _US part.
		$locale =~ s/_.*//;
		if (-f "$podir/$locale.gmo") {
			return load("$podir/$locale.gmo");
		}

		# Give up.
		unload();
		return undef;
	}
}

##
# Translation::T(message)
# Returns: the translated message, or the original message if it cannot be translated.
#
# Translate $message using the currently loaded translation file.
#
# This symbol is automatically exported.
#
# Example:
# use Translation;
# Translation::autodetect();
# print(T("hello world\n"));
sub T {
	my ($message) = @_;
	_translate(\$message);
	return $message;
}

1;
