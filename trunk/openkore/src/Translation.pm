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
# files (*.mo).
#
# <b>Note:</b> translation files MUST be encoded in UTF-8 (without BOM).
package Translation;

use strict;
use Exporter;
use base qw(Exporter);
use FindBin qw($RealBin);
use Encode;
use Encode::Alias;
use XSTools;
use Globals qw(%config);

XSTools::bootModule("Translation");
define_alias('Western'  => 'ISO-8859-1');
define_alias('Tagalog'  => 'ISO-8859-1');
define_alias('Chinese'  => 'GB18030');
define_alias('Korean'   => 'EUC-KR');
define_alias('Russian'  => 'ISO-8859-5');
define_alias('Cyrillic' => 'ISO-8859-5');
define_alias('Japanese' => 'Shift_JIS');

our @EXPORT = qw(T);
our @EXPORT_OK = qw(serverStrToUTF8);


# Note: some of the functions in this module are implemented in
# src/auto/XSTools/translation/wrapper.xs

##
# Translation::load(filename)
# filename: the filename to a translation file.
# Returns: 1 if the translation file was successfully loaded, undef otherwise.
#
# Load a translation file (.mo file). If the translation file cannot be
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
# translation (.mo) file. If the translation file cannot be
# loaded, then no translation file will be used, even if you successfully
# loaded a translation file before.
sub autodetect {
	if ($^O eq 'MSWin32') {
		# ???
		unload();
		return undef;

	} else {
		my $locale;

		sub empty { return !defined($_[0]) || length($_[0]) == 0; }

		if (!empty($ENV{LC_ALL})) {
			$locale = $ENV{LC_ALL};
		} elsif (!empty($ENV{LC_MESSAGES})) {
			$locale = $ENV{LC_MESSAGES};
		} elsif (!empty($ENV{LANG})) {
			$locale = $ENV{LANG};
		} else {
			unload();
			return undef;
		}

		# $locale is in a format like this: en_US.UTF-8
		# Remove everything after the dot and all slashes.

		$locale =~ s/\..*//;
		$locale =~ s/\///g;

		# Load the .mo file.
		my $podir = "$RealBin/src/po";
		if (-f "$podir/$locale.mo") {
			return load("$podir/$locale.mo");
		}

		# That didn't work. Try removing the _US part.
		$locale =~ s/_.*//;
		if (-f "$podir/$locale.mo") {
			return load("$podir/$locale.mo");
		}

		# Give up.
		unload();
		return undef;
	}
}

##
# Translation::T(message)
# message: The message to translate.
# Returns: the translated message, or the original message if it cannot be translated.
# Requires: $message is encoded in UTF-8.
# Ensures: the return value is encoded in UTF-8.
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

##
# Translation::serverStrToUTF8(str)
# str: the string to convert.
# Returns: the return value, encoded in UTF-8.
#
# Convert a human-readable string, sent by the RO server, into UTF-8.
# This function uses $config{serverEncoding} to determine the encoding.
#
# This function should only be used for strings sent by the RO server.
sub serverStrToUTF8 {
	my ($str) = @_;
	Encode::from_to($str, $config{serverEncoding}, "utf8");
	return $str;
}

1;
