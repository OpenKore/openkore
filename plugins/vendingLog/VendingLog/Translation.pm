package VendingLog::Translation;

use strict;

use Exporter;
use base qw(Exporter Translation);
use Plugins;
use Log;

our @EXPORT = qw(T TF);
our $_translation;

use constant {
	PLUGIN_PODIR => "$Plugins::current_plugin_folder/po",
};

sub initDefault {
	my ($podir, $locale) = @_;
	$podir = PLUGIN_PODIR if (!defined $podir);
	$_translation = Translation::_load(Translation::_autodetect($podir, $locale));
	return defined $_translation;
}

sub T {
	my ($message) = @_;
	Translation::_translate($_translation, \$message);
	return $message;
}

sub TF {
	my $message = shift;
	Translation::_translate($_translation, \$message);
	return sprintf($message, @_);
}

1;