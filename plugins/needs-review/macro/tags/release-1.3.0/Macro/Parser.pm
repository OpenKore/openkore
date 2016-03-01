package Macro::Parser;

use strict;
use warnings;
use encoding 'utf8';

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(parseMacroFile parseCmd);

use Globals;
use Log qw(message error);
use Macro::Data;
use Macro::Utilities qw(setVar getVar getnpcID getItemIDs getStorageIDs
    getPlayerID getRandom getRandomRange getInventoryAmount getCartAmount
    getShopAmount getStorageAmount getConfig getWord);

our $Changed = sprintf("%s %s %s",
    q$Date: 2006-06-12 13:37:33 +0200 (ma, 12 jun 2006) $
    =~ /(\d{4}-\d{2}-\d{2}) (\d{2}:\d{2}:\d{2}) ([+-]\d{4})/);
      
# adapted config file parser
sub parseMacroFile {
  my ($file, $no_undef) = @_;
  unless ($no_undef) {
    undef %macro;
    undef %automacro
  }

  my %block;
  my $tempmacro = 0;
  open FILE, "<:utf8", $file or return 0;
  foreach (<FILE>) {
    next if (/^\s*#/); # skip comments
    s/^\s*//g;         # remove leading whitespaces
    s/\s*[\r\n]?$//g;  # remove trailing whitespaces and eol
    s/  +/ /g;         # trim down spaces
    next unless ($_);

    if (!%block && /{$/) {
      s/\s*{$//;     # remove { at end of line
      my ($key, $value) = $_ =~ /^(.*?)\s+(.*)/;
      if ($key eq 'macro') {
        %block = (name => $value, type => "macro");
        $macro{$value} = []
      } elsif ($key eq 'automacro') {
        %block = (name => $value, type => "auto")
      }
    } elsif (%block && $block{type} eq "macro") {
      if ($_ eq "}") {
        undef %block
      } else {
        push(@{$macro{$block{name}}}, $_)
      }
    } elsif (%block && $block{type} eq "auto") {
      if ($_ eq "}") {
        if ($block{loadmacro}) {
          undef $block{loadmacro}
        } else {
          undef %block
        }
      } elsif ($_ eq "call {") {
        $block{loadmacro} = 1;
        $block{loadmacro_name} = "tempMacro".$tempmacro++;
        $automacro{$block{name}}->{call} = $block{loadmacro_name};
        $macro{$block{loadmacro_name}} = []
      } elsif ($block{loadmacro}) {
        push(@{$macro{$block{loadmacro_name}}}, $_)
      } else {
        my ($key, $value) = $_ =~ /^(.*?)\s+(.*)/;
        next unless $key;
        if ($amSingle{$key}) {
          $automacro{$block{name}}->{$key} = $value
        } else {
          push(@{$automacro{$block{name}}->{$key}}, $value)
        }
      }
    } else {
      my ($key, $value) = $_ =~ /^(.*?)\s+(.*)$/;
      if ($key eq "!include") {
        # stolen from FileParsers.pm, kekeke
        my $f = $value;
        if (!File::Spec->file_name_is_absolute($value) && $value !~ /^\//) {
          if ($file =~ /[\/\\]/) {
            $f = $file;
            $f =~ s/(.*)[\/\\].*/$1/;
            $f = File::Spec->catfile($f, $value)
          } else {
            $f = $value
          }
        }
        if (-f $f) {
          my $ret = parseMacroFile($f, 1);
          return $ret unless $ret
        } else {
          error "$file: Include file not found: $f\n";
          return 0
        }
      }
    }
  }
  close FILE;
  return 0 if %block;
  return 1
}

# parses a text for keywords and returns keyword + argument as array
# should be an adequate workaround for the parser bug
sub parseKw {
  my $text = shift;
  my $keywords = "npc|cart|inventory|store|storage|player|vender|random|rand|".
                 "invamount|cartamount|shopamount|storamount|config|eval|arg";
  my @pair = $text =~ /\@($keywords)\s*\(\s*(.*?)\s*\)/i;
  return unless @pair;
  if ($pair[0] eq 'arg') {return $text =~ /\@(arg)\s*\(\s*(".*?",\s*\d+)\s*\)/}
  elsif ($pair[0] eq 'random') {return $text =~ /\@(random)\s*\(\s*(".*?")\s*\)/}
  while ($pair[1] =~ /^\@($keywords)\s*\(/) {@pair = $pair[1] =~ /^\@($keywords)\s*\((.*)/}
  return @pair
}

# command line parser for macro
# returns undef if something went wrong, else the parsed command or "".
sub parseCmd {
  $cvs->debug("parseCmd (@_)", $logfac{function_call_macro});
  my $command = shift;
  return "" unless defined $command;
  my $var;
  # substitute variables
  while ((undef, $var) = $command =~ /(^|[^\\])\$(\.?[a-z][a-z\d]*)/i) {
    $cvs->debug("found variable $var in $command", $logfac{parser_steps});
    my $tmp = getVar($var);
    $tmp = "" unless defined $tmp;
    $var = quotemeta $var;
    $command =~ s/(^|[^\\])\$$var([^a-zA-Z\d]|$)/$1$tmp$2/g
  }
  # substitute doublevars
  while (($var) = $command =~ /\$\{(.*?)\}/i) {
    $cvs->debug("found doublevar $var in $command", $logfac{parser_steps});
    my $tmp = getVar("#".$var);
    $tmp = "" unless defined $tmp;
    $var = quotemeta $var;
    $command =~ s/\$\{$var\}/$tmp/g
  }
  while (my ($kw, $arg) = parseKw($command)) {
    $cvs->debug("parsing '$command': '$kw', '$arg'", $logfac{parser_steps});
    my $ret = "_%_";
    if ($kw eq 'npc')           {$ret = getnpcID($arg)}
    elsif ($kw eq 'cart')       {($ret, undef) = getItemIDs($arg, \@{$cart{inventory}})}
    elsif ($kw eq 'Cart')       {my @ids = getItemIDs($arg, \@{$cart{inventory}}); $ret = join ',', @ids}
    elsif ($kw eq 'inventory')  {($ret, undef) = getItemIDs($arg, \@{$char->{inventory}})}
    elsif ($kw eq 'Inventory')  {my @ids = getItemIDs($arg, \@{$char->{inventory}}); $ret = join ',', @ids}
    elsif ($kw eq 'store')      {($ret, undef) = getItemIDs($arg, \@::storeList)}
    elsif ($kw eq 'storage')    {($ret, undef) = getStorageIDs($arg)}
    elsif ($kw eq 'Storage')    {my @ids = getStorageIDs($arg); $ret = join ',', @ids}
    elsif ($kw eq 'player')     {$ret = getPlayerID($arg, \@::playersID)}
    elsif ($kw eq 'vender')     {$ret = getPlayerID($arg, \@::venderListsID)}
    elsif ($kw eq 'random')     {$ret = getRandom($arg)}
    elsif ($kw eq 'rand')	{$ret = getRandomRange($arg)}
    elsif ($kw eq 'invamount')  {$ret = getInventoryAmount($arg)}
    elsif ($kw eq 'cartamount') {$ret = getCartAmount($arg)}
    elsif ($kw eq 'shopamount') {$ret = getShopAmount($arg)}
    elsif ($kw eq 'storamount') {$ret = getStorageAmount($arg)}
    elsif ($kw eq 'config')     {$ret = getConfig($arg)}
    elsif ($kw eq 'arg')        {$ret = getWord($arg)}
    elsif ($kw eq 'eval')       {$ret = eval($arg)}
    return unless defined $ret;
    return $command if $ret eq '_%_';
    $arg = quotemeta $arg; $command =~ s/\@$kw\s*\(\s*$arg\s*\)/$ret/g
  }
  return $command
}

1;
