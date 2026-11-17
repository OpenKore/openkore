package XConfTest;

use strict;
use warnings;

use Test::More;
use FindBin qw($RealBin);
use File::Spec;
use File::Temp qw(tempdir);

use Commands;
use Globals;
use Plugins;
use Settings;

sub start {
	subtest 'xConf plugin' => sub {
		my @old_control_folders = Settings::getControlFolders();
		my $tempdir = tempdir(CLEANUP => 1);
		my $plugin_file = File::Spec->catfile($RealBin, '..', '..', 'plugins', 'xConf', 'xConf.pl');
		my $items_control_file = File::Spec->catfile($tempdir, 'items_control.txt');
		my $mon_control_file = File::Spec->catfile($tempdir, 'mon_control.txt');

		_write_file($items_control_file, <<'END_ITEMS');
# test items
all 0 1 0
Main Gauche [4] 2 0 0 0 0 #1208
END_ITEMS

		_write_file($mon_control_file, <<'END_MONS');
# test monsters
all 0 0 0
Poring 0 0 0 0 0 0 0 0 0
END_MONS

		Settings::setControlFolders($tempdir);

		local %Globals::items_lut = (
			1208 => 'Main Gauche',
		);
		local %Globals::itemSlotCount_lut = (
			1208 => 4,
		);
		local %Globals::items_control = (
			'main gauche [4]' => {
				keep => 2,
				storage => 0,
				sell => 0,
				cart_add => 0,
				cart_get => 0,
			},
		);
		local %Globals::monsters_lut = (
			1002 => "\x1CoYYB\x1C",
		);
		local %Globals::monstersTable = (
			1002 => { Name => 'Poring' },
		);
		local %Globals::mon_control = (
			poring => {
				attack_auto => 0,
				teleport_auto => 0,
				teleport_search => 0,
				skillcancel_auto => 0,
				attack_lvl => 0,
				attack_jlvl => 0,
				attack_hp => 0,
				attack_sp => 0,
				weight => 0,
			},
		);

		eval { Plugins::load($plugin_file) };
		ok(!$@, 'loads xConf plugin') or do {
			diag $@ if $@;
			Settings::setControlFolders(@old_control_folders);
			return;
		};

		ok(Plugins::registered('xConf'), 'registers xConf plugin');
		ok(Plugins::hasHook('bulk_iconf'), 'registers bulk_iconf hook');
		ok(Plugins::hasHook('bulk_mconf'), 'registers bulk_mconf hook');

		my @reloads;
		{
			no warnings 'redefine';
			local *xConf::parseReload = sub {
				push @reloads, $_[0];
			};

			Plugins::callHook('bulk_iconf', {
				changes => {
					1208 => '22 0 0 0 0',
				}
			});
		}

		is_deeply(\@reloads, ['items_control.txt'], 'bulk_iconf reloads items_control.txt');
		is(
			_slurp($items_control_file),
			join("", (
				"# test items\n",
				"all 0 1 0\n",
				"1208 22 0 0 0 0 #Main Gauche [4]\n",
			)),
			'bulk_iconf rewrites items_control.txt with canonical line'
		);

		@reloads = ();
		{
			no warnings 'redefine';
			local *xConf::parseReload = sub {
				push @reloads, $_[0];
			};

			Plugins::callHook('bulk_mconf', {
				changes => {
					1002 => '1 0 0 0 0 0 0 0 0',
				}
			});
		}

		is_deeply(\@reloads, ['mon_control.txt'], 'bulk_mconf reloads mon_control.txt');
		is(
			_slurp($mon_control_file),
			join("", (
				"# test monsters\n",
				"all 0 0 0\n",
				"1002 1 0 0 0 0 0 0 0 0 #Poring\n",
			)),
			'bulk_mconf rewrites mon_control.txt with canonical line'
		);

		ok(Plugins::unload('xConf'), 'unloads xConf plugin');
		ok(!Plugins::registered('xConf'), 'removes xConf plugin registration on unload');
		ok(!Plugins::hasHook('bulk_iconf'), 'removes bulk_iconf hook on unload');
		ok(!Plugins::hasHook('bulk_mconf'), 'removes bulk_mconf hook on unload');

		Settings::setControlFolders(@old_control_folders);
		done_testing();
	};
}

sub _write_file {
	my ($file, $content) = @_;
	open my $fh, '>:utf8', $file or die "Unable to write $file: $!";
	print {$fh} $content;
	close $fh;
}

sub _slurp {
	my ($file) = @_;
	open my $fh, '<:utf8', $file or die "Unable to read $file: $!";
	local $/;
	my $content = <$fh>;
	close $fh;
	return $content;
}

1;
