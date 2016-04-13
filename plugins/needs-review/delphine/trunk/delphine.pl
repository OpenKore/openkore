=pod

based on original patches and scripts by ToXCiL

http://forums.openkore.com/viewtopic.php?p=35377#p35377

put data from packet capture to tables/delphine-data.txt and choose "Generate", then "Continue"
OR
put the key to tables/delphine-key.txt and choose "Continue"

in noninteractive mode key will be automatically generated if there is enough data which is more up to date than key,
and it will always continue if there is any key

=cut
package delphine;
use strict;

use Globals qw/$interface $net $packetParser %config/;
use Log qw/message warning error debug/;
use Misc qw/configModify bulkConfigModify quit/;
use Translation qw/T TF/;

use constant {
	NAME => 'delphine',
	CF_DATA => 'delphine-data.txt',
	CF_KEY => 'delphine-key.txt',
};

{
	my $hooks = Plugins::addHooks(
		['start3', \&start],
		['Network::serverRecv', \&serverRecv], # hook in DirectConnection
	);

	Plugins::register(NAME, T('packet encryption'), sub { Plugins::delHooks($hooks) });
}

our ($cf_data, $cf_key);
our (@data_key, @key);
our $encrypter = sub {};

sub start {
	bulkConfigModify({qw(
		delphine_interactive 1
	)}) unless exists $config{delphine_interactive};
	
	($cf_data, $cf_key) = (
		Settings::addTableFile(CF_DATA, loader => [\&loadData, \@data_key], mustExist => 0),
		Settings::addTableFile(CF_KEY, loader => [\&loadKey, \@key], mustExist => 0),
	);
	
	my $action = 'reload';
	my ($mtime_data, $mtime_key);
	while ($action !~ /^(?:continue|unload|exit)$/o) {
		if ($action eq 'reload') {
			Settings::loadByHandle($cf_data, sub { $mtime_data = (stat $_[0])[9] });
			Settings::loadByHandle($cf_key, sub { $mtime_key = (stat $_[0])[9] });
		}
		
		$action = 'exit';
		my (@messages, @choices);
		
		if (@key) {
			push @messages, T('Current key can be used to continue');
			push @choices, [continue => T('Continue')];
			$action = 'continue';
		} else {
			push @messages, T('There is no current key');
		}
		if (@data_key and $mtime_data > $mtime_key || !@key) {
			push @messages, @key ? T('There is enough data to update the key') : T('There is enough data to generate the key');
			$action = 'generate';
		}
		push @messages, T('There is not enough data to generate the key') unless @data_key;
		
		push @choices, [unload => T('Unload delphine (continue without encryption)')];
		
		if ($config{delphine_interactive}) {
			push @choices, [generate => TF('Generate %s from %s', CF_KEY, CF_DATA)] if @data_key;
			push @choices, [reload => TF('Reload %s and %s', CF_KEY, CF_DATA)];
			push @choices, [nointeractive => T('Disable interactive mode')];
			push @choices, [exit => T('Exit')];
			
			$action = $choices[$interface->showMenu((join "\n", @messages), [map { $_->[1] } @choices], title => T('Delphine'))][0];
		} else {
			message sprintf "%s\n", join "\n", @messages;
		}
		
		if ($action eq 'generate') {
			if (@data_key) {
				saveKey(Settings::getTableFilename(CF_KEY) || File::Spec->catfile((Settings::getTablesFolders)[0], CF_KEY), \@data_key);
				@key = @data_key;
				undef $mtime_data;
			} else {
				$action = 'exit';
			}
		}
		configModify(qw(delphine_interactive 0)) if $action eq 'nointeractive';
		Plugins::unload(NAME) if $action eq 'unload';
		quit if $action eq 'exit';
	}
	
	$encrypter = eval sprintf 'sub { ${$_[0]} =~ y/\x00-\xff/%s/ }', join '', map { sprintf '\x%.2x', $_ } @key if @key;
}

sub serverRecv {
	my (undef, $args) = @_;
	
	return unless $net->getState < Network::CONNECTED_TO_MASTER_SERVER;
	
	$encrypter->($args->{msg});
}

sub loadData {
	my ($file, $key) = @_;
	@$key = ();
	
	my (@clean, @encrypted, %table);
	my $secure_login_key_switch = $config{delphine_secureLoginKeySwitch} || 'DC01';
	
	message TF("Loading data from %s...\n", $file);
	my $reader = new Utils::TextReader($file);
	until ($reader->eof) {
		local $_ = $reader->readLine;
		s/\s+//g;
		push @{/^$secure_login_key_switch/i ? \@clean : \@encrypted}, map hex, map /(.{2})/g, $_;
	}
	
	debug T("Building keys table...\n");
	for (my $each = List::MoreUtils::each_array(@encrypted, @clean); my ($encrypted, $clean) = $each->();) {
		if (exists $table{$encrypted} && $table{$encrypted} != $clean) {
			warning TF("Conflict for key %.2x (%.2x => %.2x) found in %s\n", $encrypted, $table{$encrypted}, $clean, $file);
		}
		$table{$encrypted} = $clean;
	}
	
	message TF("%d/256 keys found in %s\n", scalar keys %table, $file);
	if (keys %table) {
		message TF("Keys table:\n%s\n", join "\n", map /(.{1,48})/g, join ' ', map { exists $table{$_} ? sprintf '%.2x', $table{$_} : '__'} 0 .. 0xff);
	}
	unless (keys %table == 0x100) {
		warning TF("Missing keys:\n%s\n", join "\n", map /(.{1,48})/g, join ' ', map { sprintf '%.2x', $_ } grep { !exists $table{$_} } 0 .. 0xff);
		return
	}
	
	@$key = map { $table{$_} } 0 .. 0xff;
}

sub loadKey {
	my ($file, $key) = @_;
	@$key = ();
	
	message TF("Loading key from %s...\n", $file);
	my $reader = new Utils::TextReader($file);
	until ($reader->eof) {
		local $_ = $reader->readLine;
		s/\s+//g;
		push @$key, map hex, map /(.{2})/g, $_;
	}
	
	unless (@$key == 0x100) {
		error TF("%s is in unknown format\n", $file);
		@$key = ();
	}
}

sub saveKey {
	my ($file, $key) = @_;
	
	message TF("Saving key to %s...\n", $file);
	
	open my $f, '>:utf8', $file;
	print $f sprintf "%s\n", join "\n", map /(.{1,48})/g, join ' ', map { sprintf '%.2x', $_ } @$key;
}

1;
