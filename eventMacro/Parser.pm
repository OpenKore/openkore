# $Id: Parser.pm r6759 2009-07-05 04:00:00Z ezza $
package eventMacro::Parser;

use strict;
use encoding 'utf8';

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(parseCmd);
our @EKSPORT_OK = qw(parseCmd);

use Globals;
use Utils qw/existsInList/;
use List::Util qw(max min sum);
use Log qw(message warning error);
use Text::Balanced qw/extract_bracketed/;


use eventMacro::Data;
use eventMacro::Utilities qw(refreshGlobal getnpcID getItemIDs getItemPrice getStorageIDs getInventoryIDs
	getPlayerID getMonsterID getVenderID getRandom getRandomRange getInventoryAmount getCartAmount getShopAmount
	getStorageAmount getVendAmount getConfig getWord q4rx q4rx2 getArgFromList getListLenght);


our ($rev) = q$Revision: 6759 $ =~ /(\d+)/;

# parses a text for keywords and returns keyword + argument as array
# should be an adequate workaround for the parser bug
#sub parseKw {
#	my @pair = $_[0] =~ /\@($macroKeywords)\s*\(\s*(.*)\s*\)/i;
#	return unless @pair;
#	if ($pair[0] eq 'arg') {
#		return $_[0] =~ /\@(arg)\s*\(\s*(".*?",\s*\d+)\s*\)/
#	} elsif ($pair[0] eq 'random') {
#		return $_[0] =~ /\@(random)\s*\(\s*(".*?")\s*\)/
#	}
#	while ($pair[1] =~ /\@($macroKeywords)\s*\(/) {
#		@pair = $pair[1] =~ /\@($macroKeywords)\s*\((.*)/
#	}
#	return @pair
#}

sub parseKw {
	my @full = $_[0] =~ /@($macroKeywords)s*((s*(.*?)s*).*)$/i;
	my @pair = ($full[0]);
	my ($bracketed) = extract_bracketed ($full[1], '()');
	return unless $bracketed;
	push @pair, substr ($bracketed, 1, -1);

	return unless @pair;
	if ($pair[0] eq 'arg') {
		return $_[0] =~ /\@(arg)\s*\(\s*(".*?",\s*(\d+|\$[a-zA-Z][a-zA-Z\d]*))\s*\)/
	} elsif ($pair[0] eq 'random') {
		return $_[0] =~ /\@(random)\s*\(\s*(".*?")\s*\)/
	}
	while ($pair[1] =~ /\@($macroKeywords)\s*\(/) {
		@pair = parseKw ($pair[1])
	}
	return @pair
}

# parses all macro perl sub-routine found in the macro script
sub parseSub {
	#Taken from sub parseKw :D
	my @full = $_[0] =~ /(?:^|\s+)(\w+)s*((s*(.*?)s*).*)$/i;
	my @pair = ($full[0]);
	my ($bracketed) = extract_bracketed ($full[1], '()');
	return unless $bracketed;
	push @pair, substr ($bracketed, 1, -1);

	return unless @pair;

	while ($pair[1] =~ /(?:^|\s+)(\w+)\s*\(/) {
		@pair = parseSub ($pair[1])
	}

	return @pair
}

# substitute variables
sub subvars {
# should be working now
	my ($pre, $nick) = @_;
	my ($var, $tmp);
	
	# variables
	$pre =~ s/(?:^|(?<=[^\\]))\$(\.?[a-z][a-z\d]*)/$eventMacro->is_var_defined($1) ? $eventMacro->get_var($1) : ''/gei;
=pod
	while (($var) = $pre =~ /(?:^|[^\\])\$(\.?[a-z][a-z\d]*)/i) {
		$tmp = $eventMacro->is_var_defined($var) ? $eventMacro->get_var($var):"";
		$var = q4rx $var;
		$pre =~ s/(^|[^\\])\$$var([^a-zA-Z\d]|$)/$1$tmp$2/g;
		last if defined $nick
	}
=cut
	
	# doublevars
	$pre =~ s/\$\{(.*?)\}/$eventMacro->is_var_defined("#$1") ? $eventMacro->get_var("#$1") : ''/gei;
=pod
	while (($var) = $pre =~ /\$\{(.*?)\}/i) {
		$tmp = ($eventMacro->is_var_defined("#$var"))?$eventMacro->get_var("#$var"):"";
		$var = q4rx $var;
		$pre =~ s/\$\{$var\}/$tmp/g
	}
=cut

	return $pre
}

# command line parser for macro
# returns undef if something went wrong, else the parsed command or "".
sub parseCmd {
	my ($cmd, $self) = @_;
	return "" unless defined $cmd;
	my ($kw, $arg, $targ, $ret, $sub, $val);

	# refresh global vars only once per command line
	refreshGlobal();
	
	while (($kw, $targ) = parseKw($cmd)) {
		$ret = "_%_";
		# first parse _then_ substitute. slower but more safe
		$arg = subvars($targ) unless $kw eq 'nick';
		my $randomized = 0;

		if ($kw eq 'npc')           {$ret = getnpcID($arg)}
		elsif ($kw eq 'cart')       {($ret) = getItemIDs($arg, $::cart{'inventory'})}
		elsif ($kw eq 'Cart')       {$ret = join ',', getItemIDs($arg, $::cart{'inventory'})}
		elsif ($kw eq 'inventory')  {($ret) = getInventoryIDs($arg)}
		elsif ($kw eq 'Inventory')  {$ret = join ',', getInventoryIDs($arg)}
		elsif ($kw eq 'store')      {($ret) = getItemIDs($arg, \@::storeList)}
		elsif ($kw eq 'storage')    {($ret) = getStorageIDs($arg)}
		elsif ($kw eq 'Storage')    {$ret = join ',', getStorageIDs($arg)}
		elsif ($kw eq 'player')     {$ret = getPlayerID($arg)}
		elsif ($kw eq 'monster')    {$ret = getMonsterID($arg)}
		elsif ($kw eq 'vender')     {$ret = getVenderID($arg)}
		elsif ($kw eq 'venderitem') {($ret) = getItemIDs($arg, \@::venderItemList)}
		elsif ($kw eq 'venderItem') {$ret = join ',', getItemIDs($arg, \@::venderItemList)}
		elsif ($kw eq 'venderprice'){$ret = getItemPrice($arg, \@::venderItemList)}
		elsif ($kw eq 'venderamount'){$ret = getVendAmount($arg, \@::venderItemList)}
		elsif ($kw eq 'random')     {$ret = getRandom($arg); $randomized = 1}
		elsif ($kw eq 'rand')       {$ret = getRandomRange($arg); $randomized = 1}
		elsif ($kw eq 'invamount')  {$ret = getInventoryAmount($arg)}
		elsif ($kw eq 'cartamount') {$ret = getCartAmount($arg)}
		elsif ($kw eq 'shopamount') {$ret = getShopAmount($arg)}
		elsif ($kw eq 'storamount') {$ret = getStorageAmount($arg)}
		elsif ($kw eq 'config')     {$ret = getConfig($arg)}
		elsif ($kw eq 'arg')        {$ret = getWord($arg)}
		elsif ($kw eq 'eval')       {$ret = eval($arg) unless $Settings::lockdown}
		elsif ($kw eq 'listitem')   {$ret = getArgFromList($arg)}
		elsif ($kw eq 'listlenght') {$ret = getListLenght($arg)}
		elsif ($kw eq 'nick')       {$arg = subvars($targ, 1); $ret = q4rx2($arg)}
		return unless defined $ret;
		return $cmd if $ret eq '_%_';
		$targ = q4rx $targ;
		unless ($randomized) {
			$cmd =~ s/\@$kw\s*\(\s*$targ\s*\)/$ret/g
		} else {
			$cmd =~ s/\@$kw\s*\(\s*$targ\s*\)/$ret/
		}
	}
	
	unless ($Settings::lockdown) {
		# any round bracket(pair) found after parseKw sub-routine were treated as macro perl sub-routine
		undef $ret; undef $arg;
		while (($sub, $val) = parseSub($cmd)) {
			my $sub_error = 1;
			foreach my $e (@perl_name) {
				if ($e eq $sub) {
					$sub_error = 0;
				}
			}
			if ($sub_error) {$self->{error} = "Unrecognized --> $sub <-- Sub-Routine"; return ""}
			$arg = subvars($val);
			my $sub1 = $sub."(".$arg.")";
			$ret = eval($sub1);
			return unless defined $ret;
			$val = q4rx $val;		
			$cmd =~ s/$sub\s*\(\s*$val\s*\)/$ret/g
		}
	}

	$cmd = subvars($cmd);
	return $cmd
}

1;
