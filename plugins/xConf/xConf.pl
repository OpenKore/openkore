# xConf plugin by 4epT (ICQ 2227733)
# Based on Lims idea
# Version: 4.2
# Latest changes
# 20.03.2026 by Henrybk (added bulk_iconf and bulk_mconf)
# 12.03.2017 by Mortimal
#
# Plug-in for change mon_control/pickupitems/items_control/priority files, using console commands.
#
# Examples of commands:
# mconf Spore 0 0 0
# mconf 1014 0 0 0
#
# iconf Meat 50 1 0
# iconf 517 50 1 0
#
# pconf Fluff -1
# pconf 914 -1
#
# priconf Pupa, Poring, Lunatic
#
# mconf clearall
# iconf setall 0 0 0

package xConf;

use strict;
use Plugins;
use Globals;
use Log qw(message error debug warning);
use Misc qw(parseReload);
use File::Spec ();
use Encode qw(decode encode FB_CROAK);

our (%bulk_cache, %write_cache);
%bulk_cache = ();
%write_cache = ();

Plugins::register('xConf', 'commands for change items_control, mon_control, pickupitems, priority', \&Unload, \&Unload);

my $chooks = Commands::register(
	['iconf', 'edit items_control.txt', \&xConf],
	['mconf', 'edit mon_control.txt', \&xConf],
	['pconf', 'edit pickupitems.txt', \&xConf],
	['sconf', 'edit shop.txt', \&xConf],
	['priconf', 'edit priority.txt', \&priconf],
);

my $Hooks = Plugins::addHooks(
	['bulk_iconf', \&on_bulk_iconf],
	['bulk_mconf', \&on_bulk_mconf],
);

sub Unload {
	%bulk_cache = ();
	%write_cache = ();
	Commands::unregister($chooks);
	Plugins::delHooks($Hooks);
	message "xConf plugin reloading or unloading\n", 'success'
}

sub xConf {
my ($cmd, $args) = @_;
	my ($file,$file2,$found,$key,$oldval,$shopname,$type,$value, $name, $inf_hash, $ctrl_hash);
	if ($cmd eq 'sconf') {
		($key, $value) = $args =~ /(name)(?:\s)(.*)/;
		$shopname = 1 if $key eq 'name';
	}
	($key, $value) = $args =~ /([\s\S]+?)(?:\s)([\-\d\.]+[\s\S]*)/ if !$shopname;
	$key = $args if !$key;
	$key =~ s/^\s+|\s+$//g;
	debug "extracted from args: KEY: $key, VALUE: $value\n";
	if (!$key) {
		error "Syntax Error in function '$cmd'. Not found <key>\n".
				"Usage: $cmd <key> [<value>]\n";
		return;
	}
	if ($cmd eq 'iconf') {
		$inf_hash  = \%items_lut;
		$ctrl_hash = \%items_control;
		$file = 'items_control.txt';
		$file2 = 'tables\..\items.txt';
		$type = 'Item';
	} elsif ($cmd eq 'mconf') {
		$inf_hash  = \%monsters_lut;
		$ctrl_hash = \%mon_control;
		$file = 'mon_control.txt';
		$file2 = 'tables\..\monsters.txt';
		$type = 'Monster';
	} elsif ($cmd eq 'pconf') {
		$inf_hash  = \%items_lut;
		$ctrl_hash = \%pickupitems;
		$file = 'pickupitems.txt';
		$file2 = 'tables\..\items.txt';
		$type = 'Item';
	} elsif ($cmd eq 'sconf') {
		$inf_hash = \%items_lut;
		$ctrl_hash = \%shop;
		$file = 'shop.txt';
		$file2 = 'tables\..\items.txt';
		$type = 'Item';
	}
	## Command "sconf" don't have setall & clearall feature
	if( (($key eq "clearall") || ($key eq "setall")) && ($cmd eq 'sconf')) {
		error "Syntax Error in function '$cmd'. Keys 'setall' and 'clearall' is not suported.\n";
		return;
	} elsif($key eq "clearall")	{ ## If $key is "clear" clear file content and exit
		fileclear($file);
		return;
	} elsif (($key eq "setall")) { ## If $key is "setall" setting all keys in file to $key
		filesetall($file, $value);
		return;
	}
	## Check $key in tables\monsters.txt & tables\items.txt
	if ($key ne "all") {

		#key is an ID, have to find the name of the item/monster
		if ($inf_hash->{$key}) {
			debug "key is an ID, $type '$inf_hash->{$key}' ID: $key is found in file '$file2'.\n";
			$found = 1;
			if ($cmd eq 'iconf' && $itemSlotCount_lut{$key}) {
				$name = $inf_hash->{$key}." [".$itemSlotCount_lut{$key}."]";
			} else {
				$name = $inf_hash->{$key};
			}

		#key is a name, have to find ID of the item/monster
		} else {
            my $lookup = lc $key;
            foreach my $id (keys %$inf_hash) {
                next unless lc($inf_hash->{$id}) eq $lookup;
                $name = $inf_hash->{$id};
                $key = $id;
                $found = 1;
                debug "$type '$name' found in file '$file2'.\n";
                last;
            }
		}

		#at this point, $key is always the ID of the item/monster
		#and the name is stored on $name

		debug "Id: '$key', name: '$name', value: $value\n";
		if (!$found and !$shopname) {
			if ($cmd eq 'mconf') {
				warning "WARNING: $type '$key' not found in file '$file2'!\n";
			} else {
				error "$type '$key' not found in file '$file2'!\n";
				return;
			}
		}
	}
	
	my $realKey;
	
	if (exists $ctrl_hash->{lc($name)}) {
		$realKey = lc($name);
	} else {
		$realKey = $key;
	}
	
	if ($cmd eq 'iconf') {
		$oldval = sprintf("%s %s %s %s %s", $ctrl_hash->{$realKey}{keep}, $ctrl_hash->{$realKey}{storage}, $ctrl_hash->{$realKey}{sell},
			$ctrl_hash->{$realKey}{cart_add}, $ctrl_hash->{$realKey}{cart_get});
	} elsif ($cmd eq 'mconf') {
		$oldval = sprintf("%s %s %s %s %s %s %s %s %s", $ctrl_hash->{$realKey}{attack_auto}, $ctrl_hash->{$realKey}{teleport_auto},
			$ctrl_hash->{$realKey}{teleport_search}, $ctrl_hash->{$realKey}{skillcancel_auto}, $ctrl_hash->{$realKey}{attack_lvl},
			$ctrl_hash->{$realKey}{attack_jlvl}, $ctrl_hash->{$realKey}{attack_hp}, $ctrl_hash->{$realKey}{attack_sp},
			$ctrl_hash->{$realKey}{weight});
	} elsif ($cmd eq 'pconf') {
		$oldval = $pickupitems{$realKey};
	} elsif ($cmd eq 'sconf') {
		if ($shopname) {
			$oldval = $shop{title_line};
			$oldval =~ s/;;/,,/g;
		} else {
			for my $sale (@{$shop{items}}) {
				if (lc($sale->{name}) eq lc($key)) {
					$oldval = $sale->{price};
					$oldval .= "..$sale->{priceMax}" if ($sale->{priceMax});
					$oldval .= " $sale->{amount}";
					last;
				}
			}
		}
	}
	$oldval =~ s/\s+$//g;
	$value =~ s/\s+$//g;
	debug "VALUE: '$value', OLDVALUE: '$oldval'\n";
	if (not defined $value and $oldval eq '') {
		error "$type '$key' is not found in file '$file'!\n";
	} elsif (not defined $value or $value eq $oldval) {
		message "$file: '$key' is $oldval\n", "info";
	} else {
		filewrite($file, $key, $value, $oldval, $shopname, $name, $realKey);
	}
}

## clear file leave only #lines, emptylines and all parameter.
sub fileclear {
	my ($file) = @_;
	my $controlfile = Settings::getControlFilename($file);
	open(FILE, "<:utf8", $controlfile);
	my @lines = <FILE>;
	close(FILE);
	chomp @lines;
	my @newlines;
	foreach (@lines) {
		push (@newlines,$_) if $_ =~ /^$/ || $_ =~ /^#/ || $_ =~ /^all/;
	}
	open(WRITE, ">:utf8", $controlfile);
	print WRITE join ("\n", @newlines);
	close(WRITE);
	message "xConf. $file: cleared.\n", 'info';
	parseReload($file);
}

## set all keys to $value
sub filesetall {
	my ($file,$value) = @_;
	my $controlfile = Settings::getControlFilename($file);
	my @value;
	
	if (!$value) {
		push (@value, "0") ;
	} else {
		@value = split(/\s+/, $value);
	}
	
	open(FILE, "<:utf8", $controlfile);	
	my @lines = <FILE>;
	close(FILE);
	chomp @lines;
	
	foreach my $line (@lines) {
		next if $line =~ /^$/ || $line =~ /^#/;
		my ($what) = $line =~ /([\s\S]+?)(?:\s[\-\d\.]+[\s\S]*)/;
		$what =~ s/\s+$//g;
		$line = join (' ', $what, @value);
	}
	
	open(WRITE, ">:utf8", $controlfile);
	print WRITE join ("\n", @lines);
	close(WRITE);
	
	message "xConf. $file: all set to $value.\n", 'info';
	parseReload($file);
}

## write FILE
sub filewrite {
	my ($file, $key, $value, $oldval, $shopname, $name, $realKey) = @_;
    if ($file eq 'items_control.txt' || $file eq 'mon_control.txt') {
        my $loaded = $file eq 'items_control.txt' ? \%items_control : \%mon_control;
        _bulk_write_control_entries($file, {$key => $value}, $loaded, sub { $name || $key }, 1);
        message "$file: '$name' set to $value (was ". ($oldval || "*None*") .")\n", 'info';
        return;
    }
	my @value;
	my $controlfile = Settings::getControlFilename($file);
	debug "sub WRITE = FILE: $file\nKEY: $key\nVALUE: $value\nNAME: $name\nOLDVALUE: $oldval\nREALKEY: $realKey";

	open(FILE, "<:encoding(UTF-8)", $controlfile);
	my @lines = <FILE>;
	close(FILE);
	chomp @lines;

	my $used = 0;
	if ($shopname) {
		@value = split(/,,/, $value);
		foreach my $line (@lines) {
			next if $line =~ /^$/ || $line =~ /^#/;
			if ($line eq $shop{title_line}) {
				$line = join (';;', @value);
				last;
			}
		}

	} else {
		@value = split(/\s+/, $value);
		foreach my $line (@lines) {
			my ($what) = $line =~ /([\s\S]+?)\s[\-\d\.]+[\s\S]*/;
			$what =~ s/\s+$//g;
			my $tmp;
			if (lc($what) eq $realKey) {
				debug "Change old record: ";
				if ($file eq 'shop.txt') {
					$tmp = join ('	', $name, @value);
				} else {
					if ($realKey eq lc($name)) {
						$tmp = join (' ', $name, @value, "#", $key);
					} else {
						$tmp = join (' ', $key, @value, "#", $name);
					}
				}
				$line = $tmp;
				$used = 1;
			}
		}
		if ($used == 0) {
			debug "New record: ";
			my ($price, $amount) = split(/\s+/, $value);
			if ($file eq 'shop.txt') {
				push (@lines, $name.'	'.$price.'	'.$amount)
			} else {
				push (@lines, $key.' '.$value. " #". $name)
			}
		}
	}
	open(WRITE, ">:utf8", $controlfile);
	print WRITE join ("\n", @lines);
	close(WRITE);
	message "$file: '$name' set to @value (was ". ($oldval || "*None*") .")\n", 'info';
	parseReload($file);
}

sub on_bulk_iconf {
	my ($hook, $args) = @_;
	_bulk_write_control_entries('items_control.txt', $args->{changes}, \%items_control, sub {
		my ($key) = @_;
		return $items_lut{$key} . " [" . $itemSlotCount_lut{$key} . "]" if $items_lut{$key} && $itemSlotCount_lut{$key};
		return $items_lut{$key} || $key;
	}, $args->{changes_checked});
}

sub on_bulk_mconf {
	my ($hook, $args) = @_;
	_bulk_write_control_entries('mon_control.txt', $args->{changes}, \%mon_control, sub {
		my ($key) = @_;
		if (exists $monstersTable{$key} && exists $monstersTable{$key}{Name}) {
			return $monstersTable{$key}{Name};
		}
		return $monsters_lut{$key} || $key;
	}, $args->{changes_checked});
}

sub _bulk_write_control_entries {
    my ($file, $changes, $ctrl_hash, $name_resolver, $checked) = @_;
    return unless ref($changes) eq 'HASH' && %$changes;
    my (%new_values, %updates);
    my $delta_safe = 1;
    my @fields = $file eq 'items_control.txt'
        ? qw(keep storage sell cart_add cart_get)
        : qw(attack_auto teleport_auto teleport_search skillcancel_auto attack_lvl attack_jlvl attack_hp attack_sp weight);
    foreach my $key (keys %$changes) {
        my $name = $name_resolver->($key);
        unless ($checked) {
            my @values = split /\s+/, $changes->{$key};
            my $same = @values <= @fields;
            my $found = 0;
            for my $alias ($key, lc $name) {
                next unless exists $ctrl_hash->{$alias};
                $found = 1;
                my $loaded = $ctrl_hash->{$alias};
                for my $index (0 .. $#fields) {
                    my $current = $loaded->{$fields[$index]};
                    if (defined($current) != defined($values[$index])
                        || (defined $current && $current ne $values[$index])) {
                        $same = 0;
                        last;
                    }
                }
                last unless $same;
            }
            next if $same && $found;
        }
        $delta_safe = 0 if $name =~ /[\r\n]/ || $changes->{$key} =~ /[\r\n]/
            || ($file eq 'mon_control.txt' && $changes->{$key} =~ /\t/)
            || ($file eq 'items_control.txt' && lc($key) eq 'all' && $changes->{$key} =~ /[^0-9\s]/);
        my $line = "$key $changes->{$key} #$name";
        $new_values{$key} = $line;
        $updates{lc $key} = 1;
        $updates{lc $name} = 1;
    }
    return unless %new_values;
    my $controlfile = Settings::getControlFilename($file);
    my $cached = $write_cache{$file};
    debug "[xConf] bulk write file: $controlfile\n" if Log::debugEnabled();
    open(my $fh, '+<:raw', $controlfile) or do {
        warning "[xConf] Unable to open $controlfile for reading: $!\n";
        return;
    };
    my $input_bytes = do { local $/; <$fh> } // '';
    my $original_size = length $input_bytes;
    my $text;
    my $cache_matches = $cached && $cached->{path} eq $controlfile && $cached->{bytes} eq $input_bytes;
    if ($cache_matches) {
        $text = $cached->{text};
    } else {
        $text = decode('UTF-8', $input_bytes, FB_CROAK);
        $text =~ s/^\x{FEFF}//;
        $text =~ s/\r\n/\n/g;
    }
    my @keys = sort keys %new_values;
    my $delta = join("\n", map { $new_values{$_} } @keys) . "\n";
    my $simple_keys = $delta_safe && !grep { !/\A(?:\d+|all)\z/i } @keys;
    my ($output, $output_bytes, %positions, $tail_offset, $tail_byte_offset);
    my %unsafe;
    my $input_collision = $cache_matches && grep { $cached->{unsafe}{$_} } keys %updates;
    if ($simple_keys && $cache_matches && !$input_collision) {
        my @spans = sort { $a->[0] <=> $b->[0] }
            map { @{$cached->{positions}{$_} || []} } keys %updates;
        if (@spans) {
            my $length = 0;
            $length += $_->[1] for @spans;
            my $start = $spans[0][0];
            if ($start + $length == length($text)) {
                $tail_offset = $start;
                $output = substr($text, 0, $start) . $delta;
                $tail_byte_offset = defined $cached->{tail_char_offset} && $cached->{tail_char_offset} == $start
                    ? $cached->{tail_byte_offset} : length(encode('UTF-8', substr($text, 0, $start)));
                $output_bytes = substr($cached->{bytes}, 0, $tail_byte_offset) . encode('UTF-8', $delta);
            }
        }
    }
    unless (defined $output) {
        my @lines = split /\n/, $text, -1;
        pop @lines if @lines && $lines[-1] eq '';
        my @kept;
        my $offset = 0;
        foreach my $line (@lines) {
            my $identifier;
            if ($line =~ /^(\d+)\s/) {
                $identifier = $1;
            } elsif ($line !~ /^\s*(?:#|!|$)/) {
                if ($line =~ /^\s*"([^"]+)"\s+[\-\d.]/) {
                    $identifier = $1;
                } else {
                    ($identifier) = $line =~ /([\s\S]+?)\s[\-\d.]+[\s\S]*/;
                    $identifier =~ s/(^\s+|^"|"$|\s+$)//g if defined $identifier;
                }
                $identifier = lc $identifier if defined $identifier;
            }
            if (defined $identifier && exists $updates{$identifier}) {
                debug "[xConf] Removing line '$line' for '$identifier'\n" if Log::debugEnabled();
            } else {
                push @kept, $line;
                my $parsed_key = defined $identifier && $line =~ /^\d+\s/
                    && ($file eq 'items_control.txt' || $line !~ /\t/)
                    ? $identifier : _core_control_key($file, $line);
                if (defined $identifier != defined $parsed_key
                    || (defined $identifier && $identifier ne $parsed_key)) {
                    $unsafe{$identifier} = 1 if defined $identifier;
                    $unsafe{$parsed_key} = 1 if defined $parsed_key;
                }
                push @{$positions{$identifier}}, [$offset, length($line) + 1] if defined $identifier;
                $offset += length($line) + 1;
            }
        }
        foreach my $key (@keys) {
            push @kept, $new_values{$key};
            push @{$positions{lc $key}}, [$offset, length($new_values{$key}) + 1];
            $offset += length($new_values{$key}) + 1;
            debug "[xConf] Adding line $new_values{$key}\n" if Log::debugEnabled();
        }
        $output = join("\n", @kept) . "\n";
    }
    $output_bytes = encode('UTF-8', $output) unless defined $output_bytes;
    my $wh = $fh;
    my $write_offset = defined $tail_offset ? $tail_byte_offset : 0;
    seek($wh, $write_offset, 0) or die "[xConf] Unable to seek $controlfile: $!";
    print {$wh} substr($output_bytes, $write_offset) or die "[xConf] Unable to write $controlfile: $!";
    truncate($wh, length $output_bytes) or die "[xConf] Unable to truncate $controlfile: $!"
        if length($output_bytes) < $original_size;
    close($wh) or do {
        warning "[xConf] Unable to finish writing $controlfile: $!\n";
        return;
    };
    if ($simple_keys) {
        if (defined $tail_offset) {
            delete @{$cached->{positions}}{keys %updates};
            my $offset = $tail_offset;
            foreach my $key (@keys) {
                $cached->{positions}{lc $key} = [[$offset, length($new_values{$key}) + 1]];
                $offset += length($new_values{$key}) + 1;
            }
            $cached->{text} = $output;
            $cached->{bytes} = $output_bytes;
            $cached->{tail_char_offset} = $tail_offset;
            $cached->{tail_byte_offset} = $tail_byte_offset;
        } else {
            $write_cache{$file} = {path => $controlfile, text => $output, bytes => $output_bytes, positions => \%positions, unsafe => \%unsafe};
        }
    } else {
        delete $write_cache{$file};
    }
    _reload_bulk_control($file, $controlfile, $output, $text, \%updates, $delta, $simple_keys, $cache_matches && !$input_collision);
}

# Mirror only the core identifier rules, not its value parsing. If the legacy
# writer identifier differs, any update touching either key forces a full parse
# so duplicates and shadowed named rules cannot remain stale in the cache.
sub _core_control_key {
    my ($file, $line) = @_;
    $line = lc $line;
    $line =~ s/\x{FEFF}//g;
    return if $line =~ /^\s*(?:#|$)/;
    if ($file eq 'items_control.txt') {
        return ($line =~ /^(\d+)\s/)[0] if $line =~ /^[\s0-9]+/;
        my ($quoted) = FileParsers::extract_delimited($line);
        if (defined $quoted && length $quoted) {
            my $key = substr($quoted, 1, length($quoted) - 2);
            return length($key) ? $key : undef;
        }
        $line =~ s/#.*//;
        return ($line =~ /^(.*[^\s0-9])[\s0-9]*$/s)[0];
    }
    $line =~ s/[\r\n]//g;
    $line =~ s/\s+$//;
    $line =~ s/\s*#.*//;
    return unless length $line;
    return (split /\t+/, $line)[0] if $line =~ /\t/;
    return ($line =~ /([\s\S]+?) [-\d.]+[\s\S]*/)[0];
}

# The cache is private parsed file state, never references exposed to callers.
# Exact input-text comparison detects same-size/same-time external edits. Includes
# and pre-load/custom-loader hooks use the ordinary reload path.
sub _reload_bulk_control {
    my ($file, $path, $text, $old_text, $aliases, $delta, $cacheable, $incremental) = @_;
    if (!$cacheable || $text =~ /^\s*!/m || Plugins::hasHook('preloadfiles') || Plugins::hasHook('loadfiles')
        || Plugins::hasHook('pre_load_'.$file) || Plugins::hasHook('load_'.$file)) {
        delete $bulk_cache{$file};
        return parseReload($file);
    }
    my $expected = File::Spec->canonpath(File::Spec->rel2abs($path));
    my $parser = $file eq 'items_control.txt' ? \&FileParsers::parseItemsControl : \&FileParsers::parseMonControl;
    my $target = $file eq 'items_control.txt' ? \%items_control : \%mon_control;
    my @registered = grep {
        ref($_->{loader}) eq 'ARRAY' && $_->{loader}[0] == $parser
            && $_->{loader}[1] == $target
            && File::Spec->canonpath(File::Spec->rel2abs($_->{name})) eq $expected
    } @{$Settings::files->getItems};
    return parseReload($file) unless @registered == 1;
    my $used = 0;
    my $hook = Plugins::addHook('load_'.$file, sub {
        my ($name, $args) = @_;
        return if $used || !$args->{args} || $args->{args}[0] != $target
            || File::Spec->canonpath(File::Spec->rel2abs($args->{filename})) ne $expected;
        $used = 1;
        my $previous = $bulk_cache{$file};
        my %rules;
        if ($incremental && $previous && $previous->{path} eq $expected && $previous->{parser} == $parser
            && $previous->{text} eq $old_text) {
            %rules = %{$previous->{rules}};
            delete @rules{keys %$aliases};
            my %changed;
            _parse_control_text($parser, $path, $delta, \%changed);
            @rules{keys %changed} = values %changed;
        } else {
            _parse_control_text($parser, $path, $text, \%rules);
        }
        # Clone each unique record once. Core item parsing interns identical
        # values; loaded records must never be able to mutate the cache.
        my %copies;
        %$target = map { $_ => ($copies{$rules{$_}} ||= {%{$rules{$_}}}) } keys %rules;
        $bulk_cache{$file} = {path => $expected, parser => $parser, text => $text, rules => \%rules};
        $args->{return} = 1;
    });
    my ($ok, $error);
    { local $@; $ok = eval { parseReload($file); 1 }; $error = $@; }
    Plugins::delHook($hook);
    die $error unless $ok;
}

sub _parse_control_text {
    my ($parser, $path, $text, $target) = @_;
    my $reader_new = \&Utils::TextReader::new;
    no warnings 'redefine';
    local *Utils::TextReader::new = sub {
        return xConf::BufferedReader->new($text) if $_[1] eq $path && caller eq 'FileParsers';
        return $reader_new->(@_);
    };
    $parser->($path, $target);
}

package xConf::BufferedReader;
sub new {
    my ($class, $text) = @_;
    $text =~ s/\x{FEFF}//g;
    my @lines = grep { /\S/ && !/^\s*#/ } split /\n/, $text;
    return bless {lines => \@lines, index => 0}, $class;
}
sub eof { $_[0]{index} >= @{$_[0]{lines}} }
sub readLine { $_[0]{lines}[$_[0]{index}++] }

package xConf;

sub priconf {
	my ($cmd, $args) = @_;
	my @mobs = split /\s*,\s*/, $args;
	if (@mobs == 0) { 
		error "Syntax Error in function 'priconf'.\n".
				"Usage: priconf monster1, monster2, ...\n";
		return;
	}
	my $controlfile = Settings::getControlFilename('priority.txt');
	open(my $file,"<:utf8",$controlfile);
	my @lines;
	while (my $tmp = <$file>) {
		push @lines, $tmp if ($tmp =~ /^#/ or $tmp =~ /^!/);
	}
	push @lines, "\n";
	foreach (@mobs) { push @lines, $_."\n" }
	close($file);
	open($file,">:utf8",$controlfile);
	print $file @lines;
	close($file);
	parseReload("priority.txt");
}

1;
