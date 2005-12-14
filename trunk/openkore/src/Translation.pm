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
define_alias('Chinese'  => 'EUC-CN');
define_alias('Korean'   => 'EUC-KR');
define_alias('Russian'  => 'ISO-8859-5');
define_alias('Cyrillic' => 'ISO-8859-5');
define_alias('Japanese' => 'Shift_JIS');
define_alias('Thai'     => 'ISO-8859-11');

our @EXPORT = qw(T TF);
our @EXPORT_OK = qw(serverStrToUTF8);
our $_translation;

use constant DEFAULT_PODIR => "$RealBin/src/po";


# Note: some of the functions in this module are implemented in
# src/auto/XSTools/translation/wrapper.xs

##
# Translation::initDefault([podir])
# Ensures: Translation::T() and Translation::TF() will be usable.
#
# Initialize the default translation object. Translation::T() and
# Translation::TF() will only be usable after calling this function once.
sub initDefault {
	my ($podir) = @_;
	$podir = DEFAULT_PODIR if (!defined $podir);
	$_translation = _load(_autodetect($podir));
}

##
# Translation->new([podir])
# podir: the directory which contains translation files.
# Returns: a Translation object.
# Ensures: defined(result)
#
# Create a new Translation object. The operating system's locale will
# be automatically detected, and a suitable language file will be loaded
# from $podir. If $podir is not specified, it will default to OpenKore's
# own translation files folder.
#
# You're probably looking for Translation::T() instead. See
# $translation->translate() for rationale.
sub new {
	my ($class, $podir) = @_;
	my %self;

	$podir = DEFAULT_PODIR if (!defined $podir);
	$self{pofile} = _autodetect($podir);
	$self{trans} = _load($self{pofile});

	bless \%self, $class;
	return \%self;
}

sub DESTROY {
	my ($self) = @_;
	_unload($self->{trans});
}

# _autodetect(podir)
#
# Autodetect the operating system's language, and return the filename for
# the suitable translation file (.mo) from $podir. Returns undef if
# there is no suitable translation file.
sub _autodetect {
	my ($podir) = @_;
	my $locale;

	sub empty { return !defined($_[0]) || length($_[0]) == 0; }
	if (!empty($ENV{LC_ALL})) {
		$locale = $ENV{LC_ALL};
	} elsif (!empty($ENV{LC_MESSAGES})) {
		$locale = $ENV{LC_MESSAGES};
	} elsif (!empty($ENV{LANG})) {
		$locale = $ENV{LANG};
	}

	if (!defined($locale) && $^O eq 'MSWin32') {
		require WinUtils;
		$locale = WinUtils::getLanguageName();
		return undef if ($locale eq 'C');
	}

	return undef if (!defined $locale);

	# $locale is in a format like this: en_US.UTF-8
	# Remove everything after the dot and all slashes.

	$locale =~ s/\..*//;
	$locale =~ s/\///g;
	# Load the .mo file.
	return "$podir/$locale.mo" if (-f "$podir/$locale.mo");

	# That didn't work. Try removing the _US part.
	$locale =~ s/_.*//;
	return "$podir/$locale.mo" if (-f "$podir/$locale.mo");

	# Give up.
	return undef;
}

##
# $translation->translate(message)
# message: The message to translate.
# Returns: the translated message, or the original message if it cannot be translated.
# Requires: $message is encoded in UTF-8.
# Ensures: the return value is encoded in UTF-8.
#
# Translate $message using the translation file defined by this class.
#
# This function is meant for plugin developers, who have their translation files
# stored in a different folder than OpenKore's. If you want to translate strings
# in OpenKore, then you should use Translation::T() instead.
#
# Example:
# my $t = new Translation;
# print($t->translate("hello world\n"));
sub translate {
	my ($self, $message) = @_;
	_translate($self->{trans}, \$message);
	return $message;
}

##
# Translation::T(message)
# message: The message to translate.
# Returns: the translated message, or the original message if it cannot be translated.
# Requires: Translation::initDefault() must have been called once; $message must be encoded in UTF-8.
# Ensures: the return value is encoded in UTF-8.
#
# Translate $message.
#
# This symbol is automatically exported.
#
# See also: $translation->translate() and Translation::TF()
#
# Example:
# use Translation;
# Translation::initDefault();
# print(T("hello world\n"));
sub T {
	my ($message) = @_;
	_translate($_translation, \$message);
	return $message;
}

##
# Translation::TF(format, ...)
# Requires: Translation::initDefault() must have been called once; $format must be encoded in UTF-8.
# Ensures: the return value is encoded in UTF-8.
#
# Translate $format, and perform sprintf() formatting using the specified parameters.
# This function is just a convenient way to write:<br>
# <code>sprintf(T($format), ...);</code>
#
# This symbol is automatically exported.
#
# Example:
# print(TF("Go to %s for more information", $url));
sub TF {
	my $message = shift;
	_translate($_translation, \$message);
	return sprintf($message, $_[0], $_[1], $_[2], $_[3], $_[4]);
}

##
# Translation::serverStrToUTF8(str)
# str: the string to convert.
# Returns: the return value, encoded in UTF-8.
# Requires: $config{serverEncoding} must be a correct encoding name.
#
# Convert a human-readable string (sent by the RO server) into UTF-8.
# This function uses $config{serverEncoding} to determine the encoding.
#
# This function should only be used for strings sent by the RO server.
sub serverStrToUTF8 {
	my ($str) = @_;
	Encode::from_to($str, $config{serverEncoding} || 'Western', "utf8");
	return $str;
}

1;
