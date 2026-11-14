use strict;
use warnings;

for my $file (qw(XS/Bitmap.xs XS/Icon.xs)) {
	open my $in, '<', $file or die "$file: $!";
	local $/;
	my $source = <$in>;
	close $in;
	$source =~ s{(#if WXPERL_W_VERSION_LT\( 3, 3, )1( \)\s+void\s+(?:GetHandlers|wxIcon::SetDepth)\()}{${1}0$2}
		or die "Unsupported WxPerl source: $file\n";
	open my $out, '>', $file or die "$file: $!";
	print {$out} $source;
	close $out or die "$file: $!";
}
