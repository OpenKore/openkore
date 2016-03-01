# $Header$
package Macro::Parser;

use strict;
use warnings;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(parseMacroFile parseCmd);

use Globals;
use Log qw(message error);
use Macro::Data;
use Macro::Utilities qw(setVar getVar getnpcID getItemID getStorageID
    getPlayerID getRandom getInventoryAmount getCartAmount getShopAmount
    getStorageAmount getWord);

our $Version = sprintf("%d.%02d", q$Revision: 3475 $ =~ /(\d+)\.(\d+)/);

# adapted config file parser
sub parseMacroFile {
  my ($file) = @_;
  undef %macro;
  undef %automacro;

  my %block;
  my $tempmacro = 0;
  open FILE, "< $file" or return 0;
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
        $macro{$value} = [];
      } elsif ($key eq 'automacro') {
        %block = (name => $value, type => "auto");
      }
    } elsif ($block{type} eq "macro") {
      if ($_ eq "}") {
        undef %block;
      } else {
        push(@{$macro{$block{name}}}, $_);
      }
    } elsif ($block{type} eq "auto") {
      if ($_ eq "}") {
        if ($block{loadmacro}) {
          undef $block{loadmacro};
        } else {
          undef %block;
        }
      } elsif ($_ eq "call {") {
        $block{loadmacro} = 1;
        $block{loadmacro_name} = "tempMacro".$tempmacro++;
        $automacro{$block{name}}->{call} = $block{loadmacro_name};
        $macro{$block{loadmacro_name}} = [];
      } elsif ($block{loadmacro}) {
        push(@{$macro{$block{loadmacro_name}}}, $_);
      } else {
        my ($key, $value) = $_ =~ /^(.*?)\s+(.*)/;
        next unless $key;
        if ($key =~ /^(map|mapchange|class|timeout|disabled|call|spell|pm|pubm|guild|party|console)$/) {
          $automacro{$block{name}}->{$key} = $value;
        } else {
          push(@{$automacro{$block{name}}->{$key}}, $value);
        }
      }
    }
  }
  close FILE;
  return 0 if %block;
  return 1;
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
    my $tmp = getVar($var); $tmp = "" if !defined $tmp;
    $var = quotemeta $var;
    $command =~ s/(^|[^\\])\$$var([^a-z\d]?)/$1$tmp$2/g;
  }
  # substitute doublevars
  while (($var) = $command =~ /\$\{(.*?)\}/i) {
    $cvs->debug("found doublevar $var in $command", $logfac{parser_steps});
    my $tmp = getVar("#".$var); $tmp = "" if !defined $tmp;
    $var = quotemeta $var;
    $command =~ s/\$\{$var\}/$tmp/g;
  }
  my $keywords = "npc|cart|inventory|store|storage|player|vender|random|".
                 "invamount|cartamount|shopamount|storamount|eval|arg";
  while (my ($kw, $arg) = $command =~ /\@($keywords)\s*\(([^@]+?)\)/i) {
    $cvs->debug("parsing '$command': '$kw', '$arg'", $logfac{parser_steps});
    my $ret = "_%_";
    if ($kw eq 'npc')           {$ret = getnpcID($arg)}
    elsif ($kw eq 'cart')       {$ret = getItemID($arg, \@{$cart{inventory}})}
    elsif ($kw eq 'inventory')  {$ret = getItemID($arg, \@{$char->{inventory}})}
    elsif ($kw eq 'store')      {$ret = getItemID($arg, \@::storeList)}
    elsif ($kw eq 'storage')    {$ret = getStorageID($arg)}
    elsif ($kw eq 'player')     {$ret = getPlayerID($arg, \@::playersID)}
    elsif ($kw eq 'vender')     {$ret = getPlayerID($arg, \@::venderListsID)}
    elsif ($kw eq 'random')     {$ret = getRandom($arg)}
    elsif ($kw eq 'invamount')  {$ret = getInventoryAmount($arg)}
    elsif ($kw eq 'cartamount') {$ret = getCartAmount($arg)}
    elsif ($kw eq 'shopamount') {$ret = getShopAmount($arg)}
    elsif ($kw eq 'storamount') {$ret = getStorageAmount($arg)}
    elsif ($kw eq 'arg')        {$ret = getWord($arg)}
    elsif ($kw eq 'eval')       {$ret = eval($arg)};
    return $command if $ret eq '_%_';
    if (defined $ret) {$arg = quotemeta $arg; $command =~ s/\@$kw\s*\($arg\)/$ret/g}
    else {error "[macro] command $command failed.\n"; return}
  }
  return $command;
}

1;
