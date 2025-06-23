package mapNormalizer;

use strict;
use Plugins;
use Globals;
use Log qw(message warning error);

Plugins::register('mapNormalizer', 'Normalizes map names like izlude_a => izlude', \&onUnload);

my $hooks = Plugins::addHooks(
	['packet/map_change', \&normalizeMapName, undef],
	['packet/map_changed', \&normalizeMapName, undef],
	['packet/map_loaded', \&normalizeMapName, undef]
);

sub onUnload {
    Plugins::delHooks($hooks);
}

my @map_normalizations = (
	{ pattern => qr/^juperos_01[a-b]$/,	normalized => 'juperos_01' },
	{ pattern => qr/^lou_fild01[a-b]$/,	normalized => 'lou_fild01' },
	{ pattern => qr/^mag_dun01[a-b]$/,	normalized => 'mag_dun01' },
	{ pattern => qr/^moc_para0[a-c]$/,	normalized => 'moc_para01' },
	{ pattern => qr/^odin_tem02[a-b]$/,	normalized => 'odin_tem02' },
	{ pattern => qr/^orcsdun01_[abc]$/,	normalized => 'orcsdun01' },
	{ pattern => qr/^pay_dun00_[abc]$/,	normalized => 'pay_dun00' },
	{ pattern => qr/^prt_fild08[a-d]$/,	normalized => 'prt_fild08' },
	{ pattern => qr/^ra_fild12[a-b]$/,	normalized => 'ra_fild12' },
	{ pattern => qr/^ra_san01[a-b]$/,	normalized => 'ra_san01' },
	{ pattern => qr/^thor_v03[a-b]$/,	normalized => 'thor_v03' },
	{ pattern => qr/^ve_fild03[a-b]$/,	normalized => 've_fild03' },
	{ pattern => qr/^ve_fild07[a-b]$/,	normalized => 've_fild07' },
	{ pattern => qr/^gef_f10_[abc]$/,	normalized => 'gef_fild10' },
	{ pattern => qr/^gl_church_[ab]$/,	normalized => 'gl_church' },
    { pattern => qr/^iz_int0[1-4]$/,	normalized => 'iz_int' },
	{ pattern => qr/^int_land0[1-4]$/,	normalized => 'int_land' },
	{ pattern => qr/^iz_ac01_[abcd]$/,	normalized => 'iz_ac01' },
	{ pattern => qr/^iz_ac02_[abcd]$/,	normalized => 'iz_ac02' },
	{ pattern => qr/^izlude_[abcd]$/,	normalized => 'izlude' },
	{ pattern => qr/^prt_fild08[abcd]$/,normalized => 'prt_fild08' },
);

sub normalizeMapName {
	my $name = $::field->{name};
	return unless $name;

	# Lets print the name for debug
	message "[mapNormalizer] Normalizing map name: $name\n";

	foreach my $rule (@map_normalizations) {
		if ($name =~ $rule->{pattern}) {
			message "[mapNormalizer] Normalizing \$field->{name} from '$name' to '$rule->{normalized}'\n";
			$::field->{name}     = $rule->{normalized};
			$::field->{baseName} = $rule->{normalized};
			last;
		}
	}
}


1;
