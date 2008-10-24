package cartlog;

=head1 NAME

cartlog plugin for openkore

=head1 DESCRIPTION

Logs cart contents to file

=head1 VERSION

Version 0.4

=head1 AUTHOR

Arachno <arachnophobia at users dot sf dot net>

=cut

use strict;
use sort 'stable';
use Plugins;
use Globals;
use Log qw(message);

Plugins::register('cartlog', 'writes cart inventory to file.', \&Unload);

my $hook = Commands::register(['cartlog', "print cart contents to file", \&cartLog]);
            
sub Unload {
	Commands::unregister($hook)
}

sub cartLog {
	my $logfile = $_[1]?$_[1]:"$Settings::logs_folder/cartlog.csv";

	my $cartlog;
	foreach my $inv (@{$cart{inventory}}) {
		next unless defined $inv->{name};
		if (defined $cartlog->{$inv->{name}}) {
			$cartlog->{$inv->{name}}++
		} else {
			$cartlog->{$inv->{name}} = $inv->{amount}
		}
	}

	open CARTFILE, "> $logfile";
	foreach my $i (sort keys %{$cartlog}) {
		printf CARTFILE "%s,%d\n", $i, $cartlog->{$i}
	}
	close CARTFILE;
	message "Cart contents written to $logfile\n"
}

1;
