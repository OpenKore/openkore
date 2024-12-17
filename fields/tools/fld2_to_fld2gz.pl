use strict;
use IO::Compress::Gzip qw(gzip);

foreach my $name (sort(listMaps("."))) {
	gzip "$name.fld2" => "$name.fld2.gz"
}

sub listMaps {
	my ($dir) = @_;
	my $handle;

	opendir($handle, $dir);
	my @list = grep { /\.fld2$/i && -f $_ } readdir $handle;
	closedir $handle;

	foreach my $file (@list) {
		$file =~ s/\.fld2$//i;
	}
	return @list;
}