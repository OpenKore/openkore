#########################################################################
#  OpenKore - Module Support Code
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#########################################################################

# This file contains a list of other modules that Kore uses (internal modules;
# not public Perl modules).
# At startup, Modules::register() is called with a list of modules (see also
# openkore.pl). This module will save that list so it can be used later for
# automatic source code reloading.
#
# Modules::reload() is similar to the "reload" command you type in the
# console. he difference is that this function reloads the source code,
# not config files.

package Modules;

use strict;
no strict 'refs';
use Exporter;
use Config;

our @modules;
our @ISA = "Exporter";
our @EXPORT_OK = qw(&register &reload &checkSyntax @modules);


sub register {
	foreach (@_) {
		if (! -f "$_.pm") {
			print STDERR "Error: module $_.pm not found\n";
			exit 1;
		}

		# Call the module's MODINIT() function when it's registered
		my $initFunc = "${_}::MODINIT";
		$initFunc->() if (defined(&{$initFunc}));

		push @modules, $_;
	}
}

sub reload {
	my ($arg, $regex) = @_;

	sub reload2 {
		my ($name, $regex) = @_;
		foreach (@modules) {
			my ($match, $mod);

			$mod = $_;
			if ($name eq "all") {
				$match = 1;
			} elsif ($regex) {
				$match = ($mod =~ /$name/i);
			} else {
				$match = (lc($mod) eq lc($name));
			}
			next if (!$match);

			$mod .= '.pm';
			if (! -f $mod) {
				print "Error: file $mod not found\n";
			} elsif (checkSyntax($mod)) {
				print "Reloading $mod...\n";
				if (!do $mod || $@) {
					print "Unable to reload $mod\n";
					print "$@\n" if ($@);
				}
			}
		}
	}

	if ($regex) {
		my @names = split(/ +/, $arg);
		foreach my $name (@names) {
			reload2($name, 1);
		}
	} else {
		reload2($arg, 0);
	}
}

sub checkSyntax {
	my $filename = shift;

	if (-f $Config{'perlpath'}) {
		system($Config{'perlpath'}, '-c', $filename);
		if ($? == -1) {
			print "Error: failed to execute $Config{'perlpath'}\n";
			return -1;
		} elsif ($? & 127) {
			print "Error: $Config{'perlpath'} exited abnormally\n";
			return -1;
		} elsif (($? >> 8) == 0) {
			return 1;
		} else {
			print "Error: $filename contains syntax errors.\n";
			return 0;
		}
	}
	return 2;
}

return 1;
