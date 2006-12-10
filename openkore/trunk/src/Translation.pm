#########################################################################
#  OpenKore - Ragnarok Online Assistent
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#########################################################################
##
# MODULE DESCRIPTION: Message translation framework
#
# This module provides functions for translating messages in the user's
# native language. Translations are stored in
# <a href="http://www.gnu.org/software/gettext/">GNU gettext</a> translation
# files (*.mo).
#
# <b>Notes:</b>
# `l
# - Translation files MUST be encoded in UTF-8 (without BOM).
# - We use short locale names, as defined by http://www.loc.gov/standards/iso639-2/englangn.html
# `l`
package Translation;

use strict;
use Exporter;
use base qw(Exporter);
use FindBin qw($RealBin);
use XSTools;
use I18N;
use encoding 'utf8';

XSTools::bootModule("Translation");


our @EXPORT = qw(T TF);
our $_translation;

use constant DEFAULT_PODIR => "$RealBin/src/po";


# Note: some of the functions in this module are implemented in
# src/auto/XSTools/translation/wrapper.xs

##
# void Translation::initDefault([String podir, String locale])
# Ensures: Translation::T() and Translation::TF() will be usable.
#
# Initialize the default translation object. Translation::T() and
# Translation::TF() will only be usable after calling this function once.
sub initDefault {
	my ($podir, $locale) = @_;
	$podir = DEFAULT_PODIR if (!defined $podir);
	$_translation = _load(_autodetect($podir, $locale));
}

##
# Translation Translation->new([String podir, String locale])
# podir: the directory which contains translation files.
# locale: the name of a locale.
# Returns: a Translation object.
#
# Create a new Translation object. A suitable language file will be loaded
# from $podir. If $locale is not defined, then the operating system's locale
# will be automatically detected. If $podir is not specified, it will default
# to OpenKore's own translation files folder.
#
# You're probably looking for Translation::T() instead. See
# $Translation->translate() for rationale.
sub new {
	my ($class, $podir, $locale) = @_;
	my %self;

	$podir = DEFAULT_PODIR if (!defined $podir);
	$self{pofile} = _autodetect($podir, $locale);
	$self{trans} = _load($self{pofile});

	bless \%self, $class;
	return \%self;
}

sub DESTROY {
	my ($self) = @_;
	_unload($self->{trans});
}

# _autodetect(String podir, [String requested_locale])
#
# Autodetect the operating system's language, and return the filename for
# the suitable translation file (.mo) from $podir. Returns undef if
# there is no suitable translation file.
sub _autodetect {
	my ($podir, $requested_locale) = @_;
	my $locale;

	if ($requested_locale eq '') {
		sub empty { return !defined($_[0]) || length($_[0]) == 0; }
		if (!empty($ENV{LC_ALL})) {
			$locale = $ENV{LC_ALL};
		} elsif (!empty($ENV{LC_MESSAGES})) {
			$locale = $ENV{LC_MESSAGES};
		} elsif (!empty($ENV{LANG})) {
			$locale = $ENV{LANG};
		}

		if (!defined($locale) && $^O eq 'MSWin32') {
			require Utils::Win32;
			$locale = Utils::Win32::getLanguageName();
			return undef if ($locale eq 'C');
		}
		return undef if (!defined $locale);

	} else {
		$locale = $requested_locale;
	}

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
# String $Translation->translate(String message)
# message: The message to translate.
# Returns: the translated message, or the original message if it cannot be translated.
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
# String Translation::T(String message)
# message: The message to translate.
# Returns: the translated message, or the original message if it cannot be translated.
# Requires: Translation::initDefault() must have been called once.
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
# String Translation::TF(String format, ...)
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
	return sprintf($message, @_);
	#return sprintf($message, $_[0], $_[1], $_[2], $_[3], $_[4]);
}


1;
